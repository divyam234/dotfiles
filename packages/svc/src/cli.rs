use std::path::PathBuf;

use clap::{Parser, Subcommand, ValueEnum};

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
    Ui,
    #[command(alias = "ls")]
    List,
    Status {
        service: Option<String>,
    },
    #[command(alias = "log")]
    Logs {
        service: String,
        #[arg(short = 'n', long, default_value_t = 100)]
        lines: usize,
    },
    Start {
        services: Vec<String>,
    },
    Stop {
        services: Vec<String>,
    },
    Restart {
        services: Vec<String>,
    },
    #[command(alias = "sh")]
    Shell {
        service: String,
        #[arg(default_value = "sh")]
        shell: String,
    },
    Pull {
        services: Vec<String>,
    },
    Update {
        services: Vec<String>,
    },
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
}
