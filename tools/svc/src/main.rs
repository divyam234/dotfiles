mod cli;
mod model;
mod operations;
mod output;
mod privilege;
mod quadlet;
mod systemd;
mod tui;

use anyhow::{Result, bail};
use clap::Parser;

use crate::{
    cli::{Cli, Commands, StackAction},
    model::Service,
};

fn load_services(dir: &std::path::Path) -> Result<(Vec<Service>, Option<String>)> {
    let mut services = quadlet::discover(dir)?;
    let error = systemd::refresh_services(&mut services)
        .err()
        .map(|error| error.to_string());
    Ok((services, error))
}

fn find_service<'a>(services: &'a [Service], name: &str) -> Result<&'a Service> {
    services
        .iter()
        .find(|service| service.name == name)
        .ok_or_else(|| anyhow::anyhow!("unknown service '{name}'; run `svc list`"))
}

fn services_for_names<'a>(services: &'a [Service], names: &[String]) -> Result<Vec<&'a Service>> {
    if names.is_empty() {
        bail!("at least one service is required");
    }
    names
        .iter()
        .map(|name| find_service(services, name))
        .collect()
}

fn main() -> Result<()> {
    let cli = Cli::parse();
    if matches!(cli.command, None | Some(Commands::Ui)) {
        return tui::run(cli.quadlet_dir);
    }

    let (services, global_error) = load_services(&cli.quadlet_dir)?;
    match cli.command.expect("handled UI above") {
        Commands::Ui => unreachable!(),
        Commands::List | Commands::Status { service: None } => {
            output::print_services(&services, cli.json, global_error.as_deref())
        }
        Commands::Status {
            service: Some(name),
        } => operations::show_status(find_service(&services, &name)?),
        Commands::Logs { service, lines } => {
            operations::follow_logs(find_service(&services, &service)?, lines)
        }
        Commands::Start { services: names } => {
            for service in services_for_names(&services, &names)? {
                operations::systemctl_action("start", service, false)?;
            }
            Ok(())
        }
        Commands::Stop { services: names } => {
            for service in services_for_names(&services, &names)? {
                operations::systemctl_action("stop", service, false)?;
            }
            Ok(())
        }
        Commands::Restart { services: names } => {
            for service in services_for_names(&services, &names)? {
                operations::systemctl_action("restart", service, false)?;
            }
            Ok(())
        }
        Commands::Shell { service, shell } => {
            operations::container_shell(find_service(&services, &service)?, &shell, false)
        }
        Commands::Pull { services: names } => {
            for service in services_for_names(&services, &names)? {
                operations::pull_service(service, false)?;
            }
            Ok(())
        }
        Commands::Stack { action } => match action {
            StackAction::Status => {
                output::print_services(&services, cli.json, global_error.as_deref())
            }
            StackAction::Start => {
                for service in &services {
                    operations::systemctl_action("start", service, false)?;
                }
                Ok(())
            }
            StackAction::Stop => {
                for service in services.iter().rev() {
                    operations::systemctl_action("stop", service, false)?;
                }
                Ok(())
            }
            StackAction::Restart => {
                for service in services.iter().rev() {
                    operations::systemctl_action("stop", service, false)?;
                }
                for service in &services {
                    operations::systemctl_action("start", service, false)?;
                }
                Ok(())
            }
            StackAction::Pull => {
                for service in &services {
                    operations::pull_service(service, false)?;
                }
                Ok(())
            }
        },
    }
}
