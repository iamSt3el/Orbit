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

#[tokio::test]
async fn restores_a_trashed_file_to_its_original_location() {
    let data_home = tempdir().unwrap();
    let original_dir = tempdir().unwrap();
    let original_path = original_dir.path().join("note.txt");
    fs::write(&original_path, b"hello").unwrap();

    let trashed_path = trash::move_to_trash_in(&original_path, data_home.path())
        .await
        .unwrap();
    assert!(!original_path.exists());

    let restored_path = trash::restore_in(&trashed_path, data_home.path())
        .await
        .unwrap();

    assert_eq!(restored_path, original_path);
    assert!(restored_path.exists());
    assert_eq!(fs::read_to_string(&restored_path).unwrap(), "hello");
    assert!(!trashed_path.exists());
    let info_path = data_home
        .path()
        .join("Trash")
        .join("info")
        .join(format!(
            "{}.trashinfo",
            trashed_path.file_name().unwrap().to_str().unwrap()
        ));
    assert!(!info_path.exists());
}

#[tokio::test]
async fn recreates_a_missing_parent_directory_on_restore() {
    let data_home = tempdir().unwrap();
    let original_dir = tempdir().unwrap();
    let nested_dir = original_dir.path().join("subfolder");
    fs::create_dir_all(&nested_dir).unwrap();
    let original_path = nested_dir.join("note.txt");
    fs::write(&original_path, b"hello").unwrap();

    let trashed_path = trash::move_to_trash_in(&original_path, data_home.path())
        .await
        .unwrap();
    fs::remove_dir_all(&nested_dir).unwrap();

    let restored_path = trash::restore_in(&trashed_path, data_home.path())
        .await
        .unwrap();

    assert_eq!(restored_path, original_path);
    assert!(restored_path.exists());
}

#[tokio::test]
async fn auto_renames_on_conflict_at_the_original_location() {
    let data_home = tempdir().unwrap();
    let original_dir = tempdir().unwrap();
    let original_path = original_dir.path().join("note.txt");
    fs::write(&original_path, b"first").unwrap();

    let trashed_path = trash::move_to_trash_in(&original_path, data_home.path())
        .await
        .unwrap();
    fs::write(&original_path, b"second").unwrap();

    let restored_path = trash::restore_in(&trashed_path, data_home.path())
        .await
        .unwrap();

    assert_eq!(restored_path, original_dir.path().join("note (restored).txt"));
    assert_eq!(fs::read_to_string(&original_path).unwrap(), "second");
    assert_eq!(fs::read_to_string(&restored_path).unwrap(), "first");
}

#[tokio::test]
async fn errors_when_the_trashinfo_file_is_missing() {
    let data_home = tempdir().unwrap();
    let files_dir = data_home.path().join("Trash").join("files");
    fs::create_dir_all(&files_dir).unwrap();
    let phantom_path = files_dir.join("ghost.txt");
    fs::write(&phantom_path, b"boo").unwrap();

    let result = trash::restore_in(&phantom_path, data_home.path()).await;

    assert!(result.is_err());
}

#[tokio::test]
async fn permanently_deletes_a_trashed_file_and_its_info() {
    let data_home = tempdir().unwrap();
    let original_dir = tempdir().unwrap();
    let original_path = original_dir.path().join("note.txt");
    fs::write(&original_path, b"hello").unwrap();

    let trashed_path = trash::move_to_trash_in(&original_path, data_home.path())
        .await
        .unwrap();
    let info_path = data_home
        .path()
        .join("Trash")
        .join("info")
        .join(format!(
            "{}.trashinfo",
            trashed_path.file_name().unwrap().to_str().unwrap()
        ));
    assert!(info_path.exists());

    trash::delete_permanently_in(&trashed_path, data_home.path())
        .await
        .unwrap();

    assert!(!trashed_path.exists());
    assert!(!info_path.exists());
}

#[tokio::test]
async fn permanently_deletes_a_trashed_directory_recursively() {
    let data_home = tempdir().unwrap();
    let original_dir = tempdir().unwrap();
    let folder_path = original_dir.path().join("stuff");
    fs::create_dir_all(&folder_path).unwrap();
    fs::write(folder_path.join("inner.txt"), b"hi").unwrap();

    let trashed_path = trash::move_to_trash_in(&folder_path, data_home.path())
        .await
        .unwrap();
    assert!(trashed_path.is_dir());

    trash::delete_permanently_in(&trashed_path, data_home.path())
        .await
        .unwrap();

    assert!(!trashed_path.exists());
}

#[tokio::test]
async fn permanent_delete_succeeds_even_if_trashinfo_already_missing() {
    let data_home = tempdir().unwrap();
    let files_dir = data_home.path().join("Trash").join("files");
    fs::create_dir_all(&files_dir).unwrap();
    let phantom_path = files_dir.join("ghost.txt");
    fs::write(&phantom_path, b"boo").unwrap();

    let result = trash::delete_permanently_in(&phantom_path, data_home.path()).await;

    assert!(result.is_ok());
    assert!(!phantom_path.exists());
}
