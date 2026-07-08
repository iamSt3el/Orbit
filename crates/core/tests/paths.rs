use fm_core::paths;

#[test]
fn trash_dir_points_at_the_freedesktop_trash_files_directory() {
    let dir = paths::trash_dir().expect("XDG data dir should be resolvable");
    assert!(dir.ends_with("Trash/files"));
}

#[test]
fn theme_colors_path_points_inside_the_app_config_dir() {
    let path = paths::theme_colors_path().expect("XDG config dir should be resolvable");
    assert!(path.ends_with("orbit/colors.json"));
}

#[test]
fn expand_tilde_replaces_a_leading_tilde_with_home() {
    let home = paths::home_dir().unwrap().display().to_string();
    assert_eq!(paths::expand_tilde("~"), home);
    assert_eq!(paths::expand_tilde("~/Downloads"), format!("{home}/Downloads"));
    assert_eq!(paths::expand_tilde("/etc"), "/etc");
    assert_eq!(paths::expand_tilde("~user/x"), "~user/x");
}

#[test]
fn complete_dir_completes_a_unique_directory_match() {
    let dir = tempfile::tempdir().unwrap();
    std::fs::create_dir(dir.path().join("Documents")).unwrap();
    std::fs::create_dir(dir.path().join("Music")).unwrap();
    std::fs::write(dir.path().join("Dockerfile"), "").unwrap();

    let partial = format!("{}/Doc", dir.path().display());
    let completed = paths::complete_dir(&partial).unwrap();

    assert_eq!(completed, format!("{}/Documents/", dir.path().display()));
}

#[test]
fn complete_dir_is_case_insensitive() {
    let dir = tempfile::tempdir().unwrap();
    std::fs::create_dir(dir.path().join("Documents")).unwrap();

    let partial = format!("{}/doc", dir.path().display());
    let completed = paths::complete_dir(&partial).unwrap();

    assert_eq!(completed, format!("{}/Documents/", dir.path().display()));
}

#[test]
fn complete_dir_extends_to_the_common_prefix_of_multiple_matches() {
    let dir = tempfile::tempdir().unwrap();
    std::fs::create_dir(dir.path().join("projects")).unwrap();
    std::fs::create_dir(dir.path().join("progress")).unwrap();

    let partial = format!("{}/p", dir.path().display());
    let completed = paths::complete_dir(&partial).unwrap();

    assert_eq!(completed, format!("{}/pro", dir.path().display()));
}

#[test]
fn complete_dir_skips_hidden_directories_unless_prefix_is_dotted() {
    let dir = tempfile::tempdir().unwrap();
    std::fs::create_dir(dir.path().join(".config")).unwrap();

    let base = dir.path().display();
    assert!(paths::complete_dir(&format!("{base}/c")).is_none());
    assert_eq!(
        paths::complete_dir(&format!("{base}/.c")).unwrap(),
        format!("{base}/.config/")
    );
}

#[test]
fn complete_dir_returns_none_when_nothing_matches() {
    let dir = tempfile::tempdir().unwrap();
    let partial = format!("{}/zzz", dir.path().display());
    assert!(paths::complete_dir(&partial).is_none());
}
