mod cli;
mod model;
mod operations;
mod output;
mod privilege;
mod quadlet;
mod systemd;
mod tui;

use std::{io::IsTerminal, process::ExitCode, time::Duration};

use anyhow::{Result, bail};
use clap::{CommandFactory, Parser};
use clap_complete::{Shell, generate};

use crate::{
    cli::{Cli, Commands, StackAction},
    model::{Freshness, OutdatedEntry, Service, ServiceState},
    operations::ExecOptions,
};

/// Process exit codes (see `--help` for the documented contract).
pub const EXIT_OK: u8 = 0;
pub const EXIT_ERROR: u8 = 1;
/// Multi-service action where at least one service succeeded and one failed.
/// (Clap usage errors also exit 2; stderr disambiguates.)
pub const EXIT_PARTIAL: u8 = 2;

fn exec_options(cli: &Cli) -> ExecOptions {
    ExecOptions::cli(cli.dry_run, Duration::from_secs(cli.timeout_secs.max(1)))
}

fn init_tracing(verbose: u8) {
    use tracing_subscriber::{EnvFilter, fmt};
    let level = match verbose {
        0 => "warn",
        1 => "info",
        _ => "debug",
    };
    let filter = EnvFilter::try_from_env("SVC_LOG")
        .unwrap_or_else(|_| EnvFilter::new(format!("svc={level}")));
    let _ = fmt()
        .with_env_filter(filter)
        .with_writer(std::io::stderr)
        .try_init();
}

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

fn print_man() {
    use std::io::Write;
    let man = clap_mangen::Man::new(Cli::command());
    let mut buffer = Vec::new();
    man.render(&mut buffer).expect("man page renders");
    let text = String::from_utf8(buffer).expect("man page is UTF-8");
    // Piping to `head` closes stdout early; that is normal Unix behavior,
    // not a crash.
    if let Err(error) = write!(std::io::stdout(), "{text}") {
        if error.kind() != std::io::ErrorKind::BrokenPipe {
            eprintln!("svc: error: failed to write man page: {error:#}");
            std::process::exit(EXIT_ERROR.into());
        }
    }
}

fn print_completions(shell: Shell) {
    use std::fmt::Write as _;
    let mut generated = Vec::new();
    generate(shell, &mut Cli::command(), "svc", &mut generated);
    let generated = String::from_utf8(generated).expect("completion output is UTF-8");
    let mut output = String::new();
    for line in generated.lines().filter(|line| {
        !line.contains("using_subcommand __complete-services")
            && !line.ends_with("-a \"__complete-services\"")
    }) {
        let _ = writeln!(output, "{line}");
    }
    if shell == Shell::Fish {
        let _ = writeln!(
            output,
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
        let _ = writeln!(
            output,
            "complete -c svc -n '__fish_svc_needs_command' -f -a 'ls' -d 'Alias for list'"
        );
        let _ = writeln!(
            output,
            "complete -c svc -n '__fish_svc_needs_command' -f -a 'log' -d 'Alias for logs'"
        );
        let _ = writeln!(
            output,
            "complete -c svc -n '__fish_svc_needs_command' -f -a 'sh' -d 'Alias for shell'"
        );
        let _ = writeln!(
            output,
            "complete -c svc -f -n '__fish_svc_using_subcommand status logs log start stop restart shell sh pull update outdated enable disable exec daemon-reload' -a '(__fish_svc_services)'"
        );
    }
    // Piping to `head` closes stdout early; that is normal, not a crash.
    use std::io::Write as _;
    if let Err(error) = write!(std::io::stdout(), "{output}") {
        if error.kind() != std::io::ErrorKind::BrokenPipe {
            eprintln!("svc: error: failed to write completions: {error:#}");
            std::process::exit(EXIT_ERROR.into());
        }
    }
}

fn confirm_update(names: &[String], yes: bool) -> Result<()> {
    if yes {
        return Ok(());
    }
    if !std::io::stdin().is_terminal() {
        bail!("refusing to update without --yes in non-interactive mode");
    }
    eprint!(
        "svc: update {}? services will be stopped [y/N] ",
        names.join(", ")
    );
    let mut answer = String::new();
    std::io::stdin().read_line(&mut answer)?;
    if answer.trim().eq_ignore_ascii_case("y") {
        Ok(())
    } else {
        bail!("update cancelled");
    }
}

/// Run `op` for every target, collecting failures instead of aborting early.
///
/// Returns [`EXIT_OK`] when all succeed, [`EXIT_ERROR`] when all fail or no
/// targets were attempted, and [`EXIT_PARTIAL`] on a mixed outcome.
fn apply_to_many(
    action: &str,
    targets: Vec<&Service>,
    op: impl Fn(&Service) -> Result<()>,
) -> ExitCode {
    let total = targets.len();
    let mut failures = Vec::new();
    for service in targets {
        if let Err(error) = op(service) {
            eprintln!("svc: {action} {} failed: {error:#}", service.name);
            failures.push(service.name.clone());
        }
    }
    let failed = output::print_action_summary(action, total, &failures);
    ExitCode::from(if failed == 0 {
        EXIT_OK
    } else if failed == total {
        EXIT_ERROR
    } else {
        EXIT_PARTIAL
    })
}

fn needs_attention(service: &Service) -> bool {
    matches!(
        service.state,
        ServiceState::Failed | ServiceState::Unavailable
    )
}

fn run_list(
    quadlet_dir: &std::path::Path,
    json: bool,
    failed_only: bool,
    watch: Option<u64>,
) -> Result<ExitCode> {
    use std::io::Write;
    loop {
        // State is reloaded on every tick; discovery is cheap and
        // `systemctl show` is a single batched call.
        let (services, global_error) = load_services(quadlet_dir)?;
        let view: Vec<Service> = services
            .into_iter()
            .filter(|service| !failed_only || needs_attention(service))
            .collect();
        if watch.is_some() && std::io::stdout().is_terminal() {
            print!("\x1b[2J\x1b[H");
            std::io::stdout().flush().ok();
        }
        if view.is_empty() && failed_only && !json {
            println!("All services healthy.");
        } else {
            output::print_services(&view, json, global_error.as_deref())?;
        }
        match watch {
            None => break,
            Some(secs) => std::thread::sleep(Duration::from_secs(secs.max(1))),
        }
    }
    Ok(ExitCode::SUCCESS)
}

fn run_outdated(
    services: &[Service],
    names: &[String],
    opts: ExecOptions,
    json: bool,
) -> Result<ExitCode> {
    let targets: Vec<&Service> = if names.is_empty() {
        services.iter().collect()
    } else {
        services_for_names(services, names)?
    };
    let mut entries = Vec::new();
    let mut failed = false;
    for target in targets {
        match operations::check_updates(target, opts) {
            Ok(status) => entries.push(OutdatedEntry {
                service: target.name.clone(),
                image: target.image.clone(),
                status,
            }),
            Err(error) => {
                eprintln!("svc: outdated {} failed: {error:#}", target.name);
                failed = true;
            }
        }
    }
    output::print_outdated(&entries, json)?;
    if failed {
        return Ok(ExitCode::from(EXIT_ERROR));
    }
    if entries
        .iter()
        .any(|entry| entry.status == Freshness::Pending)
    {
        return Ok(ExitCode::from(EXIT_PARTIAL));
    }
    Ok(ExitCode::SUCCESS)
}

fn main() -> ExitCode {
    let cli = match Cli::try_parse() {
        Ok(cli) => cli,
        Err(error) => error.exit(),
    };
    init_tracing(cli.verbose);
    match run(cli) {
        Ok(code) => code,
        Err(error) => {
            eprintln!("svc: error: {error:#}");
            ExitCode::from(EXIT_ERROR)
        }
    }
}

fn run(cli: Cli) -> Result<ExitCode> {
    let opts = exec_options(&cli);
    if matches!(cli.command, None | Some(Commands::Ui)) {
        return tui::run(
            cli.quadlet_dir,
            cli.dry_run,
            opts.timeout,
            Duration::from_secs(cli.refresh_secs.max(1)),
        )
        .map(|()| ExitCode::SUCCESS);
    }

    match cli.command.as_ref() {
        Some(Commands::Completions { shell }) => {
            print_completions(*shell);
            return Ok(ExitCode::SUCCESS);
        }
        Some(Commands::Man) => {
            print_man();
            return Ok(ExitCode::SUCCESS);
        }
        Some(Commands::CompleteServices) => {
            for service in quadlet::discover(&cli.quadlet_dir)? {
                println!("{}", service.name);
            }
            return Ok(ExitCode::SUCCESS);
        }
        _ => {}
    }

    let (services, global_error) = load_services(&cli.quadlet_dir)?;
    let command = cli.command.expect("handled UI above");
    let code = match command {
        Commands::Ui => unreachable!(),
        Commands::Completions { .. } | Commands::CompleteServices | Commands::Man => {
            unreachable!()
        }
        Commands::List { failed_only, watch } => {
            run_list(&cli.quadlet_dir, cli.json, failed_only, watch)?
        }
        Commands::Status { service: None } => {
            output::print_services(&services, cli.json, global_error.as_deref())?;
            ExitCode::SUCCESS
        }
        Commands::Status {
            service: Some(name),
        } => {
            operations::show_status(find_service(&services, &name)?, opts)?;
            ExitCode::SUCCESS
        }
        Commands::Logs { service, lines } => {
            operations::follow_logs(find_service(&services, &service)?, lines)?;
            ExitCode::SUCCESS
        }
        Commands::Start { services: names } => {
            let targets = services_for_names(&services, &names)?;
            apply_to_many("start", targets, |service| {
                operations::systemctl_action("start", service, opts)
            })
        }
        Commands::Stop { services: names } => {
            let targets = services_for_names(&services, &names)?;
            apply_to_many("stop", targets, |service| {
                operations::systemctl_action("stop", service, opts)
            })
        }
        Commands::Restart { services: names } => {
            let targets = services_for_names(&services, &names)?;
            apply_to_many("restart", targets, |service| {
                operations::systemctl_action("restart", service, opts)
            })
        }
        Commands::Shell { service, shell } => {
            operations::container_shell(find_service(&services, &service)?, &shell, opts)?;
            ExitCode::SUCCESS
        }
        Commands::Exec { service, command } => {
            operations::container_exec(find_service(&services, &service)?, &command, opts)?;
            ExitCode::SUCCESS
        }
        Commands::Enable { services: names } => {
            let targets = services_for_names(&services, &names)?;
            apply_to_many("enable", targets, |service| {
                operations::systemctl_action("enable", service, opts)
            })
        }
        Commands::Disable { services: names } => {
            let targets = services_for_names(&services, &names)?;
            apply_to_many("disable", targets, |service| {
                operations::systemctl_action("disable", service, opts)
            })
        }
        Commands::DaemonReload => {
            operations::daemon_reload(opts)?;
            println!("svc: daemon reloaded");
            ExitCode::SUCCESS
        }
        Commands::Outdated { services: names } => run_outdated(&services, &names, opts, cli.json)?,
        Commands::Pull { services: names } => {
            let targets = services_for_names(&services, &names)?;
            apply_to_many("pull", targets, |service| {
                operations::pull_service(service, opts)
            })
        }
        Commands::Update {
            services: names,
            yes,
        } => {
            let targets = services_for_names(&services, &names)?;
            let names: Vec<String> = targets.iter().map(|service| service.name.clone()).collect();
            confirm_update(&names, yes)?;
            for report in operations::update_services(&services, &targets, opts)? {
                println!("svc: {}: {}", report.name, report.describe());
            }
            ExitCode::SUCCESS
        }
        Commands::Stack { action } => match action {
            StackAction::Status => {
                output::print_services(&services, cli.json, global_error.as_deref())?;
                ExitCode::SUCCESS
            }
            StackAction::Start => {
                let targets: Vec<&Service> = services.iter().collect();
                apply_to_many("start", targets, |service| {
                    operations::systemctl_action("start", service, opts)
                })
            }
            StackAction::Stop => {
                let targets: Vec<&Service> = services.iter().rev().collect();
                apply_to_many("stop", targets, |service| {
                    operations::systemctl_action("stop", service, opts)
                })
            }
            StackAction::Restart => {
                let stop: Vec<&Service> = services.iter().rev().collect();
                let code = apply_to_many("stop", stop, |service| {
                    operations::systemctl_action("stop", service, opts)
                });
                if code != ExitCode::SUCCESS {
                    return Ok(code);
                }
                let start: Vec<&Service> = services.iter().collect();
                apply_to_many("start", start, |service| {
                    operations::systemctl_action("start", service, opts)
                })
            }
            StackAction::Pull => {
                let targets: Vec<&Service> = services.iter().collect();
                apply_to_many("pull", targets, |service| {
                    operations::pull_service(service, opts)
                })
            }
        },
    };
    Ok(code)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;

    fn service(name: &str) -> Service {
        Service::new(
            name.into(),
            name.into(),
            None,
            None,
            PathBuf::from(format!("{name}.container")),
        )
    }

    #[test]
    fn aggregation_reports_success_failure_and_partial_codes() {
        let services = [service("a"), service("b")];
        let refs: Vec<&Service> = services.iter().collect();
        assert_eq!(
            apply_to_many("start", refs.clone(), |_| Ok(())),
            ExitCode::SUCCESS
        );
        assert_eq!(
            apply_to_many("start", refs.clone(), |_| Err(anyhow::anyhow!("boom"))),
            ExitCode::from(EXIT_ERROR)
        );
        assert_eq!(
            apply_to_many("start", refs, |service| if service.name == "a" {
                Ok(())
            } else {
                Err(anyhow::anyhow!("boom"))
            }),
            ExitCode::from(EXIT_PARTIAL)
        );
    }

    #[test]
    fn confirm_update_with_yes_skips_prompt() {
        confirm_update(&["a".to_owned()], true).unwrap();
    }

    #[test]
    fn confirm_update_refuses_without_yes_when_stdin_is_not_a_tty() {
        if std::io::stdin().is_terminal() {
            return;
        }
        confirm_update(&["a".to_owned()], false).unwrap_err();
    }
}
