use serde::{Deserialize, Serialize};
use std::path::PathBuf;

/// Persisted user preferences — view mode, sort order, icon size, etc.
/// Stored as JSON at `~/.config/filemanager/settings.json`, alongside the
/// optional external theme color file.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(default)]
pub struct Settings {
    pub view_mode: String,
    pub icon_size_level: String,
    pub sort_key: String,
    pub sort_ascending: bool,
    pub show_hidden: bool,
    pub last_path: String,
}

impl Default for Settings {
    fn default() -> Self {
        Self {
            view_mode: "list".to_string(),
            icon_size_level: "medium".to_string(),
            sort_key: "name".to_string(),
            sort_ascending: true,
            show_hidden: false,
            last_path: String::new(),
        }
    }
}

fn settings_path() -> Option<PathBuf> {
    crate::paths::app_config_dir().map(|dir| dir.join("settings.json"))
}

impl Settings {
    /// Falls back to `Settings::default()` if the file is missing, unreadable,
    /// or not valid JSON — a corrupt or absent settings file should never
    /// stop the app from starting.
    pub fn load() -> Self {
        match settings_path() {
            Some(path) => Self::load_from(&path),
            None => Self::default(),
        }
    }

    pub fn save(&self) -> std::io::Result<()> {
        match settings_path() {
            Some(path) => self.save_to(&path),
            None => Ok(()),
        }
    }

    pub fn load_from(path: &std::path::Path) -> Self {
        let Ok(contents) = std::fs::read_to_string(path) else {
            return Self::default();
        };
        serde_json::from_str(&contents).unwrap_or_default()
    }

    pub fn save_to(&self, path: &std::path::Path) -> std::io::Result<()> {
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent)?;
        }
        let json = serde_json::to_string_pretty(self)
            .map_err(|e| std::io::Error::new(std::io::ErrorKind::Other, e))?;
        std::fs::write(path, json)
    }
}
