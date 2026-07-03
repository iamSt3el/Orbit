use std::future::Future;
use std::io;
use std::path::{Path, PathBuf};
use std::pin::Pin;

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

pub fn copy<'a>(
    src: &'a Path,
    dst: &'a Path,
) -> Pin<Box<dyn Future<Output = io::Result<()>> + Send + 'a>> {
    Box::pin(async move {
        let metadata = tokio::fs::metadata(src).await?;

        if metadata.is_dir() {
            tokio::fs::create_dir_all(dst).await?;
            let mut read_dir = tokio::fs::read_dir(src).await?;
            while let Some(dir_entry) = read_dir.next_entry().await? {
                let child_src = dir_entry.path();
                let child_dst = dst.join(dir_entry.file_name());
                copy(&child_src, &child_dst).await?;
            }
            Ok(())
        } else {
            tokio::fs::copy(src, dst).await?;
            Ok(())
        }
    })
}
