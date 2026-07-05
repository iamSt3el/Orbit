use std::future::Future;
use std::io;
use std::path::{Path, PathBuf};
use std::pin::Pin;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;
use tokio::sync::mpsc::UnboundedSender;

/// Formats a byte count as a short human-readable string (e.g. "12.4 MB")
/// — used for transfer speed labels (paired with "/s" by the caller) and
/// available for "done / total" displays generally.
pub fn format_bytes(bytes: u64) -> String {
    if bytes < 1024 {
        return format!("{bytes} B");
    }
    const UNITS: [&str; 5] = ["KB", "MB", "GB", "TB", "PB"];
    let mut value = bytes as f64;
    // Starts below the first unit, not at it — the loop always runs at
    // least once here (bytes >= 1024 is guaranteed by the early return
    // above), and that first division is what reaches "KB" (index 0).
    let mut unit_index: i32 = -1;
    while value >= 1024.0 && unit_index < UNITS.len() as i32 - 1 {
        value /= 1024.0;
        unit_index += 1;
    }
    let unit = UNITS[unit_index as usize];
    if value < 10.0 {
        format!("{value:.1} {unit}")
    } else {
        format!("{value:.0} {unit}")
    }
}

pub async fn create_folder(parent: &Path, name: &str) -> io::Result<PathBuf> {
    let target = parent.join(name);
    tokio::fs::create_dir(&target).await?;
    Ok(target)
}

pub async fn create_file(parent: &Path, name: &str) -> io::Result<PathBuf> {
    let target = parent.join(name);
    // create_new: errors with AlreadyExists instead of truncating an
    // existing file — the same never-clobber contract create_folder gets
    // from create_dir failing on an existing directory.
    tokio::fs::File::options()
        .write(true)
        .create_new(true)
        .open(&target)
        .await?;
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

/// Total size in bytes of everything under `path` — itself if it's a file,
/// or the sum of every file in the tree if it's a directory. Used to know
/// the "total" half of a done/total progress display before a copy/move
/// starts. Synchronous (plain std::fs, not tokio) since this is meant to be
/// called once, up front, not from inside a hot copy loop.
pub fn path_size(path: &Path) -> u64 {
    let Ok(metadata) = std::fs::metadata(path) else {
        return 0;
    };
    if metadata.is_dir() {
        let Ok(entries) = std::fs::read_dir(path) else {
            return 0;
        };
        entries.flatten().map(|entry| path_size(&entry.path())).sum()
    } else {
        metadata.len()
    }
}

/// Like `copy`, but reads/writes in chunks instead of delegating to
/// `tokio::fs::copy`'s single OS-level call, so it can report progress —
/// `done` accumulates total bytes copied across the whole tree (shared
/// across the recursion via Arc, since a directory copy touches many
/// files), and every chunk written sends the new running total on `tx`.
/// Takes owned PathBufs rather than `copy`'s `&'a Path` — simpler than
/// threading a lifetime through Arc/UnboundedSender, which are `'static`
/// anyway.
pub fn copy_with_progress(
    src: PathBuf,
    dst: PathBuf,
    done: Arc<AtomicU64>,
    tx: UnboundedSender<u64>,
) -> Pin<Box<dyn Future<Output = io::Result<()>> + Send>> {
    Box::pin(async move {
        let metadata = tokio::fs::metadata(&src).await?;

        if metadata.is_dir() {
            tokio::fs::create_dir_all(&dst).await?;
            let mut read_dir = tokio::fs::read_dir(&src).await?;
            while let Some(dir_entry) = read_dir.next_entry().await? {
                let child_src = dir_entry.path();
                let child_dst = dst.join(dir_entry.file_name());
                copy_with_progress(child_src, child_dst, done.clone(), tx.clone()).await?;
            }
            Ok(())
        } else {
            use tokio::io::{AsyncReadExt, AsyncWriteExt};

            let mut reader = tokio::fs::File::open(&src).await?;
            let mut writer = tokio::fs::File::create(&dst).await?;
            let mut buf = vec![0u8; 1024 * 1024];
            loop {
                let n = reader.read(&mut buf).await?;
                if n == 0 {
                    break;
                }
                writer.write_all(&buf[..n]).await?;
                let total = done.fetch_add(n as u64, Ordering::Relaxed) + n as u64;
                let _ = tx.send(total);
            }
            // Surface any buffered write error here instead of losing it
            // in the file's silent drop.
            writer.flush().await?;
            // tokio::fs::copy (the non-progress path) preserves mode bits;
            // a manual read/write loop must do it itself or every copied
            // executable silently loses its +x bit.
            tokio::fs::set_permissions(&dst, metadata.permissions()).await?;
            Ok(())
        }
    })
}

/// Like `move_entry`, but reports progress the same way `copy_with_progress`
/// does. The fast, same-filesystem rename() path completes with no
/// intermediate progress — there's nothing to report partway through an
/// atomic rename — so callers should treat the whole operation as "done" as
/// soon as this returns, not wait for a `tx` message that will never come
/// in that case.
pub async fn move_entry_with_progress(
    src: &Path,
    dst: &Path,
    done: Arc<AtomicU64>,
    tx: UnboundedSender<u64>,
) -> io::Result<()> {
    match tokio::fs::rename(src, dst).await {
        Ok(()) => Ok(()),
        Err(e) if e.raw_os_error() == Some(libc::EXDEV) => {
            copy_with_progress(src.to_path_buf(), dst.to_path_buf(), done, tx).await?;
            remove_all(src).await
        }
        Err(e) => Err(e),
    }
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
