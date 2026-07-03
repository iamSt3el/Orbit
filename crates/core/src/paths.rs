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
