use fm_core::paths;

#[test]
fn trash_dir_points_at_the_freedesktop_trash_files_directory() {
    let dir = paths::trash_dir().expect("XDG data dir should be resolvable");
    assert!(dir.ends_with("Trash/files"));
}
