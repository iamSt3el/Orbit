use fm_core::mime;
use std::fs;
use tempfile::tempdir;

#[test]
fn detects_mime_by_extension() {
    let dir = tempdir().unwrap();
    let file_path = dir.path().join("notes.txt");
    fs::write(&file_path, b"hello").unwrap();

    let info = mime::detect(&file_path);

    assert_eq!(info.mime_type, "text/plain");
    assert_eq!(info.icon_key, "text");
}

#[test]
fn detects_mime_by_magic_bytes_when_extension_is_missing() {
    let dir = tempdir().unwrap();
    let file_path = dir.path().join("mystery");
    let png_signature: [u8; 8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    fs::write(&file_path, png_signature).unwrap();

    let info = mime::detect(&file_path);

    assert_eq!(info.icon_key, "image");
}

#[test]
fn falls_back_to_octet_stream_when_undetectable() {
    let dir = tempdir().unwrap();
    let file_path = dir.path().join("mystery");
    fs::write(&file_path, b"not a recognizable format").unwrap();

    let info = mime::detect(&file_path);

    assert_eq!(info.mime_type, "application/octet-stream");
    assert_eq!(info.icon_key, "file");
}

#[test]
fn directory_mime_is_inode_directory() {
    let info = mime::detect_dir();

    assert_eq!(info.mime_type, "inode/directory");
    assert_eq!(info.icon_key, "folder");
}
