use fm_core::duplicates;
use std::fs;
use tempfile::tempdir;

#[test]
fn groups_identical_files_across_folders() {
    let dir = tempdir().unwrap();
    fs::create_dir(dir.path().join("sub")).unwrap();
    fs::write(dir.path().join("a.txt"), b"same-content").unwrap();
    fs::write(dir.path().join("sub").join("b.txt"), b"same-content").unwrap();
    fs::write(dir.path().join("unique.txt"), b"different").unwrap();

    let groups = duplicates::find_duplicates(dir.path(), false, 10000, &|| false);

    assert_eq!(groups.len(), 1);
    assert_eq!(groups[0].size, 12);
    let mut paths = groups[0].paths.clone();
    paths.sort();
    assert_eq!(paths, vec!["a.txt".to_string(), "sub/b.txt".to_string()]);
}

#[test]
fn same_size_different_content_is_not_grouped() {
    let dir = tempdir().unwrap();
    fs::write(dir.path().join("a.txt"), b"aaaa").unwrap();
    fs::write(dir.path().join("b.txt"), b"bbbb").unwrap();

    let groups = duplicates::find_duplicates(dir.path(), false, 10000, &|| false);

    assert!(groups.is_empty());
}

#[test]
fn stop_callback_aborts_the_walk() {
    let dir = tempdir().unwrap();
    fs::write(dir.path().join("a.txt"), b"same").unwrap();
    fs::write(dir.path().join("b.txt"), b"same").unwrap();

    let groups = duplicates::find_duplicates(dir.path(), false, 10000, &|| true);

    assert!(groups.is_empty());
}
