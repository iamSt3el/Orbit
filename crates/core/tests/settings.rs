use fm_core::settings::Settings;
use tempfile::tempdir;

#[test]
fn load_from_missing_file_returns_defaults() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("settings.json");

    let settings = Settings::load_from(&path);

    assert_eq!(settings, Settings::default());
}

#[test]
fn load_from_invalid_json_returns_defaults() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("settings.json");
    std::fs::write(&path, "not json").unwrap();

    let settings = Settings::load_from(&path);

    assert_eq!(settings, Settings::default());
}

#[test]
fn save_then_load_round_trips() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("nested").join("settings.json");

    let settings = Settings {
        view_mode: "grid".to_string(),
        icon_size_level: "large".to_string(),
        sort_key: "size".to_string(),
        sort_ascending: false,
        show_hidden: true,
        last_path: "/home/steel/Downloads".to_string(),
        resume_last_path: false,
        pinned_folders: vec!["/home/steel/projects".to_string()],
    };
    settings.save_to(&path).unwrap();

    let loaded = Settings::load_from(&path);

    assert_eq!(loaded, settings);
}

#[test]
fn load_from_partial_json_fills_in_defaults_for_missing_fields() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("settings.json");
    std::fs::write(&path, r#"{"show_hidden":true}"#).unwrap();

    let loaded = Settings::load_from(&path);

    assert!(loaded.show_hidden);
    assert_eq!(loaded.view_mode, Settings::default().view_mode);
    assert_eq!(loaded.sort_key, Settings::default().sort_key);
}
