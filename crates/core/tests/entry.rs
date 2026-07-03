use fm_core::FileEntry;
use std::path::PathBuf;
use std::time::SystemTime;

#[test]
fn file_entry_stores_all_fields() {
    let entry = FileEntry {
        name: "foo.txt".to_string(),
        path: PathBuf::from("/tmp/foo.txt"),
        is_dir: false,
        size: 42,
        modified: SystemTime::UNIX_EPOCH,
        mime_type: "text/plain".to_string(),
        icon_key: "text".to_string(),
        permissions: "rw-r--r--".to_string(),
        thumbnail_path: None,
    };

    assert_eq!(entry.name, "foo.txt");
    assert_eq!(entry.path, PathBuf::from("/tmp/foo.txt"));
    assert!(!entry.is_dir);
    assert_eq!(entry.size, 42);
    assert_eq!(entry.mime_type, "text/plain");
    assert_eq!(entry.icon_key, "text");
    assert_eq!(entry.permissions, "rw-r--r--");
}
