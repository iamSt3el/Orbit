use fm_core::paths;

#[test]
fn trash_dir_points_at_the_freedesktop_trash_files_directory() {
    let dir = paths::trash_dir().expect("XDG data dir should be resolvable");
    assert!(dir.ends_with("Trash/files"));
}

#[test]
fn theme_colors_path_points_inside_the_app_config_dir() {
    let path = paths::theme_colors_path().expect("XDG config dir should be resolvable");
    assert!(path.ends_with("filemanager/colors.json"));
}
