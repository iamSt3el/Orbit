use fm_core::ops;
use std::fs;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::Arc;
use tempfile::tempdir;

#[test]
fn format_bytes_uses_the_smallest_unit_that_keeps_the_number_readable() {
    assert_eq!(ops::format_bytes(42), "42 B");
    assert_eq!(ops::format_bytes(1536), "1.5 KB");
    assert_eq!(ops::format_bytes(15 * 1024 * 1024), "15 MB");
    assert_eq!(ops::format_bytes(1024 * 1024 * 1024), "1.0 GB");
}

#[tokio::test]
async fn create_folder_makes_a_new_directory() {
    let dir = tempdir().unwrap();

    let created = ops::create_folder(dir.path(), "new-folder").await.unwrap();

    assert!(created.is_dir());
    assert_eq!(created, dir.path().join("new-folder"));
}

#[tokio::test]
async fn create_file_makes_a_new_empty_file() {
    let dir = tempdir().unwrap();

    let created = ops::create_file(dir.path(), "notes.txt").await.unwrap();

    assert!(created.is_file());
    assert_eq!(created, dir.path().join("notes.txt"));
    assert_eq!(fs::metadata(&created).unwrap().len(), 0);
}

#[tokio::test]
async fn create_file_fails_if_the_name_already_exists() {
    let dir = tempdir().unwrap();
    fs::write(dir.path().join("notes.txt"), b"keep me").unwrap();

    let result = ops::create_file(dir.path(), "notes.txt").await;

    assert!(result.is_err());
    assert_eq!(
        fs::read_to_string(dir.path().join("notes.txt")).unwrap(),
        "keep me"
    );
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
async fn duplicate_appends_copy_suffix_before_the_extension() {
    let dir = tempdir().unwrap();
    let src = dir.path().join("report.txt");
    fs::write(&src, b"data").unwrap();

    let duplicated = ops::duplicate(&src).await.unwrap();

    assert!(src.exists(), "duplicate must not remove the source");
    assert_eq!(duplicated, dir.path().join("report (copy).txt"));
    assert_eq!(fs::read_to_string(&duplicated).unwrap(), "data");
}

#[tokio::test]
async fn duplicate_increments_when_a_copy_already_exists() {
    let dir = tempdir().unwrap();
    let src = dir.path().join("notes");
    fs::create_dir(&src).unwrap();
    fs::create_dir(dir.path().join("notes (copy)")).unwrap();

    let duplicated = ops::duplicate(&src).await.unwrap();

    assert_eq!(duplicated, dir.path().join("notes (copy 2)"));
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

#[test]
fn path_size_of_a_single_file_is_its_byte_length() {
    let dir = tempdir().unwrap();
    let file = dir.path().join("data.bin");
    fs::write(&file, vec![0u8; 12345]).unwrap();

    assert_eq!(ops::path_size(&file), 12345);
}

#[test]
fn path_size_of_a_directory_sums_every_file_in_the_tree() {
    let dir = tempdir().unwrap();
    let root = dir.path().join("tree");
    fs::create_dir(&root).unwrap();
    fs::write(root.join("a.txt"), vec![0u8; 100]).unwrap();
    fs::create_dir(root.join("nested")).unwrap();
    fs::write(root.join("nested").join("b.txt"), vec![0u8; 250]).unwrap();

    assert_eq!(ops::path_size(&root), 350);
}

#[tokio::test]
async fn copy_with_progress_copies_the_file_and_reports_the_final_total() {
    let dir = tempdir().unwrap();
    let src = dir.path().join("source.bin");
    let payload = vec![7u8; 500_000]; // bigger than the 256KB chunk size
    fs::write(&src, &payload).unwrap();
    let dst = dir.path().join("dest.bin");

    let done = Arc::new(AtomicU64::new(0));
    let (tx, mut rx) = tokio::sync::mpsc::unbounded_channel();

    ops::copy_with_progress(src.clone(), dst.clone(), done.clone(), tx, Arc::new(AtomicBool::new(false)))
        .await
        .unwrap();

    assert_eq!(fs::read(&dst).unwrap(), payload);
    assert_eq!(done.load(Ordering::Relaxed), 500_000);

    // The channel should have received at least one update, and the final
    // (largest) one should equal the total.
    let mut last = 0u64;
    while let Ok(value) = rx.try_recv() {
        last = value;
    }
    assert_eq!(last, 500_000);
}

#[tokio::test]
async fn copy_with_progress_preserves_the_source_permission_bits() {
    use std::os::unix::fs::PermissionsExt;

    let dir = tempdir().unwrap();
    let src = dir.path().join("tool.sh");
    fs::write(&src, b"#!/bin/sh\n").unwrap();
    fs::set_permissions(&src, fs::Permissions::from_mode(0o755)).unwrap();
    let dst = dir.path().join("tool-copy.sh");

    let done = Arc::new(AtomicU64::new(0));
    let (tx, _rx) = tokio::sync::mpsc::unbounded_channel();

    ops::copy_with_progress(src.clone(), dst.clone(), done, tx, Arc::new(AtomicBool::new(false)))
        .await
        .unwrap();

    let mode = fs::metadata(&dst).unwrap().permissions().mode() & 0o777;
    assert_eq!(mode, 0o755, "copied executable must keep its +x bit");
}

#[tokio::test]
async fn copy_with_progress_copies_a_directory_tree() {
    let dir = tempdir().unwrap();
    let src = dir.path().join("srcdir");
    fs::create_dir(&src).unwrap();
    fs::write(src.join("a.txt"), b"aaa").unwrap();
    fs::create_dir(src.join("nested")).unwrap();
    fs::write(src.join("nested").join("b.txt"), b"bb").unwrap();
    let dst = dir.path().join("dstdir");

    let done = Arc::new(AtomicU64::new(0));
    let (tx, _rx) = tokio::sync::mpsc::unbounded_channel();

    ops::copy_with_progress(src.clone(), dst.clone(), done.clone(), tx, Arc::new(AtomicBool::new(false)))
        .await
        .unwrap();

    assert_eq!(fs::read_to_string(dst.join("a.txt")).unwrap(), "aaa");
    assert_eq!(
        fs::read_to_string(dst.join("nested").join("b.txt")).unwrap(),
        "bb"
    );
    assert_eq!(done.load(Ordering::Relaxed), 5);
}

#[tokio::test]
async fn move_entry_with_progress_relocates_within_same_filesystem() {
    let dir = tempdir().unwrap();
    let src = dir.path().join("a.txt");
    fs::write(&src, b"hello").unwrap();
    let dst = dir.path().join("b.txt");

    let done = Arc::new(AtomicU64::new(0));
    let (tx, _rx) = tokio::sync::mpsc::unbounded_channel();

    ops::move_entry_with_progress(&src, &dst, done, tx, Arc::new(AtomicBool::new(false)))
        .await
        .unwrap();

    assert!(!src.exists());
    assert_eq!(fs::read_to_string(&dst).unwrap(), "hello");
}

#[test]
fn dir_size_with_progress_totals_bytes_and_items_recursively() {
    let dir = tempdir().unwrap();
    fs::write(dir.path().join("a.txt"), vec![0u8; 100]).unwrap();
    fs::create_dir(dir.path().join("sub")).unwrap();
    fs::write(dir.path().join("sub/b.txt"), vec![0u8; 50]).unwrap();
    fs::write(dir.path().join("sub/c.txt"), vec![0u8; 25]).unwrap();

    let (bytes, items) = ops::dir_size_with_progress(dir.path(), &mut |_, _| true);

    assert_eq!(bytes, 175);
    // a.txt + sub + sub/b.txt + sub/c.txt — directories count as items.
    assert_eq!(items, 4);
}

#[test]
fn dir_size_with_progress_reports_running_totals_to_the_callback() {
    let dir = tempdir().unwrap();
    fs::write(dir.path().join("a.txt"), vec![0u8; 10]).unwrap();
    fs::write(dir.path().join("b.txt"), vec![0u8; 20]).unwrap();

    let mut calls: Vec<(u64, u64)> = Vec::new();
    let (bytes, items) = ops::dir_size_with_progress(dir.path(), &mut |b, i| {
        calls.push((b, i));
        true
    });

    assert_eq!(bytes, 30);
    assert_eq!(items, 2);
    assert_eq!(calls.len(), 2);
    // The last callback carries the final totals.
    assert_eq!(*calls.last().unwrap(), (30, 2));
}

#[test]
fn dir_size_with_progress_aborts_when_the_callback_returns_false() {
    let dir = tempdir().unwrap();
    for n in 0..10 {
        fs::write(dir.path().join(format!("f{n}.txt")), vec![0u8; 10]).unwrap();
    }

    let mut calls = 0u64;
    let (_, items) = ops::dir_size_with_progress(dir.path(), &mut |_, _| {
        calls += 1;
        calls < 3
    });

    assert_eq!(calls, 3);
    assert!(items < 10, "walk kept going after the callback said stop");
}

#[test]
fn dir_size_with_progress_returns_zero_for_an_unreadable_path() {
    let (bytes, items) =
        ops::dir_size_with_progress(std::path::Path::new("/nonexistent/nope"), &mut |_, _| true);

    assert_eq!(bytes, 0);
    assert_eq!(items, 0);
}

#[tokio::test]
async fn copy_with_progress_cancel_aborts_before_writing() {
    let dir = tempdir().unwrap();
    let src = dir.path().join("big.bin");
    fs::write(&src, vec![0u8; 1024 * 1024]).unwrap();
    let dst = dir.path().join("out.bin");
    let done = Arc::new(AtomicU64::new(0));
    let (tx, _rx) = tokio::sync::mpsc::unbounded_channel();
    let cancel = Arc::new(AtomicBool::new(true));

    let result = ops::copy_with_progress(src.clone(), dst.clone(), done, tx, cancel).await;

    assert_eq!(result.unwrap_err().kind(), std::io::ErrorKind::Interrupted);
    assert!(!dst.exists());
}

#[tokio::test]
async fn copy_with_progress_cancel_mid_copy_removes_partial_file() {
    let dir = tempdir().unwrap();
    let src = dir.path().join("big.bin");
    fs::write(&src, vec![7u8; 8 * 1024 * 1024]).unwrap();
    let dst = dir.path().join("out.bin");
    let done = Arc::new(AtomicU64::new(0));
    let (tx, mut rx) = tokio::sync::mpsc::unbounded_channel();
    let cancel = Arc::new(AtomicBool::new(false));
    let cancel_setter = cancel.clone();
    tokio::spawn(async move {
        let _ = rx.recv().await;
        cancel_setter.store(true, Ordering::Relaxed);
    });

    let result = ops::copy_with_progress(src.clone(), dst.clone(), done, tx, cancel).await;

    assert_eq!(result.unwrap_err().kind(), std::io::ErrorKind::Interrupted);
    assert!(!dst.exists());
}

#[tokio::test]
async fn copy_with_progress_handles_empty_files() {
    let dir = tempdir().unwrap();
    let src = dir.path().join("empty.txt");
    fs::write(&src, b"").unwrap();
    let dst = dir.path().join("out.txt");
    let done = Arc::new(AtomicU64::new(0));
    let (tx, _rx) = tokio::sync::mpsc::unbounded_channel();

    ops::copy_with_progress(src.clone(), dst.clone(), done, tx, Arc::new(AtomicBool::new(false)))
        .await
        .unwrap();

    assert!(dst.exists());
    assert_eq!(fs::metadata(&dst).unwrap().len(), 0);
}


#[test]
fn disk_usage_counts_allocated_blocks_not_sparse_length() {
    let dir = tempfile::tempdir().unwrap();
    let sparse = dir.path().join("sparse.img");
    let file = std::fs::File::create(&sparse).unwrap();
    file.set_len(100 * 1024 * 1024).unwrap();
    std::fs::write(dir.path().join("real.txt"), vec![7u8; 8192]).unwrap();

    let usage = fm_core::ops::path_disk_usage(dir.path());

    assert!(usage < 1024 * 1024, "sparse length must not count: {usage}");
    assert!(usage >= 8192, "real data must count: {usage}");
}
