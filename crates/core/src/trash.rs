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

pub async fn empty_trash() -> io::Result<()> {
    let data_home = dirs::data_dir()
        .ok_or_else(|| io::Error::new(io::ErrorKind::NotFound, "XDG data dir not found"))?;
    empty_trash_in(&data_home).await
}

pub async fn empty_trash_in(data_home: &Path) -> io::Result<()> {
    let files_dir = data_home.join("Trash").join("files");
    let info_dir = data_home.join("Trash").join("info");
    remove_dir_contents(&files_dir).await?;
    remove_dir_contents(&info_dir).await?;
    Ok(())
}

async fn remove_dir_contents(dir: &Path) -> io::Result<()> {
    let mut entries = match tokio::fs::read_dir(dir).await {
        Ok(entries) => entries,
        Err(e) if e.kind() == io::ErrorKind::NotFound => return Ok(()),
        Err(e) => return Err(e),
    };
    while let Some(entry) = entries.next_entry().await? {
        let path = entry.path();
        if entry.metadata().await?.is_dir() {
            tokio::fs::remove_dir_all(&path).await?;
        } else {
            tokio::fs::remove_file(&path).await?;
        }
    }
    Ok(())
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

pub async fn restore(trashed_path: &Path) -> io::Result<PathBuf> {
    let data_home = dirs::data_dir()
        .ok_or_else(|| io::Error::new(io::ErrorKind::NotFound, "XDG data dir not found"))?;
    restore_in(trashed_path, &data_home).await
}

pub async fn restore_in(trashed_path: &Path, data_home: &Path) -> io::Result<PathBuf> {
    let info_dir = data_home.join("Trash").join("info");
    let trash_name = trashed_path
        .file_name()
        .and_then(|n| n.to_str())
        .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidInput, "path has no file name"))?;
    let info_path = info_dir.join(format!("{trash_name}.trashinfo"));

    let info_contents = tokio::fs::read_to_string(&info_path).await?;
    let original_path = parse_trashinfo_path(&info_contents)?;

    if let Some(parent) = original_path.parent() {
        tokio::fs::create_dir_all(parent).await?;
    }
    let destination = unique_restore_destination(&original_path);

    tokio::fs::rename(trashed_path, &destination).await?;
    tokio::fs::remove_file(&info_path).await?;

    Ok(destination)
}

fn parse_trashinfo_path(contents: &str) -> io::Result<PathBuf> {
    contents
        .lines()
        .find_map(|line| line.strip_prefix("Path="))
        .map(PathBuf::from)
        .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidData, "trashinfo missing Path="))
}

fn unique_restore_destination(original: &Path) -> PathBuf {
    if !original.exists() {
        return original.to_path_buf();
    }
    let parent = original.parent().unwrap_or_else(|| Path::new(""));
    let stem = original
        .file_stem()
        .and_then(|s| s.to_str())
        .unwrap_or_default();
    let ext = original.extension().and_then(|s| s.to_str());

    let mut candidate = match ext {
        Some(ext) => parent.join(format!("{stem} (restored).{ext}")),
        None => parent.join(format!("{stem} (restored)")),
    };
    let mut n = 2;
    while candidate.exists() {
        candidate = match ext {
            Some(ext) => parent.join(format!("{stem} (restored {n}).{ext}")),
            None => parent.join(format!("{stem} (restored {n})")),
        };
        n += 1;
    }
    candidate
}

pub async fn delete_permanently(trashed_path: &Path) -> io::Result<()> {
    let data_home = dirs::data_dir()
        .ok_or_else(|| io::Error::new(io::ErrorKind::NotFound, "XDG data dir not found"))?;
    delete_permanently_in(trashed_path, &data_home).await
}

pub async fn delete_permanently_in(trashed_path: &Path, data_home: &Path) -> io::Result<()> {
    let info_dir = data_home.join("Trash").join("info");
    let trash_name = trashed_path
        .file_name()
        .and_then(|n| n.to_str())
        .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidInput, "path has no file name"))?;
    let info_path = info_dir.join(format!("{trash_name}.trashinfo"));

    if tokio::fs::metadata(trashed_path).await?.is_dir() {
        tokio::fs::remove_dir_all(trashed_path).await?;
    } else {
        tokio::fs::remove_file(trashed_path).await?;
    }
    let _ = tokio::fs::remove_file(&info_path).await;
    Ok(())
}
