use std::{
    io::{self, Write},
    path::Path,
    process::Command,
};

use anyhow::{Context, Result, bail};

pub const NIXOS_SUDO_WRAPPER: &str = "/run/wrappers/bin/sudo";

/// Resolve how to elevate: none for root (or `SVC_NO_SUDO=1`, used by tests
/// and rootless environments without sudo), the NixOS wrapper when present,
/// otherwise plain `sudo` from `PATH`.
pub fn launcher(euid: u32, wrapper_exists: bool) -> Option<&'static str> {
    if euid == 0 || std::env::var_os("SVC_NO_SUDO").is_some_and(|value| value == "1") {
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
    eprintln!("svc: authenticating with sudo before opening the dashboard…");
    io::stderr().flush().context("flush sudo prompt notice")?;
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
        let previous = std::env::var_os("SVC_NO_SUDO");
        unsafe {
            std::env::remove_var("SVC_NO_SUDO");
        }
        assert_eq!(launcher(0, false), None);
        assert_eq!(launcher(1000, true), Some(NIXOS_SUDO_WRAPPER));
        assert_eq!(launcher(1000, false), Some("sudo"));
        unsafe {
            std::env::set_var("SVC_NO_SUDO", "1");
        }
        assert_eq!(launcher(1000, true), None);
        unsafe {
            match previous {
                Some(value) => std::env::set_var("SVC_NO_SUDO", value),
                None => std::env::remove_var("SVC_NO_SUDO"),
            }
        }
    }
}
