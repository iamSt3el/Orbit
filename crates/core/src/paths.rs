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

pub fn expand_tilde(input: &str) -> String {
    if input == "~" {
        return home_dir()
            .map(|h| h.display().to_string())
            .unwrap_or_else(|| input.to_string());
    }
    if let Some(rest) = input.strip_prefix("~/") {
        if let Some(home) = home_dir() {
            return format!("{}/{}", home.display(), rest);
        }
    }
    input.to_string()
}

pub fn complete_dir(partial: &str) -> Option<String> {
    let expanded = expand_tilde(partial);
    let slash = expanded.rfind('/')?;
    let (parent, prefix) = expanded.split_at(slash + 1);
    let parent_path = std::path::Path::new(if parent.is_empty() { "/" } else { parent });
    let prefix_lower = prefix.to_lowercase();
    let mut matches: Vec<String> = std::fs::read_dir(parent_path)
        .ok()?
        .filter_map(|entry| entry.ok())
        .filter(|entry| entry.path().is_dir())
        .filter_map(|entry| entry.file_name().into_string().ok())
        .filter(|name| {
            name.to_lowercase().starts_with(&prefix_lower)
                && (prefix.starts_with('.') || !name.starts_with('.'))
        })
        .collect();
    if matches.is_empty() {
        return None;
    }
    if matches.len() == 1 {
        return Some(format!("{}{}/", parent, matches.remove(0)));
    }
    matches.sort();
    let first = &matches[0];
    let mut common = first.len();
    for name in &matches[1..] {
        common = first
            .char_indices()
            .zip(name.char_indices())
            .take_while(|((_, a), (_, b))| a.to_lowercase().eq(b.to_lowercase()))
            .last()
            .map(|((i, c), _)| i + c.len_utf8())
            .unwrap_or(0)
            .min(common);
    }
    if common > prefix.len() {
        Some(format!("{}{}", parent, &first[..common]))
    } else {
        Some(expanded)
    }
}
