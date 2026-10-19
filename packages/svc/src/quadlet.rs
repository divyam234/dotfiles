use std::{ffi::OsStr, fs, path::Path};

use anyhow::{Context, Result, anyhow};

use crate::model::Service;

pub fn discover(dir: &Path) -> Result<Vec<Service>> {
    if !dir.exists() {
        return Ok(Vec::new());
    }
    let mut services = Vec::new();
    for entry in fs::read_dir(dir).with_context(|| format!("read {}", dir.display()))? {
        let path = entry?.path();
        if path.extension() != Some(OsStr::new("container")) {
            continue;
        }
        let name = path
            .file_stem()
            .and_then(OsStr::to_str)
            .ok_or_else(|| anyhow!("invalid Quadlet file name: {}", path.display()))?
            .to_owned();
        let content =
            fs::read_to_string(&path).with_context(|| format!("read {}", path.display()))?;
        let container_name = value_in_section(&content, "Container", "ContainerName")
            .unwrap_or_else(|| name.clone());
        services.push(Service::new(
            name,
            container_name,
            value_in_section(&content, "Container", "Image"),
            value_in_section(&content, "Unit", "Description"),
            path,
        ));
    }
    services.sort_by(|a, b| a.name.cmp(&b.name));
    Ok(services)
}

pub fn value_in_section(content: &str, section: &str, key: &str) -> Option<String> {
    let mut current = "";
    for raw in content.lines() {
        let line = raw.trim();
        if line.is_empty() || line.starts_with('#') || line.starts_with(';') {
            continue;
        }
        if line.starts_with('[') && line.ends_with(']') {
            current = &line[1..line.len() - 1];
            continue;
        }
        if current == section
            && let Some((candidate, value)) = line.split_once('=')
            && candidate.trim() == key
        {
            return Some(value.trim().to_owned());
        }
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;

    #[test]
    fn parses_container_name_and_image() {
        let text = "[Container]\nImage=example/app:1\nContainerName=real-app\n";
        assert_eq!(
            value_in_section(text, "Container", "ContainerName").as_deref(),
            Some("real-app")
        );
        assert_eq!(
            value_in_section(text, "Container", "Image").as_deref(),
            Some("example/app:1")
        );
    }

    #[test]
    fn discovers_only_containers_and_falls_back_name() {
        let dir = tempfile::tempdir().unwrap();
        let mut file = fs::File::create(dir.path().join("alpha.container")).unwrap();
        writeln!(file, "[Container]\nImage=example/alpha:1").unwrap();
        fs::write(dir.path().join("svc.network"), "[Network]").unwrap();
        let services = discover(dir.path()).unwrap();
        assert_eq!(services.len(), 1);
        assert_eq!(services[0].container_name, "alpha");
    }
}
