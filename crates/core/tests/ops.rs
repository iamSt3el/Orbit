use fm_core::ops;
use std::fs;
use tempfile::tempdir;

#[tokio::test]
async fn create_folder_makes_a_new_directory() {
    let dir = tempdir().unwrap();

    let created = ops::create_folder(dir.path(), "new-folder").await.unwrap();

    assert!(created.is_dir());
    assert_eq!(created, dir.path().join("new-folder"));
}

#[tokio::test]
async fn rename_moves_file_to_new_name_in_same_directory() {
    let dir = tempdir().unwrap();
    let original = dir.path().join("old.txt");
    fs::write(&original, b"content").unwrap();

    let renamed = ops::rename(&original, "new.txt").await.unwrap();

    assert!(!original.exists());
    assert_eq!(renamed, dir.path().join("new.txt"));
    assert_eq!(fs::read_to_string(&renamed).unwrap(), "content");
}

#[tokio::test]
async fn rename_fails_for_nonexistent_path() {
    let dir = tempdir().unwrap();
    let missing = dir.path().join("missing.txt");

    let result = ops::rename(&missing, "new.txt").await;

    assert!(result.is_err());
}
