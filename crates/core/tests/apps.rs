use fm_core::apps::{exec_to_argv, mime_matches, parse_desktop_entry, resolve_icon_in};
use std::path::Path;

#[test]
fn parse_desktop_entry_reads_name_exec_and_mimes() {
    let text = "\
[Desktop Entry]
Type=Application
Name=Image Viewer
Name[de]=Bildbetrachter
Exec=imv %f
Icon=imv
MimeType=image/png;image/jpeg;
";
    let app = parse_desktop_entry(text).unwrap();
    assert_eq!(app.name, "Image Viewer");
    assert_eq!(app.exec, "imv %f");
    assert_eq!(app.icon, "imv");
    assert_eq!(app.mime_types, vec!["image/png", "image/jpeg"]);
}

#[test]
fn parse_desktop_entry_without_icon_yields_empty_icon() {
    let text = "[Desktop Entry]\nType=Application\nName=X\nExec=x\n";
    assert_eq!(parse_desktop_entry(text).unwrap().icon, "");
}

#[test]
fn resolve_icon_finds_hicolor_png_before_scalable_svg() {
    let dir = tempfile::tempdir().unwrap();
    let root = dir.path().join("icons");
    let png_dir = root.join("hicolor/128x128/apps");
    let svg_dir = root.join("hicolor/scalable/apps");
    std::fs::create_dir_all(&png_dir).unwrap();
    std::fs::create_dir_all(&svg_dir).unwrap();
    std::fs::write(png_dir.join("imv.png"), b"png").unwrap();
    std::fs::write(svg_dir.join("imv.svg"), b"svg").unwrap();

    let found = resolve_icon_in("imv", &[root.clone()], &[]).unwrap();
    assert_eq!(found, png_dir.join("imv.png"));

    std::fs::remove_file(png_dir.join("imv.png")).unwrap();
    let found = resolve_icon_in("imv", &[root], &[]).unwrap();
    assert_eq!(found, svg_dir.join("imv.svg"));
}

#[test]
fn resolve_icon_falls_back_to_pixmaps_and_absolute_paths() {
    let dir = tempfile::tempdir().unwrap();
    let pixmaps = dir.path().join("pixmaps");
    std::fs::create_dir_all(&pixmaps).unwrap();
    std::fs::write(pixmaps.join("gimp.png"), b"png").unwrap();

    assert_eq!(
        resolve_icon_in("gimp", &[], &[pixmaps.clone()]).unwrap(),
        pixmaps.join("gimp.png")
    );

    let abs = pixmaps.join("gimp.png");
    assert_eq!(
        resolve_icon_in(abs.to_str().unwrap(), &[], &[]).unwrap(),
        abs
    );

    assert!(resolve_icon_in("missing", &[], &[pixmaps]).is_none());
    assert!(resolve_icon_in("", &[], &[]).is_none());
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
