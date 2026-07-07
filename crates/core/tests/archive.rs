use fm_core::archive;
use std::fs;
use tempfile::tempdir;

#[test]
fn recognizes_archive_names() {
    assert!(archive::is_archive_name("photos.zip"));
    assert!(archive::is_archive_name("backup.tar.gz"));
    assert!(archive::is_archive_name("BACKUP.TAR.ZST"));
    assert!(archive::is_archive_name("code.tgz"));
    assert!(!archive::is_archive_name("notes.txt"));
    assert!(!archive::is_archive_name("gzip"));
}

#[test]
fn strips_the_full_archive_extension() {
    assert_eq!(archive::archive_stem("photos.zip"), "photos");
    assert_eq!(archive::archive_stem("backup.tar.gz"), "backup");
    assert_eq!(archive::archive_stem("notes.txt"), "notes.txt");
}

#[test]
fn unique_sibling_numbers_collisions() {
    let dir = tempdir().unwrap();
    fs::write(dir.path().join("Archive.zip"), b"x").unwrap();
    fs::write(dir.path().join("Archive (2).zip"), b"x").unwrap();

    let picked = archive::unique_sibling(dir.path(), "Archive", ".zip");

    assert_eq!(picked, dir.path().join("Archive (3).zip"));
}

#[tokio::test]
async fn compress_then_extract_round_trips() {
    let dir = tempdir().unwrap();
    fs::create_dir(dir.path().join("sub")).unwrap();
    fs::write(dir.path().join("sub").join("a.txt"), b"alpha").unwrap();
    fs::write(dir.path().join("b.txt"), b"beta").unwrap();

    let dest = dir.path().join("out.zip");
    archive::compress(
        dir.path(),
        &["sub".to_string(), "b.txt".to_string()],
        &dest,
    )
    .await
    .unwrap();
    assert!(dest.exists());

    let unpacked = dir.path().join("unpacked");
    archive::extract(&dest, &unpacked).await.unwrap();

    assert_eq!(fs::read(unpacked.join("sub").join("a.txt")).unwrap(), b"alpha");
    assert_eq!(fs::read(unpacked.join("b.txt")).unwrap(), b"beta");
}

#[tokio::test]
async fn extract_reports_bsdtar_errors() {
    let dir = tempdir().unwrap();
    let bogus = dir.path().join("not-an-archive.zip");
    fs::write(&bogus, b"garbage").unwrap();

    let result = archive::extract(&bogus, &dir.path().join("out")).await;

    assert!(result.is_err());
}
