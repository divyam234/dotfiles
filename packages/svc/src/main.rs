mod cli;
mod model;
mod operations;
mod output;
mod privilege;
mod quadlet;
mod systemd;
mod tui;

use anyhow::{Result, bail};
use clap::{CommandFactory, Parser};
use clap_complete::{Shell, generate};

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

fn print_completions(shell: Shell) {
    let mut generated = Vec::new();
    generate(shell, &mut Cli::command(), "svc", &mut generated);
    let generated = String::from_utf8(generated).expect("completion output is UTF-8");
    for line in generated.lines().filter(|line| {
        !line.contains("using_subcommand __complete-services")
            && !line.ends_with("-a \"__complete-services\"")
    }) {
        println!("{line}");
    }
    if shell == Shell::Fish {
        println!(
            r#"function __fish_svc_services
    set -l quadlet_dir
    set -l next_is_dir 0
    for token in (commandline -opc)[2..]
        if test $next_is_dir -eq 1
            set quadlet_dir $token
            set next_is_dir 0
        else if test $token = --quadlet-dir
            set next_is_dir 1
        else if string match -q -- '--quadlet-dir=*' $token
            set quadlet_dir (string replace -- '--quadlet-dir=' '' $token)
        end
    end
    if test -n "$quadlet_dir"
        command svc --quadlet-dir "$quadlet_dir" __complete-services 2>/dev/null
    else
        command svc __complete-services 2>/dev/null
    end
end"#
        );
        println!("complete -c svc -n '__fish_svc_needs_command' -f -a 'ls' -d 'Alias for list'");
        println!("complete -c svc -n '__fish_svc_needs_command' -f -a 'log' -d 'Alias for logs'");
        println!("complete -c svc -n '__fish_svc_needs_command' -f -a 'sh' -d 'Alias for shell'");
        println!(
            "complete -c svc -f -n '__fish_svc_using_subcommand status logs log start stop restart shell sh pull update' -a '(__fish_svc_services)'"
        );
    }
}

fn main() -> Result<()> {
    let cli = Cli::parse();
    if matches!(cli.command, None | Some(Commands::Ui)) {
        return tui::run(cli.quadlet_dir);
    }

    match cli.command.as_ref() {
        Some(Commands::Completions { shell }) => {
            print_completions(*shell);
            return Ok(());
        }
        Some(Commands::CompleteServices) => {
            for service in quadlet::discover(&cli.quadlet_dir)? {
                println!("{}", service.name);
            }
            return Ok(());
        }
        _ => {}
    }

    let (services, global_error) = load_services(&cli.quadlet_dir)?;
    match cli.command.expect("handled UI above") {
        Commands::Ui => unreachable!(),
        Commands::Completions { .. } | Commands::CompleteServices => unreachable!(),
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
        Commands::Update { services: names } => {
            for service in services_for_names(&services, &names)? {
                operations::update_service(service, false)?;
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
