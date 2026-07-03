use std::path::PathBuf;

pub fn home_dir() -> Option<PathBuf> {
    dirs::home_dir()
}

pub fn download_dir() -> Option<PathBuf> {
    dirs::download_dir()
}

pub fn document_dir() -> Option<PathBuf> {
    dirs::document_dir()
}

/// The freedesktop.org Trash spec's files directory — where `trash::move_to_trash`
/// actually places deleted entries, so this is where a "Trash" shortcut should browse.
pub fn trash_dir() -> Option<PathBuf> {
    dirs::data_dir().map(|dir| dir.join("Trash").join("files"))
}

/// This app's own config directory (`~/.config/filemanager`) — currently
/// only used to look for an external theme color file dropped in by
/// another tool.
pub fn app_config_dir() -> Option<PathBuf> {
    dirs::config_dir().map(|dir| dir.join("filemanager"))
}

/// Where an external tool (e.g. a wallpaper-based Material You color
/// generator) can place a JSON color file for this app to pick up instead
/// of its own generated defaults.
pub fn theme_colors_path() -> Option<PathBuf> {
    app_config_dir().map(|dir| dir.join("colors.json"))
}
