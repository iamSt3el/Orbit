use std::future::Future;
use std::io;
use std::path::{Path, PathBuf};
use std::pin::Pin;

pub async fn create_folder(parent: &Path, name: &str) -> io::Result<PathBuf> {
    let target = parent.join(name);
    tokio::fs::create_dir(&target).await?;
    Ok(target)
}

/// Opens a file with the desktop's default handler for its type. Fires the
/// launcher and returns immediately — does not wait for the opened
/// application to exit.
pub async fn open_file(path: &Path) -> io::Result<()> {
    tokio::process::Command::new("xdg-open")
        .arg(path)
        .spawn()?;
    Ok(())
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

/// Copies `path` to a sibling `"name (copy)"` (or `"name (copy N)"` if that's
/// already taken), returning the new path.
pub async fn duplicate(path: &Path) -> io::Result<PathBuf> {
    let parent = path
        .parent()
        .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidInput, "path has no parent"))?;
    let dst = unique_duplicate_name(parent, path);
    copy(path, &dst).await?;
    Ok(dst)
}

fn unique_duplicate_name(parent: &Path, path: &Path) -> PathBuf {
    let stem = path
        .file_stem()
        .and_then(|s| s.to_str())
        .unwrap_or_default();
    let ext = path.extension().and_then(|e| e.to_str());

    let mut candidate = match ext {
        Some(ext) => parent.join(format!("{stem} (copy).{ext}")),
        None => parent.join(format!("{stem} (copy)")),
    };
    let mut n = 2;
    while candidate.exists() {
        candidate = match ext {
            Some(ext) => parent.join(format!("{stem} (copy {n}).{ext}")),
            None => parent.join(format!("{stem} (copy {n})")),
        };
        n += 1;
    }
    candidate
}

/// Opens a terminal emulator with its working directory set to `path`. There
/// is no XDG standard for "the user's terminal" the way `xdg-open` covers
/// files, so this tries a handful of common emulators in order.
pub async fn open_terminal(path: &Path) -> io::Result<()> {
    const CANDIDATES: &[&str] = &[
        "x-terminal-emulator",
        "konsole",
        "gnome-terminal",
        "xterm",
        "alacritty",
        "kitty",
    ];
    for candidate in CANDIDATES {
        if tokio::process::Command::new(candidate)
            .current_dir(path)
            .spawn()
            .is_ok()
        {
            return Ok(());
        }
    }
    Err(io::Error::new(
        io::ErrorKind::NotFound,
        "no terminal emulator found",
    ))
}

pub async fn move_entry(src: &Path, dst: &Path) -> io::Result<()> {
    match tokio::fs::rename(src, dst).await {
        Ok(()) => Ok(()),
        Err(e) if e.raw_os_error() == Some(libc::EXDEV) => {
            copy(src, dst).await?;
            remove_all(src).await
        }
        Err(e) => Err(e),
    }
}

async fn remove_all(path: &Path) -> io::Result<()> {
    let metadata = tokio::fs::metadata(path).await?;
    if metadata.is_dir() {
        tokio::fs::remove_dir_all(path).await
    } else {
        tokio::fs::remove_file(path).await
    }
}
