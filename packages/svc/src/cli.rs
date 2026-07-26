use std::path::PathBuf;

use clap::{Parser, Subcommand, ValueEnum};
use clap_complete::Shell;

pub const DEFAULT_QUADLET_DIR: &str = "/etc/containers/systemd";

#[derive(Debug, Parser)]
#[command(name = "svc", version, about = "Quadlet service manager and dashboard")]
pub struct Cli {
    #[arg(long, env = "SVC_QUADLET_DIR", default_value = DEFAULT_QUADLET_DIR)]
    pub quadlet_dir: PathBuf,

    #[arg(long, global = true)]
    pub json: bool,

    #[command(subcommand)]
    pub command: Option<Commands>,
}

#[derive(Debug, Subcommand)]
pub enum Commands {
    /// Open the terminal dashboard
    Ui,
    /// List all services
    #[command(alias = "ls")]
    List,
    /// Show service status
    Status { service: Option<String> },
    /// Follow service logs
    #[command(alias = "log")]
    Logs {
        service: String,
        #[arg(short = 'n', long, default_value_t = 100)]
        lines: usize,
    },
    /// Start one or more services
    Start { services: Vec<String> },
    /// Stop one or more services
    Stop { services: Vec<String> },
    /// Restart one or more services
    Restart { services: Vec<String> },
    /// Open an interactive shell in a container
    #[command(alias = "sh")]
    Shell {
        service: String,
        #[arg(default_value = "sh")]
        shell: String,
    },
    /// Pull images for one or more services
    Pull { services: Vec<String> },
    /// Update one or more services when new images are available
    Update { services: Vec<String> },
    /// Generate shell completions
    Completions {
        #[arg(value_enum)]
        shell: Shell,
    },
    #[command(name = "__complete-services", hide = true)]
    CompleteServices,
    /// Operate on the full service stack
    Stack {
        #[arg(value_enum, default_value_t = StackAction::Status)]
        action: StackAction,
    },
}

#[derive(Debug, Clone, Copy, ValueEnum)]
pub enum StackAction {
    Status,
    Start,
    Stop,
    Restart,
    Pull,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_update_services() {
        let cli = Cli::try_parse_from(["svc", "update", "forgejo", "postgres"]).unwrap();

        let Some(Commands::Update { services }) = cli.command else {
            panic!("expected update command");
        };
        assert_eq!(services, ["forgejo", "postgres"]);
    }

    #[test]
    fn parses_fish_completions() {
        let cli = Cli::try_parse_from(["svc", "completions", "fish"]).unwrap();

        assert!(matches!(
            cli.command,
            Some(Commands::Completions { shell: Shell::Fish })
        ));
    }
}
