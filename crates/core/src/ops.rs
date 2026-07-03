use std::io;
use std::path::{Path, PathBuf};

pub async fn create_folder(parent: &Path, name: &str) -> io::Result<PathBuf> {
    let target = parent.join(name);
    tokio::fs::create_dir(&target).await?;
    Ok(target)
}

pub async fn rename(path: &Path, new_name: &str) -> io::Result<PathBuf> {
    let parent = path
        .parent()
        .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidInput, "path has no parent"))?;
    let target = parent.join(new_name);
    tokio::fs::rename(path, &target).await?;
    Ok(target)
}
