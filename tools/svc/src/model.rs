use std::path::PathBuf;

use ratatui::style::Color;
use serde::Serialize;

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum ServiceState {
    Running,
    Starting,
    Stopping,
    Stopped,
    Failed,
    Unavailable,
    Unknown,
}

impl ServiceState {
    pub fn from_active_state(value: &str) -> Self {
        match value.trim() {
            "active" => Self::Running,
            "activating" => Self::Starting,
            "deactivating" => Self::Stopping,
            "inactive" => Self::Stopped,
            "failed" => Self::Failed,
            "" => Self::Unavailable,
            _ => Self::Unknown,
        }
    }

    pub fn label(&self) -> &'static str {
        match self {
            Self::Running => "● running",
            Self::Starting => "◐ starting",
            Self::Stopping => "◑ stopping",
            Self::Stopped => "○ stopped",
            Self::Failed => "× failed",
            Self::Unavailable => "! unavailable",
            Self::Unknown => "? unknown",
        }
    }

    pub fn color(&self) -> Color {
        match self {
            Self::Running => Color::Green,
            Self::Starting | Self::Stopping => Color::Yellow,
            Self::Stopped => Color::DarkGray,
            Self::Failed | Self::Unavailable => Color::Red,
            Self::Unknown => Color::Magenta,
        }
    }
}

#[derive(Debug, Clone, Serialize)]
pub struct Service {
    pub name: String,
    pub container_name: String,
    pub unit: String,
    pub image: Option<String>,
    pub description: Option<String>,
    pub file: PathBuf,
    pub state: ServiceState,
    pub startup: String,
    pub sub_state: String,
    pub load_state: String,
    pub query_error: Option<String>,
}

impl Service {
    pub fn new(
        name: String,
        container_name: String,
        image: Option<String>,
        description: Option<String>,
        file: PathBuf,
    ) -> Self {
        let unit = format!("{name}.service");
        Self {
            name,
            container_name,
            unit,
            image,
            description,
            file,
            state: ServiceState::Unavailable,
            startup: "unknown".into(),
            sub_state: "unknown".into(),
            load_state: "unknown".into(),
            query_error: None,
        }
    }
}

pub fn normalize_startup(value: &str) -> String {
    match value.trim() {
        "enabled" | "linked" | "linked-runtime" | "static" | "generated" | "indirect" | "alias" => {
            "auto".into()
        }
        "disabled" => "manual".into(),
        "" => "unknown".into(),
        other => other.into(),
    }
}
