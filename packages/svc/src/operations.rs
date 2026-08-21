use std::process::{Command, ExitStatus};

use anyhow::{Context, Result, anyhow, bail};

use crate::{model::Service, privilege, systemd};

fn run_status(mut command: Command) -> Result<ExitStatus> {
    let rendered = format!("{command:?}");
    command.status().with_context(|| format!("run {rendered}"))
}

fn run_output(mut command: Command) -> Result<String> {
    let rendered = format!("{command:?}");
    let output = command
        .output()
        .with_context(|| format!("run {rendered}"))?;
    if !output.status.success() {
        bail!("{rendered} failed");
    }
    Ok(String::from_utf8_lossy(&output.stdout).trim().to_owned())
}

pub fn systemctl_action(action: &str, service: &Service, non_interactive: bool) -> Result<()> {
    let mut command = privilege::command("systemctl", non_interactive);
    command.args([action, &service.unit]);
    let status = run_status(command)?;
    if !status.success() {
        if non_interactive {
            bail!(
                "systemctl {action} {} failed; sudo authentication may need refreshing",
                service.unit
            );
        }
        bail!("systemctl {action} {} failed", service.unit);
    }
    Ok(())
}

pub fn pull_service(service: &Service, non_interactive: bool) -> Result<()> {
    let image = service
        .image
        .as_deref()
        .ok_or_else(|| anyhow!("{} has no Image= entry", service.name))?;
    pull_image_ref(image, non_interactive)
}

fn pull_image_ref(image: &str, non_interactive: bool) -> Result<()> {
    let mut command = privilege::command("podman", non_interactive);
    command.args(["pull", image]);
    let status = run_status(command)?;
    if !status.success() {
        bail!("podman pull failed for {image}");
    }
    Ok(())
}

fn container_image_id(container_name: &str, non_interactive: bool) -> Result<String> {
    let mut command = privilege::command("podman", non_interactive);
    command.args(["inspect", "--format", "{{.Image}}", container_name]);
    run_output(command).with_context(|| format!("get current image ID for {container_name}"))
}

fn containers_using_image(image_id: &str, non_interactive: bool) -> Result<Vec<String>> {
    let mut command = privilege::command("podman", non_interactive);
    command.args([
        "ps",
        "-a",
        "--filter",
        &format!("ancestor={image_id}"),
        "--format",
        "{{.Names}}",
    ]);
    let output =
        run_output(command).with_context(|| format!("list containers using {image_id}"))?;
    Ok(output.lines().map(str::to_owned).collect())
}

fn image_update_available(service: &Service, non_interactive: bool) -> Result<bool> {
    let mut command = privilege::command("podman", non_interactive);
    command.args([
        "auto-update",
        "--dry-run",
        "--format",
        "{{.ContainerName}}\t{{.Updated}}",
    ]);
    let output = run_output(command).context("check registry for image updates")?;
    let status = output
        .lines()
        .filter_map(|line| line.split_once('\t'))
        .find_map(|(name, status)| (name == service.container_name).then_some(status))
        .ok_or_else(|| {
            anyhow!(
                "{} is not configured for registry auto-update",
                service.name
            )
        })?;

    match status {
        "pending" => Ok(true),
        "false" => Ok(false),
        "failed" => bail!("registry update check failed for {}", service.name),
        status => bail!("unexpected update status '{status}' for {}", service.name),
    }
}

fn remove_image(image_id: &str, non_interactive: bool) -> Result<()> {
    let mut command = privilege::command("podman", non_interactive);
    command.args(["image", "rm", image_id]);
    let status = run_status(command)?;
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
enum UpdateOutcome {
    Updated,
    AlreadyCurrent,
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

pub fn update_services(all: &[Service], targets: &[&Service], non_interactive: bool) -> Result<()> {
    let by_container: Vec<(String, &Service)> = all
        .iter()
        .map(|service| (service.container_name.clone(), service))
        .collect();

    let mut handled_images: Vec<String> = Vec::new();
    for target in targets {
        let image_id = container_image_id(&target.container_name, non_interactive)?;
        if handled_images.contains(&image_id) {
            continue;
        }
        handled_images.push(image_id);

        let members = image_group_members(all, target, |container| {
            container_image_id(container, non_interactive)
        });
        if members.len() > 1 {
            let others: Vec<&str> = members
                .iter()
                .map(|service| service.name.as_str())
                .filter(|name| *name != target.name)
                .collect();
            eprintln!(
                "svc: {}: sharing image with {}; updating as a group",
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
            || container_image_id(&target.container_name, non_interactive),
            || {
                let mut pending = false;
                for member in &members {
                    if image_update_available(member, non_interactive)? {
                        pending = true;
                    }
                }
                Ok(pending)
            },
            |old_image| {
                let users = containers_using_image(old_image, non_interactive)?;
                Ok(!users
                    .iter()
                    .any(|container| !member_containers.contains(container)))
            },
            |step, image_id| match step {
                UpdateStep::Stop(name) => {
                    eprintln!("svc: {name}: new image found; stopping service");
                    systemctl_action("stop", find(&name)?, non_interactive)
                }
                UpdateStep::Pull => {
                    for image in &image_refs {
                        eprintln!("svc: {}: pulling {}", target.name, image);
                        pull_image_ref(image, non_interactive)?;
                    }
                    Ok(())
                }
                UpdateStep::RemoveOldImage => {
                    eprintln!("svc: {}: removing old image", target.name);
                    remove_image(image_id.expect("old image ID"), non_interactive)
                }
                UpdateStep::Start(name) => {
                    eprintln!("svc: {name}: starting service");
                    systemctl_action("start", find(&name)?, non_interactive)
                }
            },
        )?;

        for member in &members {
            match outcome {
                UpdateOutcome::Updated => println!("svc: {}: update complete", member.name),
                UpdateOutcome::AlreadyCurrent => {
                    println!("svc: {}: already up to date", member.name)
                }
            }
        }
    }
    Ok(())
}

pub fn show_status(service: &Service) -> Result<()> {
    let status = Command::new("systemctl")
        .args(["status", &service.unit, "--no-pager"])
        .status()
        .context("run systemctl status")?;
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
    let status = Command::new("journalctl")
        .args(["-u", &service.unit, "-n", &lines.to_string(), "-f"])
        .status()
        .context("run journalctl")?;
    if !status.success() {
        bail!("journalctl failed for {}", service.unit);
    }
    Ok(())
}

pub fn container_shell(service: &Service, shell: &str, non_interactive: bool) -> Result<()> {
    let mut command = privilege::command("podman", non_interactive);
    command.args(["exec", "-it", &service.container_name, shell]);
    let status = run_status(command)?;
    if !status.success() {
        bail!("shell failed for {}", service.container_name);
    }
    Ok(())
}

pub fn tail_logs(service: &Service, lines: usize) -> String {
    Command::new("journalctl")
        .args([
            "-u",
            &service.unit,
            "-n",
            &lines.to_string(),
            "--no-pager",
            "-o",
            "cat",
        ])
        .output()
        .ok()
        .filter(|output| output.status.success())
        .map(|output| String::from_utf8_lossy(&output.stdout).into_owned())
        .unwrap_or_else(|| "No logs available.".into())
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
}
