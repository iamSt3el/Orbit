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
async fn counts_directory_children() {
    let dir = tempdir().unwrap();
    fs::create_dir(dir.path().join("sub")).unwrap();
    fs::write(dir.path().join("sub").join("x.txt"), b"x").unwrap();
    fs::write(dir.path().join("sub").join("y.txt"), b"y").unwrap();
    fs::write(dir.path().join("plain.txt"), b"p").unwrap();

    let mut rx = listing::list_directory(dir.path().to_path_buf());
    let mut counts = std::collections::HashMap::new();
    while let Some(result) = rx.recv().await {
        let entry = result.unwrap();
        counts.insert(entry.name, entry.child_count);
    }

    assert_eq!(counts["sub"], Some(2));
    assert_eq!(counts["plain.txt"], None);
}

#[tokio::test]
async fn reports_error_for_nonexistent_directory() {
    let mut rx = listing::list_directory("/nonexistent/path/that/does/not/exist".into());

    let result = rx.recv().await.expect("channel should yield one error");
    assert!(result.is_err());
}

#[tokio::test]
async fn search_recursive_finds_nested_matches_with_relative_names() {
    let dir = tempdir().unwrap();
    fs::create_dir_all(dir.path().join("docs/old")).unwrap();
    fs::write(dir.path().join("notes.txt"), b"x").unwrap();
    fs::write(dir.path().join("docs/old/notes-2024.txt"), b"x").unwrap();
    fs::write(dir.path().join("docs/other.md"), b"x").unwrap();
    fs::create_dir(dir.path().join(".hidden")).unwrap();
    fs::write(dir.path().join(".hidden/notes-secret.txt"), b"x").unwrap();

    let results =
        listing::search_recursive(dir.path().to_path_buf(), "notes".into(), false, 100).await;

    let names: HashSet<String> = results.iter().map(|e| e.name.clone()).collect();
    assert_eq!(
        names,
        HashSet::from(["notes.txt".to_string(), "docs/old/notes-2024.txt".to_string()])
    );
}

#[tokio::test]
async fn search_recursive_honors_the_result_limit() {
    let dir = tempdir().unwrap();
    for i in 0..10 {
        fs::write(dir.path().join(format!("match-{i}.txt")), b"x").unwrap();
    }

    let results =
        listing::search_recursive(dir.path().to_path_buf(), "match".into(), false, 4).await;

    assert_eq!(results.len(), 4);
}
