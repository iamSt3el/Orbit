use crate::entry::{format_permissions, FileEntry};
use crate::mime;
use std::os::unix::fs::PermissionsExt;
use std::path::PathBuf;
use std::time::SystemTime;
use tokio::sync::mpsc;

pub fn list_directory(path: PathBuf) -> mpsc::Receiver<std::io::Result<FileEntry>> {
    let (tx, rx) = mpsc::channel(64);

    tokio::spawn(async move {
        let mut read_dir = match tokio::fs::read_dir(&path).await {
            Ok(read_dir) => read_dir,
            Err(e) => {
                let _ = tx.send(Err(e)).await;
                return;
            }
        };

        loop {
            match read_dir.next_entry().await {
                Ok(Some(dir_entry)) => {
                    let entry_path = dir_entry.path();
                    let metadata = match dir_entry.metadata().await {
                        Ok(metadata) => metadata,
                        Err(e) => {
                            if tx.send(Err(e)).await.is_err() {
                                return;
                            }
                            continue;
                        }
                    };

                    let is_dir = metadata.is_dir();
                    let mime_info = if is_dir {
                        mime::detect_dir()
                    } else {
                        mime::detect(&entry_path)
                    };
                    let child_count = if is_dir {
                        std::fs::read_dir(&entry_path)
                            .map(|rd| rd.count() as u64)
                            .ok()
                    } else {
                        None
                    };

                    let file_entry = FileEntry {
                        name: dir_entry.file_name().to_string_lossy().into_owned(),
                        path: entry_path,
                        is_dir,
                        size: metadata.len(),
                        modified: metadata.modified().unwrap_or(SystemTime::UNIX_EPOCH),
                        mime_type: mime_info.mime_type,
                        icon_key: mime_info.icon_key,
                        permissions: format_permissions(metadata.permissions().mode()),
                        thumbnail_path: None,
                        child_count,
                    };

                    if tx.send(Ok(file_entry)).await.is_err() {
                        return;
                    }
                }
                Ok(None) => return,
                Err(e) => {
                    let _ = tx.send(Err(e)).await;
                    return;
                }
            }
        }
    });

    rx
}

/// Recursive filename search under `root` (roadmap round-2 item 25):
/// breadth-first walk collecting entries whose file name contains
/// `query` case-insensitively, with names REWRITTEN to the path relative
/// to `root` ("docs/notes.txt") — the model resolves entry names against
/// its current directory, so relative names keep every existing
/// operation (open, trash, drag, properties) working on nested results.
/// Hidden components are skipped unless `include_hidden`; directory
/// symlinks are never followed (cycle safety); stops at `limit` matches.
pub async fn search_recursive(
    root: PathBuf,
    query: String,
    include_hidden: bool,
    limit: usize,
) -> Vec<FileEntry> {
    let needle = query.to_lowercase();
    let mut results = Vec::new();
    if needle.is_empty() {
        return results;
    }
    let mut queue = std::collections::VecDeque::new();
    queue.push_back(root.clone());
    while let Some(dir) = queue.pop_front() {
        let Ok(mut read_dir) = tokio::fs::read_dir(&dir).await else {
            continue;
        };
        while let Ok(Some(dir_entry)) = read_dir.next_entry().await {
            let file_name = dir_entry.file_name().to_string_lossy().into_owned();
            if !include_hidden && file_name.starts_with('.') {
                continue;
            }
            let entry_path = dir_entry.path();
            let Ok(metadata) = tokio::fs::symlink_metadata(&entry_path).await else {
                continue;
            };
            let is_dir = metadata.is_dir();
            if is_dir {
                queue.push_back(entry_path.clone());
            }
            if file_name.to_lowercase().contains(&needle) {
                let mime_info = if is_dir {
                    mime::detect_dir()
                } else {
                    mime::detect(&entry_path)
                };
                let relative = entry_path
                    .strip_prefix(&root)
                    .map(|p| p.to_string_lossy().into_owned())
                    .unwrap_or(file_name);
                results.push(FileEntry {
                    name: relative,
                    path: entry_path,
                    is_dir,
                    size: metadata.len(),
                    modified: metadata.modified().unwrap_or(SystemTime::UNIX_EPOCH),
                    mime_type: mime_info.mime_type,
                    icon_key: mime_info.icon_key,
                    permissions: format_permissions(metadata.permissions().mode()),
                    thumbnail_path: None,
                    child_count: None,
                });
                if results.len() >= limit {
                    return results;
                }
            }
        }
    }
    results
}
