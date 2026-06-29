use std::{collections::HashMap, process::Command};

use anyhow::{Context, Result, bail};

use crate::model::{Service, ServiceState, normalize_startup};

#[derive(Debug, Default, Clone, PartialEq, Eq)]
pub struct UnitProperties {
    pub id: String,
    pub active_state: String,
    pub sub_state: String,
    pub unit_file_state: String,
    pub load_state: String,
}

pub fn refresh_services(services: &mut [Service]) -> Result<()> {
    if services.is_empty() {
        return Ok(());
    }
    let mut command = Command::new("systemctl");
    command.arg("show");
    for service in services.iter() {
        command.arg(&service.unit);
    }
    command.args([
        "--property=Id",
        "--property=ActiveState",
        "--property=SubState",
        "--property=UnitFileState",
        "--property=LoadState",
        "--no-pager",
    ]);
    let output = command.output().context("run batched systemctl show")?;
    if !output.status.success() {
        let error = String::from_utf8_lossy(&output.stderr).trim().to_owned();
        for service in services {
            service.state = ServiceState::Unavailable;
            service.query_error = Some(error.clone());
        }
        bail!("systemctl show failed: {error}");
    }
    let properties = parse_show_output(&String::from_utf8_lossy(&output.stdout));
    apply_properties(services, &properties);
    Ok(())
}

pub fn parse_show_output(text: &str) -> HashMap<String, UnitProperties> {
    let mut map = HashMap::new();
    let mut current = UnitProperties::default();
    let flush = |current: &mut UnitProperties, map: &mut HashMap<String, UnitProperties>| {
        if !current.id.is_empty() {
            map.insert(current.id.clone(), std::mem::take(current));
        }
    };
    for line in text.lines().chain(std::iter::once("")) {
        if line.is_empty() {
            flush(&mut current, &mut map);
            continue;
        }
        if let Some((key, value)) = line.split_once('=') {
            match key {
                "Id" => current.id = value.into(),
                "ActiveState" => current.active_state = value.into(),
                "SubState" => current.sub_state = value.into(),
                "UnitFileState" => current.unit_file_state = value.into(),
                "LoadState" => current.load_state = value.into(),
                _ => {}
            }
        }
    }
    map
}

pub fn apply_properties(services: &mut [Service], properties: &HashMap<String, UnitProperties>) {
    for service in services {
        match properties.get(&service.unit) {
            Some(props) => {
                service.state = ServiceState::from_active_state(&props.active_state);
                service.startup = normalize_startup(&props.unit_file_state);
                service.sub_state = if props.sub_state.is_empty() {
                    "unknown".into()
                } else {
                    props.sub_state.clone()
                };
                service.load_state = if props.load_state.is_empty() {
                    "unknown".into()
                } else {
                    props.load_state.clone()
                };
                service.query_error = if props.load_state == "not-found" {
                    Some(format!("unit {} not found", service.unit))
                } else {
                    None
                };
            }
            None => {
                service.state = ServiceState::Unavailable;
                service.query_error = Some(format!("no state returned for {}", service.unit));
            }
        }
    }
}

pub fn status_is_acceptable(code: Option<i32>) -> bool {
    matches!(code, Some(0 | 3))
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;

    #[test]
    fn parses_batched_show_output() {
        let parsed = parse_show_output(
            "Id=a.service\nActiveState=active\nSubState=running\nUnitFileState=generated\nLoadState=loaded\n\nId=b.service\nActiveState=inactive\nSubState=dead\nUnitFileState=disabled\nLoadState=loaded\n",
        );
        assert_eq!(parsed.len(), 2);
        assert_eq!(parsed["a.service"].active_state, "active");
        assert_eq!(parsed["b.service"].sub_state, "dead");
    }

    #[test]
    fn applies_missing_state_as_visible_error() {
        let mut services = vec![Service::new(
            "a".into(),
            "a".into(),
            None,
            None,
            PathBuf::from("a.container"),
        )];
        apply_properties(&mut services, &HashMap::new());
        assert_eq!(services[0].state, ServiceState::Unavailable);
        assert!(
            services[0]
                .query_error
                .as_deref()
                .unwrap()
                .contains("no state")
        );
    }

    #[test]
    fn inactive_status_is_not_execution_failure() {
        assert!(status_is_acceptable(Some(0)));
        assert!(status_is_acceptable(Some(3)));
        assert!(!status_is_acceptable(Some(4)));
        assert!(!status_is_acceptable(None));
    }
}
