use std::{path::Path, process::Command};

use anyhow::{Context, Result, bail};

pub const NIXOS_SUDO_WRAPPER: &str = "/run/wrappers/bin/sudo";

pub fn launcher(euid: u32, wrapper_exists: bool) -> Option<&'static str> {
    if euid == 0 {
        None
    } else if wrapper_exists {
        Some(NIXOS_SUDO_WRAPPER)
    } else {
        Some("sudo")
    }
}

pub fn command(program: &str, non_interactive: bool) -> Command {
    let euid = unsafe { libc::geteuid() };
    match launcher(euid, Path::new(NIXOS_SUDO_WRAPPER).is_file()) {
        None => Command::new(program),
        Some(sudo) => {
            let mut command = Command::new(sudo);
            if non_interactive {
                command.arg("-n");
            }
            command.arg(program);
            command
        }
    }
}

pub fn warm_credentials() -> Result<()> {
    let euid = unsafe { libc::geteuid() };
    let Some(sudo) = launcher(euid, Path::new(NIXOS_SUDO_WRAPPER).is_file()) else {
        return Ok(());
    };
    let status = Command::new(sudo)
        .arg("-v")
        .status()
        .context("authenticate with sudo")?;
    if !status.success() {
        bail!("sudo authentication failed");
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn selects_launcher() {
        assert_eq!(launcher(0, false), None);
        assert_eq!(launcher(1000, true), Some(NIXOS_SUDO_WRAPPER));
        assert_eq!(launcher(1000, false), Some("sudo"));
    }
}
