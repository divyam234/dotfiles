use std::path::PathBuf;

use clap::{ArgAction, Parser, Subcommand, ValueEnum};
use clap_complete::Shell;

pub const DEFAULT_QUADLET_DIR: &str = "/etc/containers/systemd";
pub const DEFAULT_TIMEOUT_SECS: u64 = 120;

#[derive(Debug, Parser)]
#[command(
    name = "svc",
    version,
    about = "Quadlet service manager and dashboard",
    after_help = "Exit codes:\n  0  success\n  1  error\n  2  partial failure (multi-service action) or invalid CLI usage"
)]
pub struct Cli {
    #[arg(long, env = "SVC_QUADLET_DIR", default_value = DEFAULT_QUADLET_DIR)]
    pub quadlet_dir: PathBuf,

    #[arg(long, global = true)]
    pub json: bool,

    /// Print the commands that would run without executing them
    #[arg(long, global = true, env = "SVC_DRY_RUN")]
    pub dry_run: bool,

    /// Timeout in seconds for each systemctl/podman invocation
    #[arg(long = "timeout", global = true, env = "SVC_TIMEOUT", default_value_t = DEFAULT_TIMEOUT_SECS)]
    pub timeout_secs: u64,

    /// Dashboard state refresh interval in seconds
    #[arg(long, global = true, env = "SVC_REFRESH_INTERVAL", default_value_t = 5)]
    pub refresh_secs: u64,

    /// Increase log verbosity (-v info, -vv debug)
    #[arg(short, long, global = true, action = ArgAction::Count)]
    pub verbose: u8,

    #[command(subcommand)]
    pub command: Option<Commands>,
}

#[derive(Debug, Subcommand)]
pub enum Commands {
    /// Open the terminal dashboard
    Ui,
    /// List all services
    #[command(alias = "ls")]
    List {
        /// Only show failed or unavailable services
        #[arg(long)]
        failed_only: bool,
        /// Reprint the list every SECS seconds until interrupted (default 2)
        #[arg(long, num_args = 0..=1, default_missing_value = "2")]
        watch: Option<u64>,
    },
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
    /// Run a one-off command in a container (-it when stdin is a terminal)
    Exec {
        service: String,
        #[arg(last = true, required = true)]
        command: Vec<String>,
    },
    /// Enable one or more services to start at boot
    Enable { services: Vec<String> },
    /// Disable one or more services from starting at boot
    Disable { services: Vec<String> },
    /// Reload the systemd manager configuration
    DaemonReload,
    /// Show registry update status without changing anything
    Outdated { services: Vec<String> },
    /// Pull images for one or more services
    Pull { services: Vec<String> },
    /// Update one or more services when new images are available
    Update {
        services: Vec<String>,
        /// Skip the confirmation prompt and proceed immediately
        #[arg(long)]
        yes: bool,
    },
    /// Generate shell completions
    Completions {
        #[arg(value_enum)]
        shell: Shell,
    },
    /// Print a man page in roff format
    Man,
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

        let Some(Commands::Update { services, yes }) = cli.command else {
            panic!("expected update command");
        };
        assert_eq!(services, ["forgejo", "postgres"]);
        assert!(!yes);
    }

    #[test]
    fn parses_update_yes_and_global_flags() {
        let cli = Cli::try_parse_from([
            "svc",
            "--dry-run",
            "--timeout",
            "30",
            "-v",
            "update",
            "--yes",
            "forgejo",
        ])
        .unwrap();

        assert!(cli.dry_run);
        assert_eq!(cli.timeout_secs, 30);
        assert_eq!(cli.verbose, 1);
        assert!(matches!(
            cli.command,
            Some(Commands::Update { yes: true, .. })
        ));
    }

    #[test]
    fn parses_fish_completions() {
        let cli = Cli::try_parse_from(["svc", "completions", "fish"]).unwrap();

        assert!(matches!(
            cli.command,
            Some(Commands::Completions { shell: Shell::Fish })
        ));
    }

    #[test]
    fn parses_new_commands() {
        let cli = Cli::try_parse_from(["svc", "outdated"]).unwrap();
        assert!(matches!(cli.command, Some(Commands::Outdated { .. })));

        let cli = Cli::try_parse_from(["svc", "enable", "a", "b"]).unwrap();
        let Some(Commands::Enable { services }) = cli.command else {
            panic!("expected enable command");
        };
        assert_eq!(services, ["a", "b"]);

        let cli = Cli::try_parse_from(["svc", "daemon-reload"]).unwrap();
        assert!(matches!(cli.command, Some(Commands::DaemonReload)));

        let cli = Cli::try_parse_from(["svc", "exec", "web", "--", "ls", "-la"]).unwrap();
        let Some(Commands::Exec { service, command }) = cli.command else {
            panic!("expected exec command");
        };
        assert_eq!(service, "web");
        assert_eq!(command, ["ls", "-la"]);

        let cli = Cli::try_parse_from(["svc", "list", "--failed-only", "--watch", "5"]).unwrap();
        let Some(Commands::List { failed_only, watch }) = cli.command else {
            panic!("expected list command");
        };
        assert!(failed_only);
        assert_eq!(watch, Some(5));

        let cli = Cli::try_parse_from(["svc", "list", "--watch"]).unwrap();
        let Some(Commands::List { watch, .. }) = cli.command else {
            panic!("expected list command");
        };
        assert_eq!(watch, Some(2));
    }
}
