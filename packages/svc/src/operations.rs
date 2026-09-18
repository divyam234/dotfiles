use std::{
    process::{Command, ExitStatus},
    thread,
    time::{Duration, Instant},
};

use anyhow::{Context, Result, anyhow, bail};

use crate::{
    model::{Freshness, Service},
    privilege, systemd,
};

/// Shared execution context for every external command.
#[derive(Debug, Clone, Copy)]
pub struct ExecOptions {
    /// Pass `-n` to sudo so workers never block on a password prompt.
    pub non_interactive: bool,
    /// Print mutating commands instead of executing them.
    pub dry_run: bool,
    /// Per-command timeout for systemctl/podman invocations.
    pub timeout: Duration,
}

impl ExecOptions {
    pub fn new(non_interactive: bool, dry_run: bool, timeout: Duration) -> Self {
        Self {
            non_interactive,
            dry_run,
            timeout,
        }
    }

    /// Foreground CLI execution: sudo may prompt.
    pub fn cli(dry_run: bool, timeout: Duration) -> Self {
        Self::new(false, dry_run, timeout)
    }

    /// Background worker execution: sudo must not prompt.
    pub fn worker(dry_run: bool, timeout: Duration) -> Self {
        Self::new(true, dry_run, timeout)
    }
}

impl Default for ExecOptions {
    fn default() -> Self {
        Self::new(false, false, Duration::from_secs(120))
    }
}

fn spawn_timed(mut command: Command) -> Result<std::process::Child> {
    let rendered = format!("{command:?}");
    command.spawn().with_context(|| format!("run {rendered}"))
}

fn wait_timed(child: &mut std::process::Child, rendered: &str, timeout: Duration) -> Result<()> {
    let start = Instant::now();
    loop {
        match child.try_wait().context("poll child process")? {
            Some(_) => return Ok(()),
            None if start.elapsed() >= timeout => {
                let _ = child.kill();
                let _ = child.wait();
                bail!("{rendered} timed out after {}s", timeout.as_secs());
            }
            None => thread::sleep(Duration::from_millis(50)),
        }
    }
}

fn run_status(command: Command, timeout: Duration) -> Result<ExitStatus> {
    let rendered = format!("{command:?}");
    let mut child = spawn_timed(command)?;
    wait_timed(&mut child, &rendered, timeout)?;
    child.wait().with_context(|| format!("run {rendered}"))
}

fn run_output(command: Command, timeout: Duration) -> Result<String> {
    use std::process::Stdio;
    let rendered = format!("{command:?}");
    let mut child = spawn_timed({
        let mut command = command;
        command.stdout(Stdio::piped()).stderr(Stdio::piped());
        command
    })?;
    wait_timed(&mut child, &rendered, timeout)?;
    let output = child
        .wait_with_output()
        .with_context(|| format!("run {rendered}"))?;
    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr).trim().to_owned();
        if stderr.is_empty() {
            bail!("{rendered} failed");
        }
        bail!("{rendered} failed: {stderr}");
    }
    Ok(String::from_utf8_lossy(&output.stdout).trim().to_owned())
}

fn dry_run_print(command: Command) {
    println!("svc: dry-run: {command:?}");
}

pub fn systemctl_action(action: &str, service: &Service, opts: ExecOptions) -> Result<()> {
    let mut command = privilege::command("systemctl", opts.non_interactive);
    command.args([action, &service.unit]);
    if opts.dry_run {
        dry_run_print(command);
        return Ok(());
    }
    let status = run_status(command, opts.timeout)?;
    if !status.success() {
        if opts.non_interactive {
            bail!(
                "systemctl {action} {} failed; sudo authentication may need refreshing",
                service.unit
            );
        }
        bail!("systemctl {action} {} failed", service.unit);
    }
    Ok(())
}

pub fn pull_service(service: &Service, opts: ExecOptions) -> Result<()> {
    let image = service
        .image
        .as_deref()
        .ok_or_else(|| anyhow!("{} has no Image= entry", service.name))?;
    pull_image_ref(image, opts)
}

fn pull_image_ref(image: &str, opts: ExecOptions) -> Result<()> {
    let mut command = privilege::command("podman", opts.non_interactive);
    command.args(["pull", image]);
    if opts.dry_run {
        dry_run_print(command);
        return Ok(());
    }
    let status = run_status(command, opts.timeout)?;
    if !status.success() {
        bail!("podman pull failed for {image}");
    }
    Ok(())
}

fn container_image_id(container_name: &str, opts: ExecOptions) -> Result<String> {
    let mut command = privilege::command("podman", opts.non_interactive);
    command.args(["inspect", "--format", "{{.Image}}", container_name]);
    run_output(command, opts.timeout)
        .with_context(|| format!("get current image ID for {container_name}"))
}

fn containers_using_image(image_id: &str, opts: ExecOptions) -> Result<Vec<String>> {
    let mut command = privilege::command("podman", opts.non_interactive);
    command.args([
        "ps",
        "-a",
        "--filter",
        &format!("ancestor={image_id}"),
        "--format",
        "{{.Names}}",
    ]);
    let output = run_output(command, opts.timeout)
        .with_context(|| format!("list containers using {image_id}"))?;
    Ok(output.lines().map(str::to_owned).collect())
}

/// Check the registry for a newer image.
///
/// Returns `Ok(None)` when the service is not configured for registry
/// auto-update; callers decide whether that is fatal.
fn image_update_available(service: &Service, opts: ExecOptions) -> Result<Option<bool>> {
    let mut command = privilege::command("podman", opts.non_interactive);
    command.args([
        "auto-update",
        "--dry-run",
        "--format",
        "{{.ContainerName}}\t{{.Updated}}",
    ]);
    let output = run_output(command, opts.timeout).context("check registry for image updates")?;
    let status = output
        .lines()
        .filter_map(|line| line.split_once('\t'))
        .find_map(|(name, status)| (name == service.container_name).then_some(status));

    let Some(status) = status else {
        return Ok(None);
    };
    match status {
        "pending" => Ok(Some(true)),
        "false" => Ok(Some(false)),
        "failed" => bail!("registry update check failed for {}", service.name),
        status => bail!("unexpected update status '{status}' for {}", service.name),
    }
}

/// Registry freshness for `outdated`: never fatal for unsupported services.
pub fn check_updates(service: &Service, opts: ExecOptions) -> Result<Freshness> {
    match image_update_available(service, opts)? {
        Some(true) => Ok(Freshness::Pending),
        Some(false) => Ok(Freshness::Current),
        None => Ok(Freshness::Unsupported),
    }
}

fn remove_image(image_id: &str, opts: ExecOptions) -> Result<()> {
    let mut command = privilege::command("podman", opts.non_interactive);
    command.args(["image", "rm", image_id]);
    if opts.dry_run {
        dry_run_print(command);
        return Ok(());
    }
    let status = run_status(command, opts.timeout)?;
    if !status.success() {
        bail!("podman image rm failed for {image_id}");
    }
    Ok(())
}

#[derive(Debug, Clone, PartialEq, Eq)]
enum UpdateStep {
    Stop(String),
    Pull,
    RemoveOldImage,
    Start(String),
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum UpdateOutcome {
    Updated,
    AlreadyCurrent,
}

/// Per-service result of [`update_services`]; presentation lives with callers
/// so the dashboard can render reports without touching stdout.
#[derive(Debug, Clone)]
pub struct UpdateReport {
    pub name: String,
    pub outcome: UpdateOutcome,
}

impl UpdateReport {
    pub fn describe(&self) -> &'static str {
        match self.outcome {
            UpdateOutcome::Updated => "update complete",
            UpdateOutcome::AlreadyCurrent => "already up to date",
        }
    }
}

fn image_group_members<'a>(
    all: &'a [Service],
    target: &'a Service,
    container_image: impl Fn(&str) -> Result<String>,
) -> Vec<&'a Service> {
    let Ok(image_id) = container_image(&target.container_name) else {
        return vec![target];
    };
    let members: Vec<&Service> = all
        .iter()
        .filter(|service| {
            service.container_name == target.container_name
                || container_image(&service.container_name)
                    .map(|other| other == image_id)
                    .unwrap_or(false)
        })
        .collect();
    if members.is_empty() {
        return vec![target];
    }
    members
}

fn run_group_update(
    label: &str,
    members: &[String],
    get_old_image: impl FnOnce() -> Result<String>,
    any_update_pending: impl FnOnce() -> Result<bool>,
    can_remove_old_image: impl FnOnce(&str) -> Result<bool>,
    mut run: impl FnMut(UpdateStep, Option<&str>) -> Result<()>,
) -> Result<UpdateOutcome> {
    let old_image = get_old_image()?;
    if !any_update_pending()? {
        return Ok(UpdateOutcome::AlreadyCurrent);
    }

    for name in members.iter().rev() {
        run(UpdateStep::Stop(name.clone()), None)?;
    }

    let remove_allowed = match can_remove_old_image(&old_image) {
        Ok(true) => true,
        Ok(false) => {
            eprintln!("svc: {label}: old image still used by other containers; keeping it");
            false
        }
        Err(error) => {
            eprintln!("svc: {label}: cannot verify old image usage; keeping it ({error:#})");
            false
        }
    };

    let update_result = run(UpdateStep::Pull, None).map(|()| {
        if remove_allowed && let Err(error) = run(UpdateStep::RemoveOldImage, Some(&old_image)) {
            eprintln!("svc: {label}: warning: failed to remove old image ({error:#})");
        }
    });

    let mut start_errors = Vec::new();
    for name in members {
        if let Err(error) = run(UpdateStep::Start(name.clone()), None) {
            start_errors.push(format!("{}: {error:#}", name));
        }
    }
    if !start_errors.is_empty() {
        let joined = start_errors.join("; ");
        return match update_result {
            Err(update_error) => {
                Err(update_error.context(format!("also failed to restart services: {joined}")))
            }
            Ok(()) => Err(anyhow!("failed to restart services: {joined}")),
        };
    }
    update_result?;
    Ok(UpdateOutcome::Updated)
}

pub fn update_services(
    all: &[Service],
    targets: &[&Service],
    opts: ExecOptions,
) -> Result<Vec<UpdateReport>> {
    let by_container: Vec<(String, &Service)> = all
        .iter()
        .map(|service| (service.container_name.clone(), service))
        .collect();

    let mut handled_images: Vec<String> = Vec::new();
    let mut reports = Vec::new();
    for target in targets {
        let image_id = container_image_id(&target.container_name, opts)?;
        if handled_images.contains(&image_id) {
            continue;
        }
        handled_images.push(image_id);

        let members =
            image_group_members(all, target, |container| container_image_id(container, opts));
        if members.len() > 1 {
            let others: Vec<&str> = members
                .iter()
                .map(|service| service.name.as_str())
                .filter(|name| *name != target.name)
                .collect();
            tracing::info!(
                "{}: sharing image with {}; updating as a group",
                target.name,
                others.join(", ")
            );
        }

        let member_names: Vec<String> =
            members.iter().map(|service| service.name.clone()).collect();
        let member_containers: Vec<String> = members
            .iter()
            .map(|service| service.container_name.clone())
            .collect();
        let image_refs: Vec<String> = members
            .iter()
            .filter_map(|service| service.image.clone())
            .collect::<std::collections::BTreeSet<_>>()
            .into_iter()
            .collect();

        let find = |name: &str| -> Result<&Service> {
            by_container
                .iter()
                .find(|(container, _)| container == name)
                .map(|(_, service)| *service)
                .ok_or_else(|| anyhow!("unknown container '{name}'"))
        };

        let outcome = run_group_update(
            &target.name,
            &member_names,
            || container_image_id(&target.container_name, opts),
            || {
                let mut pending = false;
                for member in &members {
                    match image_update_available(member, opts)? {
                        Some(true) => pending = true,
                        Some(false) => {}
                        None => bail!("{} is not configured for registry auto-update", member.name),
                    }
                }
                Ok(pending)
            },
            |old_image| {
                let users = containers_using_image(old_image, opts)?;
                Ok(!users
                    .iter()
                    .any(|container| !member_containers.contains(container)))
            },
            |step, image_id| match step {
                UpdateStep::Stop(name) => {
                    tracing::info!("{name}: new image found; stopping service");
                    systemctl_action("stop", find(&name)?, opts)
                }
                UpdateStep::Pull => {
                    for image in &image_refs {
                        tracing::info!("{}: pulling {}", target.name, image);
                        pull_image_ref(image, opts)?;
                    }
                    Ok(())
                }
                UpdateStep::RemoveOldImage => {
                    tracing::info!("{}: removing old image", target.name);
                    remove_image(image_id.expect("old image ID"), opts)
                }
                UpdateStep::Start(name) => {
                    tracing::info!("{name}: starting service");
                    systemctl_action("start", find(&name)?, opts)
                }
            },
        )?;

        for member in &members {
            reports.push(UpdateReport {
                name: member.name.clone(),
                outcome,
            });
        }
    }
    Ok(reports)
}

pub fn daemon_reload(opts: ExecOptions) -> Result<()> {
    let mut command = privilege::command("systemctl", opts.non_interactive);
    command.arg("daemon-reload");
    if opts.dry_run {
        dry_run_print(command);
        return Ok(());
    }
    let status = run_status(command, opts.timeout)?;
    if !status.success() {
        bail!("systemctl daemon-reload failed");
    }
    Ok(())
}

pub fn container_exec(service: &Service, args: &[String], opts: ExecOptions) -> Result<()> {
    use std::io::IsTerminal;
    let mut command = privilege::command("podman", opts.non_interactive);
    command.arg("exec");
    if std::io::stdin().is_terminal() {
        command.args(["-it"]);
    }
    command.arg(&service.container_name);
    command.args(args);
    if opts.dry_run {
        dry_run_print(command);
        return Ok(());
    }
    // May be interactive: run without a timeout.
    let rendered = format!("{command:?}");
    let status = command
        .status()
        .with_context(|| format!("run {rendered}"))?;
    if !status.success() {
        bail!("exec failed for {}", service.container_name);
    }
    Ok(())
}

pub fn show_status(service: &Service, opts: ExecOptions) -> Result<()> {
    let mut command = Command::new("systemctl");
    command.args(["status", &service.unit, "--no-pager"]);
    if opts.dry_run {
        dry_run_print(command);
        return Ok(());
    }
    // `systemctl status` streams directly; wait with a timeout instead of
    // blocking forever on a wedged systemd.
    let rendered = format!("{command:?}");
    let mut child = spawn_timed(command)?;
    wait_timed(&mut child, &rendered, opts.timeout)?;
    let status = child.wait().context("run systemctl status")?;
    if !systemd::status_is_acceptable(status.code()) {
        bail!(
            "systemctl status {} failed with {:?}",
            service.unit,
            status.code()
        );
    }
    Ok(())
}

pub fn follow_logs(service: &Service, lines: usize) -> Result<()> {
    // Intentionally untimed: `-f` follows forever by design.
    let status = Command::new("journalctl")
        .args(["-u", &service.unit, "-n", &lines.to_string(), "-f"])
        .status()
        .context("run journalctl")?;
    if !status.success() {
        bail!("journalctl failed for {}", service.unit);
    }
    Ok(())
}

pub fn container_shell(service: &Service, shell: &str, opts: ExecOptions) -> Result<()> {
    let mut command = privilege::command("podman", opts.non_interactive);
    command.args(["exec", "-it", &service.container_name, shell]);
    if opts.dry_run {
        dry_run_print(command);
        return Ok(());
    }
    // Interactive session: no timeout.
    let rendered = format!("{command:?}");
    let status = command
        .status()
        .with_context(|| format!("run {rendered}"))?;
    if !status.success() {
        bail!("shell failed for {}", service.container_name);
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn service(name: &str, container: &str, image: Option<&str>) -> Service {
        Service::new(
            name.to_owned(),
            container.to_owned(),
            image.map(str::to_owned),
            None,
            std::path::PathBuf::from(format!("/tmp/{name}.container")),
        )
    }

    #[test]
    fn group_members_share_resolved_image_id() {
        let all = vec![
            service("caddy", "systemd-caddy", None),
            service("forgejo", "systemd-forgejo", Some("img:latest")),
            service("gitea", "systemd-gitea", Some("mirror:1")),
        ];
        let target = &all[1];

        let members = image_group_members(&all, target, |container| match container {
            "systemd-forgejo" | "systemd-gitea" => Ok("sha256:abc".into()),
            _ => Ok("sha256:other".into()),
        });

        let names: Vec<&str> = members
            .iter()
            .map(|service| service.name.as_str())
            .collect();
        assert_eq!(names, ["forgejo", "gitea"]);
    }

    #[test]
    fn group_falls_back_to_target_when_container_unknown() {
        let all = vec![service("forgejo", "systemd-forgejo", Some("img:latest"))];
        let members = image_group_members(&all, &all[0], |_| {
            bail!("no such container");
        });
        assert_eq!(members.len(), 1);
    }

    #[test]
    fn group_runs_steps_in_order() {
        let members = ["a".to_owned(), "b".to_owned()];
        let mut steps = Vec::new();

        run_group_update(
            "a",
            &members,
            || Ok("old".into()),
            || Ok(true),
            |_| Ok(true),
            |step, _| {
                match step {
                    UpdateStep::Stop(name) => steps.push(format!("stop {name}")),
                    UpdateStep::Pull => steps.push("pull".into()),
                    UpdateStep::RemoveOldImage => steps.push("remove".into()),
                    UpdateStep::Start(name) => steps.push(format!("start {name}")),
                }
                Ok(())
            },
        )
        .unwrap();

        assert_eq!(
            steps,
            ["stop b", "stop a", "pull", "remove", "start a", "start b"]
        );
    }

    #[test]
    fn group_restarts_all_after_pull_failure() {
        let members = ["a".to_owned(), "b".to_owned()];
        let mut steps = Vec::new();

        let error = run_group_update(
            "a",
            &members,
            || Ok("old".into()),
            || Ok(true),
            |_| Ok(true),
            |step, _| {
                if step == UpdateStep::Pull {
                    steps.push("pull".into());
                    return Err(anyhow!("pull failed"));
                }
                match step {
                    UpdateStep::Stop(name) => steps.push(format!("stop {name}")),
                    UpdateStep::Pull => steps.push("pull".into()),
                    UpdateStep::RemoveOldImage => steps.push("remove".into()),
                    UpdateStep::Start(name) => steps.push(format!("start {name}")),
                }
                Ok(())
            },
        )
        .unwrap_err();

        assert_eq!(steps, ["stop b", "stop a", "pull", "start a", "start b"]);
        assert_eq!(error.root_cause().to_string(), "pull failed");
    }

    #[test]
    fn group_keeps_old_image_when_shared_outside_group() {
        let members = ["a".to_owned()];
        let mut steps = Vec::new();

        run_group_update(
            "a",
            &members,
            || Ok("old".into()),
            || Ok(true),
            |_| Ok(false),
            |step, image_id| {
                match step {
                    UpdateStep::Stop(name) => steps.push(format!("stop {name}")),
                    UpdateStep::Pull => steps.push("pull".into()),
                    UpdateStep::RemoveOldImage => {
                        steps.push(format!("remove {}", image_id.unwrap()))
                    }
                    UpdateStep::Start(name) => steps.push(format!("start {name}")),
                }
                Ok(())
            },
        )
        .unwrap();

        assert_eq!(steps, ["stop a", "pull", "start a"]);
    }

    #[test]
    fn group_warns_but_succeeds_when_remove_fails() {
        let members = ["a".to_owned()];

        let outcome = run_group_update(
            "a",
            &members,
            || Ok("old".into()),
            || Ok(true),
            |_| Ok(true),
            |step, _| match step {
                UpdateStep::RemoveOldImage => Err(anyhow!("rm failed")),
                other => {
                    let _ = other;
                    Ok(())
                }
            },
        )
        .unwrap();

        assert_eq!(outcome, UpdateOutcome::Updated);
    }

    #[test]
    fn group_reports_start_failures_for_all_members() {
        let members = ["a".to_owned(), "b".to_owned()];

        let error = run_group_update(
            "a",
            &members,
            || Ok("old".into()),
            || Ok(true),
            |_| Ok(true),
            |step, _| match step {
                UpdateStep::Start(name) if name == "a" => Err(anyhow!("start failed")),
                _ => Ok(()),
            },
        )
        .unwrap_err();

        assert_eq!(
            error.to_string(),
            "failed to restart services: a: start failed"
        );
    }

    #[test]
    fn group_combines_pull_and_start_failures() {
        let members = ["a".to_owned(), "b".to_owned()];

        let error = run_group_update(
            "a",
            &members,
            || Ok("old".into()),
            || Ok(true),
            |_| Ok(true),
            |step, _| match step {
                UpdateStep::Pull => Err(anyhow!("pull failed")),
                UpdateStep::Start(name) if name == "b" => Err(anyhow!("start failed")),
                _ => Ok(()),
            },
        )
        .unwrap_err();

        assert_eq!(
            error.to_string(),
            "also failed to restart services: b: start failed"
        );
        assert_eq!(error.root_cause().to_string(), "pull failed");
    }

    #[test]
    fn group_does_nothing_when_registry_image_is_current() {
        let members = ["a".to_owned(), "b".to_owned()];
        let mut steps = Vec::new();

        run_group_update(
            "a",
            &members,
            || Ok("same".into()),
            || Ok(false),
            |_| Ok(true),
            |step, _| {
                match step {
                    UpdateStep::Stop(name) => steps.push(format!("stop {name}")),
                    UpdateStep::Pull => steps.push("pull".into()),
                    UpdateStep::Start(name) => steps.push(format!("start {name}")),
                    UpdateStep::RemoveOldImage => steps.push("remove".into()),
                }
                Ok(())
            },
        )
        .unwrap();

        assert!(steps.is_empty());
    }

    #[test]
    fn update_check_failure_propagates_without_touching_services() {
        let members = ["a".to_owned()];

        let error = run_group_update(
            "a",
            &members,
            || Ok("old".into()),
            || Err(anyhow!("registry unreachable")),
            |_| Ok(true),
            |step, _| {
                let _ = step;
                panic!("no steps should run");
            },
        )
        .unwrap_err();

        assert_eq!(error.root_cause().to_string(), "registry unreachable");
    }

    #[test]
    fn dry_run_mutations_succeed_without_executing() {
        let opts = ExecOptions::new(false, true, Duration::from_secs(1));
        // No such unit/binary needs to exist: dry-run returns before spawning.
        let target = service("ghost", "systemd-ghost", Some("img:latest"));
        systemctl_action("restart", &target, opts).unwrap();
        pull_service(&target, opts).unwrap();
        remove_image("sha256:never", opts).unwrap();
        container_shell(&target, "sh", opts).unwrap();
        show_status(&target, opts).unwrap();
    }

    #[test]
    fn slow_command_times_out() {
        let mut command = std::process::Command::new("sleep");
        command.arg("30");
        let error = run_status(command, Duration::from_millis(200)).unwrap_err();
        assert!(error.to_string().contains("timed out"), "{error:#}");
    }

    #[test]
    fn failing_command_reports_stderr() {
        let mut command = std::process::Command::new("sh");
        command.args(["-c", "echo oops >&2; exit 1"]);
        let error = run_output(command, Duration::from_secs(5)).unwrap_err();
        assert!(error.to_string().contains("oops"), "{error:#}");
    }

    #[test]
    fn update_report_describes_outcomes() {
        let updated = UpdateReport {
            name: "a".into(),
            outcome: UpdateOutcome::Updated,
        };
        let current = UpdateReport {
            name: "b".into(),
            outcome: UpdateOutcome::AlreadyCurrent,
        };
        assert_eq!(updated.describe(), "update complete");
        assert_eq!(current.describe(), "already up to date");
    }
}
