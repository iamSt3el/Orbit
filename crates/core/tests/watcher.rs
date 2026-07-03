use fm_core::watcher::{DirWatcher, WatchEvent};
use std::fs;
use tempfile::tempdir;
use tokio::sync::mpsc;
use tokio::time::{timeout, Duration};

#[tokio::test]
async fn emits_created_event_for_new_file() {
    let dir = tempdir().unwrap();
    let (tx, mut rx) = mpsc::unbounded_channel();
    let _watcher = DirWatcher::new(dir.path(), tx).unwrap();

    let file_path = dir.path().join("new.txt");
    fs::write(&file_path, b"hi").unwrap();

    let event = timeout(Duration::from_secs(5), rx.recv())
        .await
        .expect("timed out waiting for a watch event")
        .expect("channel closed unexpectedly");

    assert_eq!(event, WatchEvent::Created(file_path));
}

#[tokio::test]
async fn emits_removed_event_for_deleted_file() {
    let dir = tempdir().unwrap();
    let file_path = dir.path().join("doomed.txt");
    fs::write(&file_path, b"bye").unwrap();

    let (tx, mut rx) = mpsc::unbounded_channel();
    let _watcher = DirWatcher::new(dir.path(), tx).unwrap();

    fs::remove_file(&file_path).unwrap();

    let mut saw_removed = false;
    for _ in 0..10 {
        let event = timeout(Duration::from_secs(5), rx.recv())
            .await
            .expect("timed out waiting for a watch event")
            .expect("channel closed unexpectedly");
        if event == WatchEvent::Removed(file_path.clone()) {
            saw_removed = true;
            break;
        }
    }
    assert!(saw_removed, "expected a Removed event for the deleted file");
}
