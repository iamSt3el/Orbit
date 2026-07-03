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

                    let file_entry = FileEntry {
                        name: dir_entry.file_name().to_string_lossy().into_owned(),
                        path: entry_path,
                        is_dir,
                        size: metadata.len(),
                        modified: metadata.modified().unwrap_or(SystemTime::UNIX_EPOCH),
                        mime_type: mime_info.mime_type,
                        icon_key: mime_info.icon_key,
                        permissions: format_permissions(metadata.permissions().mode()),
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
