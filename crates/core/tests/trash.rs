use fm_core::trash;
use std::fs;
use tempfile::tempdir;

#[tokio::test]
async fn moves_file_into_trash_files_dir_and_writes_info_file() {
    let data_home = tempdir().unwrap();
    let source_dir = tempdir().unwrap();
    let file_path = source_dir.path().join("doomed.txt");
    fs::write(&file_path, b"bye").unwrap();

    let trashed_path = trash::move_to_trash_in(&file_path, data_home.path())
        .await
        .unwrap();

    assert!(!file_path.exists());
    assert!(trashed_path.exists());
    assert_eq!(fs::read_to_string(&trashed_path).unwrap(), "bye");

    let info_path = data_home
        .path()
        .join("Trash")
        .join("info")
        .join("doomed.txt.trashinfo");
    let info_contents = fs::read_to_string(&info_path).unwrap();
    assert!(info_contents.contains("[Trash Info]"));
    assert!(info_contents.contains(&format!("Path={}", file_path.display())));
    assert!(info_contents.contains("DeletionDate="));
}

#[tokio::test]
async fn dedupes_name_collisions_in_trash() {
    let data_home = tempdir().unwrap();
    let source_dir = tempdir().unwrap();

    let first = source_dir.path().join("dup.txt");
    fs::write(&first, b"one").unwrap();
    trash::move_to_trash_in(&first, data_home.path())
        .await
        .unwrap();

    let second = source_dir.path().join("dup.txt");
    fs::write(&second, b"two").unwrap();
    let trashed_second = trash::move_to_trash_in(&second, data_home.path())
        .await
        .unwrap();

    assert_eq!(
        trashed_second.file_name().unwrap().to_str().unwrap(),
        "dup_1.txt"
    );
    assert_eq!(fs::read_to_string(&trashed_second).unwrap(), "two");
}

#[tokio::test]
async fn empty_trash_removes_files_and_info_entries() {
    let data_home = tempdir().unwrap();
    let source_dir = tempdir().unwrap();
    let file_path = source_dir.path().join("doomed.txt");
    fs::write(&file_path, b"bye").unwrap();

    trash::move_to_trash_in(&file_path, data_home.path())
        .await
        .unwrap();

    trash::empty_trash_in(data_home.path()).await.unwrap();

    let files_dir = data_home.path().join("Trash").join("files");
    let info_dir = data_home.path().join("Trash").join("info");
    assert_eq!(fs::read_dir(&files_dir).unwrap().count(), 0);
    assert_eq!(fs::read_dir(&info_dir).unwrap().count(), 0);
}

#[tokio::test]
async fn empty_trash_is_a_noop_when_trash_does_not_exist() {
    let data_home = tempdir().unwrap();
    trash::empty_trash_in(data_home.path()).await.unwrap();
}
