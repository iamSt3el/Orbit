use std::io;
use std::path::{Path, PathBuf};
use time::format_description::well_known::Iso8601;
use time::OffsetDateTime;

pub async fn move_to_trash(path: &Path) -> io::Result<PathBuf> {
    let data_home = dirs::data_dir()
        .ok_or_else(|| io::Error::new(io::ErrorKind::NotFound, "XDG data dir not found"))?;
    move_to_trash_in(path, &data_home).await
}

pub async fn move_to_trash_in(path: &Path, data_home: &Path) -> io::Result<PathBuf> {
    let files_dir = data_home.join("Trash").join("files");
    let info_dir = data_home.join("Trash").join("info");
    tokio::fs::create_dir_all(&files_dir).await?;
    tokio::fs::create_dir_all(&info_dir).await?;

    let original_name = path
        .file_name()
        .and_then(|n| n.to_str())
        .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidInput, "path has no file name"))?
        .to_string();

    let trash_name = unique_trash_name(&files_dir, &original_name);
    let trashed_path = files_dir.join(&trash_name);
    let info_path = info_dir.join(format!("{trash_name}.trashinfo"));

    let absolute_path = if path.is_absolute() {
        path.to_path_buf()
    } else {
        std::env::current_dir()?.join(path)
    };

    tokio::fs::write(&info_path, trash_info_contents(&absolute_path)?).await?;
    tokio::fs::rename(path, &trashed_path).await?;

    Ok(trashed_path)
}

fn unique_trash_name(files_dir: &Path, original_name: &str) -> String {
    let path = Path::new(original_name);
    let stem = path
        .file_stem()
        .and_then(|s| s.to_str())
        .unwrap_or(original_name);
    let ext = path.extension().and_then(|s| s.to_str());

    let mut candidate = original_name.to_string();
    let mut counter = 1;
    while files_dir.join(&candidate).exists() {
        candidate = match ext {
            Some(ext) => format!("{stem}_{counter}.{ext}"),
            None => format!("{stem}_{counter}"),
        };
        counter += 1;
    }
    candidate
}

fn trash_info_contents(original_path: &Path) -> io::Result<String> {
    let deletion_date = OffsetDateTime::now_utc()
        .format(&Iso8601::DEFAULT)
        .map_err(|e| io::Error::new(io::ErrorKind::Other, e.to_string()))?;
    Ok(format!(
        "[Trash Info]\nPath={}\nDeletionDate={}\n",
        original_path.display(),
        deletion_date
    ))
}
