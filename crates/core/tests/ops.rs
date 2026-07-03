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

#[tokio::test]
async fn copy_duplicates_a_single_file() {
    let dir = tempdir().unwrap();
    let src = dir.path().join("source.txt");
    fs::write(&src, b"payload").unwrap();
    let dst = dir.path().join("dest.txt");

    ops::copy(&src, &dst).await.unwrap();

    assert!(src.exists());
    assert_eq!(fs::read_to_string(&dst).unwrap(), "payload");
}

#[tokio::test]
async fn copy_duplicates_a_directory_tree() {
    let dir = tempdir().unwrap();
    let src = dir.path().join("srcdir");
    fs::create_dir(&src).unwrap();
    fs::write(src.join("top.txt"), b"top").unwrap();
    fs::create_dir(src.join("nested")).unwrap();
    fs::write(src.join("nested").join("inner.txt"), b"inner").unwrap();
    let dst = dir.path().join("dstdir");

    ops::copy(&src, &dst).await.unwrap();

    assert_eq!(fs::read_to_string(dst.join("top.txt")).unwrap(), "top");
    assert_eq!(
        fs::read_to_string(dst.join("nested").join("inner.txt")).unwrap(),
        "inner"
    );
    assert!(src.exists(), "copy must not remove the source");
}

#[tokio::test]
async fn move_entry_relocates_a_file_within_same_filesystem() {
    let dir = tempdir().unwrap();
    let src = dir.path().join("a.txt");
    fs::write(&src, b"hello").unwrap();
    let dst = dir.path().join("b.txt");

    ops::move_entry(&src, &dst).await.unwrap();

    assert!(!src.exists());
    assert_eq!(fs::read_to_string(&dst).unwrap(), "hello");
}

#[tokio::test]
async fn move_entry_relocates_a_directory_within_same_filesystem() {
    let dir = tempdir().unwrap();
    let src = dir.path().join("srcdir");
    fs::create_dir(&src).unwrap();
    fs::write(src.join("inner.txt"), b"x").unwrap();
    let dst = dir.path().join("dstdir");

    ops::move_entry(&src, &dst).await.unwrap();

    assert!(!src.exists());
    assert_eq!(fs::read_to_string(dst.join("inner.txt")).unwrap(), "x");
}
