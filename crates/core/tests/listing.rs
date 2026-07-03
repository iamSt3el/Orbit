use fm_core::listing;
use std::collections::HashSet;
use std::fs;
use tempfile::tempdir;

#[tokio::test]
async fn streams_all_entries_in_directory() {
    let dir = tempdir().unwrap();
    fs::write(dir.path().join("a.txt"), b"a").unwrap();
    fs::write(dir.path().join("b.txt"), b"b").unwrap();
    fs::create_dir(dir.path().join("sub")).unwrap();

    let mut rx = listing::list_directory(dir.path().to_path_buf());
    let mut names = HashSet::new();
    while let Some(result) = rx.recv().await {
        names.insert(result.unwrap().name);
    }

    assert_eq!(
        names,
        HashSet::from(["a.txt".to_string(), "b.txt".to_string(), "sub".to_string()])
    );
}

#[tokio::test]
async fn marks_directories_correctly() {
    let dir = tempdir().unwrap();
    fs::create_dir(dir.path().join("sub")).unwrap();

    let mut rx = listing::list_directory(dir.path().to_path_buf());
    let entry = rx.recv().await.unwrap().unwrap();

    assert_eq!(entry.name, "sub");
    assert!(entry.is_dir);
    assert_eq!(entry.icon_key, "folder");
    assert_eq!(entry.mime_type, "inode/directory");
}

#[tokio::test]
async fn reports_error_for_nonexistent_directory() {
    let mut rx = listing::list_directory("/nonexistent/path/that/does/not/exist".into());

    let result = rx.recv().await.expect("channel should yield one error");
    assert!(result.is_err());
}
