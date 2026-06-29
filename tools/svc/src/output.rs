use anyhow::Result;

use crate::model::{Service, ServiceState};

pub fn print_services(services: &[Service], json: bool, global_error: Option<&str>) -> Result<()> {
    if json {
        println!("{}", serde_json::to_string_pretty(services)?);
        return Ok(());
    }
    if let Some(error) = global_error {
        eprintln!("warning: {error}");
    }
    if services.is_empty() {
        println!("No Quadlet services discovered.");
        return Ok(());
    }
    println!("{:<22} {:<15} {:<9} IMAGE", "SERVICE", "STATE", "STARTUP");
    println!("{}", "─".repeat(90));
    for service in services {
        println!(
            "{:<22} {:<15} {:<9} {}",
            service.name,
            service.state.label(),
            service.startup,
            service.image.as_deref().unwrap_or("—")
        );
        if let Some(error) = &service.query_error {
            println!("  ! {error}");
        }
    }
    let running = services
        .iter()
        .filter(|s| s.state == ServiceState::Running)
        .count();
    let failed = services
        .iter()
        .filter(|s| matches!(s.state, ServiceState::Failed | ServiceState::Unavailable))
        .count();
    println!(
        "\n{} total · {} running · {} attention",
        services.len(),
        running,
        failed
    );
    Ok(())
}
