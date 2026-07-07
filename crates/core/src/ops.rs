use std::future::Future;
use std::io;
use std::path::{Path, PathBuf};
use std::pin::Pin;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
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

/// Allocated-blocks recursive total (what `du` reports) rather than
/// apparent byte length — sparse files (Docker/VM disk images) report
/// terabytes of `len()` while occupying a fraction of that on disk.
/// Symlinks are counted by their own metadata and never followed.
pub fn path_disk_usage(path: &Path) -> u64 {
    use std::os::unix::fs::MetadataExt;
    let Ok(metadata) = std::fs::symlink_metadata(path) else {
        return 0;
    };
    if metadata.is_dir() {
        let Ok(entries) = std::fs::read_dir(path) else {
            return 0;
        };
        entries
            .flatten()
            .map(|entry| path_disk_usage(&entry.path()))
            .sum()
    } else {
        metadata.blocks() * 512
    }
}

/// Recursively totals a directory's bytes and entry count, invoking
/// `progress(bytes_so_far, items_so_far)` once per entry encountered.
/// Items count every entry recursively — files AND directories — matching
/// Nautilus's Properties "contents" semantics. Returning `false` from the
/// callback aborts the walk early; the totals accumulated so far are
/// returned either way. Unreadable directories are skipped silently.
pub fn dir_size_with_progress(
    path: &Path,
    progress: &mut impl FnMut(u64, u64) -> bool,
) -> (u64, u64) {
    let mut bytes = 0u64;
    let mut items = 0u64;
    dir_size_walk(path, &mut bytes, &mut items, progress);
    (bytes, items)
}

/// Returns false if the callback asked to abort (propagates up the
/// recursion so the whole walk unwinds immediately).
fn dir_size_walk(
    path: &Path,
    bytes: &mut u64,
    items: &mut u64,
    progress: &mut impl FnMut(u64, u64) -> bool,
) -> bool {
    let Ok(entries) = std::fs::read_dir(path) else {
        return true;
    };
    for entry in entries.flatten() {
        // metadata() on a DirEntry uses lstat on Unix (doesn't follow
        // symlinks), so a symlink counts its own small size, never the
        // target's — avoiding both double-counting and symlink-cycle
        // infinite recursion.
        match entry.metadata() {
            Ok(metadata) if metadata.is_dir() => {
                *items += 1;
                if !progress(*bytes, *items) {
                    return false;
                }
                if !dir_size_walk(&entry.path(), bytes, items, progress) {
                    return false;
                }
            }
            Ok(metadata) => {
                *items += 1;
                *bytes += metadata.len();
                if !progress(*bytes, *items) {
                    return false;
                }
            }
            Err(_) => {}
        }
    }
    true
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
    cancel: Arc<AtomicBool>,
) -> Pin<Box<dyn Future<Output = io::Result<()>> + Send>> {
    Box::pin(async move {
        if cancel.load(Ordering::Relaxed) {
            return Err(io::Error::new(io::ErrorKind::Interrupted, "cancelled"));
        }
        let metadata = tokio::fs::metadata(&src).await?;

        if metadata.is_dir() {
            tokio::fs::create_dir_all(&dst).await?;
            let mut read_dir = tokio::fs::read_dir(&src).await?;
            while let Some(dir_entry) = read_dir.next_entry().await? {
                let child_src = dir_entry.path();
                let child_dst = dst.join(dir_entry.file_name());
                copy_with_progress(child_src, child_dst, done.clone(), tx.clone(), cancel.clone())
                    .await?;
            }
            Ok(())
        } else {
            let len = metadata.len();
            let permissions = metadata.permissions();
            tokio::task::spawn_blocking(move || {
                copy_file_blocking(&src, &dst, len, permissions, &done, &tx, &cancel)
            })
            .await
            .map_err(|e| io::Error::other(e.to_string()))?
        }
    })
}

fn copy_file_blocking(
    src: &Path,
    dst: &Path,
    len: u64,
    permissions: std::fs::Permissions,
    done: &Arc<AtomicU64>,
    tx: &UnboundedSender<u64>,
    cancel: &Arc<AtomicBool>,
) -> io::Result<()> {
    use std::io::{Read, Write};
    use std::os::fd::AsRawFd;

    let mut reader = std::fs::File::open(src)?;
    let mut writer = std::fs::File::create(dst)?;
    let mut remaining = len;
    let mut use_fallback = false;
    while remaining > 0 {
        if cancel.load(Ordering::Relaxed) {
            let _ = std::fs::remove_file(dst);
            return Err(io::Error::new(io::ErrorKind::Interrupted, "cancelled"));
        }
        let chunk = remaining.min(1024 * 1024) as usize;
        let copied = unsafe {
            libc::copy_file_range(
                reader.as_raw_fd(),
                std::ptr::null_mut(),
                writer.as_raw_fd(),
                std::ptr::null_mut(),
                chunk,
                0,
            )
        };
        if copied < 0 {
            let e = io::Error::last_os_error();
            match e.raw_os_error() {
                Some(libc::EXDEV) | Some(libc::EINVAL) | Some(libc::ENOSYS)
                | Some(libc::EOPNOTSUPP) => {
                    use_fallback = true;
                    break;
                }
                _ => {
                    let _ = std::fs::remove_file(dst);
                    return Err(e);
                }
            }
        } else if copied == 0 {
            break;
        } else {
            remaining -= copied as u64;
            let total = done.fetch_add(copied as u64, Ordering::Relaxed) + copied as u64;
            let _ = tx.send(total);
        }
    }
    if use_fallback {
        let mut buf = vec![0u8; 1024 * 1024];
        loop {
            if cancel.load(Ordering::Relaxed) {
                let _ = std::fs::remove_file(dst);
                return Err(io::Error::new(io::ErrorKind::Interrupted, "cancelled"));
            }
            let n = reader.read(&mut buf)?;
            if n == 0 {
                break;
            }
            writer.write_all(&buf[..n])?;
            let total = done.fetch_add(n as u64, Ordering::Relaxed) + n as u64;
            let _ = tx.send(total);
        }
        writer.flush()?;
    }
    std::fs::set_permissions(dst, permissions)?;
    Ok(())
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
    cancel: Arc<AtomicBool>,
) -> io::Result<()> {
    match tokio::fs::rename(src, dst).await {
        Ok(()) => Ok(()),
        Err(e) if e.raw_os_error() == Some(libc::EXDEV) => {
            copy_with_progress(src.to_path_buf(), dst.to_path_buf(), done, tx, cancel).await?;
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
