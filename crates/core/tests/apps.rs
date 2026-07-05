use fm_core::apps::{exec_to_argv, mime_matches, parse_desktop_entry};
use std::path::Path;

#[test]
fn parse_desktop_entry_reads_name_exec_and_mimes() {
    let text = "\
[Desktop Entry]
Type=Application
Name=Image Viewer
Name[de]=Bildbetrachter
Exec=imv %f
MimeType=image/png;image/jpeg;
";
    let app = parse_desktop_entry(text).unwrap();
    assert_eq!(app.name, "Image Viewer");
    assert_eq!(app.exec, "imv %f");
    assert_eq!(app.mime_types, vec!["image/png", "image/jpeg"]);
}

#[test]
fn parse_desktop_entry_skips_nodisplay_and_non_applications() {
    let hidden = "[Desktop Entry]\nType=Application\nName=X\nExec=x\nNoDisplay=true\n";
    assert!(parse_desktop_entry(hidden).is_none());

    let link = "[Desktop Entry]\nType=Link\nName=X\nExec=x\n";
    assert!(parse_desktop_entry(link).is_none());
}

#[test]
fn parse_desktop_entry_ignores_other_sections() {
    let text = "\
[Desktop Entry]
Type=Application
Name=App
Exec=app %U
[Desktop Action new-window]
Name=New Window
Exec=other --new
";
    let app = parse_desktop_entry(text).unwrap();
    assert_eq!(app.name, "App");
    assert_eq!(app.exec, "app %U");
}

#[test]
fn mime_matches_exact_and_wildcard() {
    let patterns = vec!["image/png".to_string(), "video/*".to_string()];
    assert!(mime_matches(&patterns, "image/png"));
    assert!(mime_matches(&patterns, "video/mp4"));
    assert!(!mime_matches(&patterns, "image/jpeg"));
    assert!(!mime_matches(&patterns, "videos/mp4"));
}

#[test]
fn exec_to_argv_substitutes_and_appends() {
    let target = Path::new("/tmp/a b.png");
    assert_eq!(
        exec_to_argv("imv %f", target),
        vec!["imv".to_string(), "/tmp/a b.png".to_string()]
    );
    // %i/%c dropped; no placeholder appends the path.
    assert_eq!(
        exec_to_argv("gimp %i", target),
        vec!["gimp".to_string(), "/tmp/a b.png".to_string()]
    );
}
