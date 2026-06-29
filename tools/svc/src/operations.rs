use std::process::{Command, ExitStatus};

use anyhow::{Context, Result, anyhow, bail};

use crate::{model::Service, privilege, systemd};

fn run_status(mut command: Command) -> Result<ExitStatus> {
    let rendered = format!("{command:?}");
    command.status().with_context(|| format!("run {rendered}"))
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
