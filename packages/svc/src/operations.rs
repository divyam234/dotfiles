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
    let mut command = privilege::command("podman", non_interactive);
    command.args(["pull", image]);
    let status = run_status(command)?;
    if !status.success() {
        bail!("podman pull failed for {}", service.name);
    }
    Ok(())
}

fn container_image_id(service: &Service, non_interactive: bool) -> Result<String> {
    let mut command = privilege::command("podman", non_interactive);
    command.args(["inspect", "--format", "{{.Image}}", &service.container_name]);
    run_output(command).with_context(|| format!("get current image ID for {}", service.name))
}

fn pulled_image_id(service: &Service, non_interactive: bool) -> Result<String> {
    let image = service
        .image
        .as_deref()
        .ok_or_else(|| anyhow!("{} has no Image= entry", service.name))?;
    let mut command = privilege::command("podman", non_interactive);
    command.args(["image", "inspect", "--format", "{{.Id}}", image]);
    run_output(command).with_context(|| format!("get pulled image ID for {}", service.name))
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

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum UpdateStep {
    Pull,
    Stop,
    RemoveOldImage,
    Start,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum UpdateOutcome {
    Updated,
    AlreadyCurrent,
}

fn run_update(
    get_old_image: impl FnOnce() -> Result<String>,
    get_new_image: impl FnOnce() -> Result<String>,
    mut run: impl FnMut(UpdateStep, Option<&str>) -> Result<()>,
) -> Result<UpdateOutcome> {
    let old_image = get_old_image()?;
    run(UpdateStep::Pull, None)?;
    let new_image = get_new_image()?;
    if old_image == new_image {
        return Ok(UpdateOutcome::AlreadyCurrent);
    }

    run(UpdateStep::Stop, None)?;
    let update_result = run(UpdateStep::RemoveOldImage, Some(&old_image));
    let start_result = run(UpdateStep::Start, None);

    match (update_result, start_result) {
        (Err(update_error), Err(start_error)) => {
            Err(update_error.context(format!("also failed to restart service: {start_error:#}")))
        }
        (Err(update_error), Ok(())) => Err(update_error),
        (Ok(()), Ok(())) => Ok(UpdateOutcome::Updated),
        (Ok(()), Err(start_error)) => Err(start_error),
    }
}

pub fn update_service(service: &Service, non_interactive: bool) -> Result<()> {
    eprintln!("svc: {}: checking current image", service.name);
    let outcome = run_update(
        || container_image_id(service, non_interactive),
        || pulled_image_id(service, non_interactive),
        |step, image_id| match step {
            UpdateStep::Pull => {
                eprintln!(
                    "svc: {}: pulling {}",
                    service.name,
                    service.image.as_deref().unwrap_or("image")
                );
                pull_service(service, non_interactive)
            }
            UpdateStep::Stop => {
                eprintln!("svc: {}: new image found; stopping service", service.name);
                systemctl_action("stop", service, non_interactive)
            }
            UpdateStep::RemoveOldImage => {
                eprintln!("svc: {}: removing old image", service.name);
                remove_image(image_id.expect("old image ID"), non_interactive)
            }
            UpdateStep::Start => {
                eprintln!("svc: {}: starting service", service.name);
                systemctl_action("start", service, non_interactive)
            }
        },
    )?;

    match outcome {
        UpdateOutcome::Updated => println!("svc: {}: update complete", service.name),
        UpdateOutcome::AlreadyCurrent => println!("svc: {}: already up to date", service.name),
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

    #[test]
    fn update_runs_steps_in_order() {
        let mut steps = Vec::new();

        run_update(
            || Ok("old".into()),
            || Ok("new".into()),
            |step, _| {
                steps.push(step);
                Ok(())
            },
        )
        .unwrap();

        assert_eq!(
            steps,
            [
                UpdateStep::Pull,
                UpdateStep::Stop,
                UpdateStep::RemoveOldImage,
                UpdateStep::Start
            ]
        );
    }

    #[test]
    fn update_does_not_stop_service_after_pull_failure() {
        let mut steps = Vec::new();

        let error = run_update(
            || Ok("old".into()),
            || Ok("new".into()),
            |step, _| {
                steps.push(step);
                if step == UpdateStep::Pull {
                    bail!("pull failed");
                }
                Ok(())
            },
        )
        .unwrap_err();

        assert_eq!(steps, [UpdateStep::Pull]);
        assert_eq!(error.to_string(), "pull failed");
    }

    #[test]
    fn update_reports_update_and_restart_failures() {
        let error = run_update(
            || Ok("old".into()),
            || Ok("new".into()),
            |step, _| match step {
                UpdateStep::RemoveOldImage => bail!("remove failed"),
                UpdateStep::Start => bail!("start failed"),
                _ => Ok(()),
            },
        )
        .unwrap_err();

        assert_eq!(
            error.to_string(),
            "also failed to restart service: start failed"
        );
        assert_eq!(error.root_cause().to_string(), "remove failed");
    }

    #[test]
    fn update_keeps_image_when_pull_returns_same_id() {
        let mut steps = Vec::new();

        run_update(
            || Ok("same".into()),
            || Ok("same".into()),
            |step, _| {
                steps.push(step);
                Ok(())
            },
        )
        .unwrap();

        assert_eq!(steps, [UpdateStep::Pull]);
    }
}
