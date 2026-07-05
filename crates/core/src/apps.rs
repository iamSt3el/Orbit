use std::path::{Path, PathBuf};

/// A launchable application parsed from a freedesktop .desktop entry —
/// the data the "Open with…" chooser needs (roadmap round-2 item 26).
#[derive(Debug, Clone, PartialEq)]
pub struct DesktopApp {
    pub name: String,
    pub exec: String,
    pub mime_types: Vec<String>,
}

/// Parses the `[Desktop Entry]` section of a .desktop file. Returns None
/// for anything that shouldn't appear in a chooser: non-Applications,
/// NoDisplay/Hidden entries, or entries missing Name/Exec. Localized keys
/// (`Name[de]`) are ignored — the plain `Name` is the fallback every
/// entry must carry.
pub fn parse_desktop_entry(text: &str) -> Option<DesktopApp> {
    let mut in_section = false;
    let mut name = None;
    let mut exec = None;
    let mut mime_types = Vec::new();
    let mut hidden = false;
    let mut is_app = false;
    for line in text.lines() {
        let line = line.trim();
        if line.starts_with('[') {
            in_section = line == "[Desktop Entry]";
            continue;
        }
        if !in_section {
            continue;
        }
        let Some((key, value)) = line.split_once('=') else {
            continue;
        };
        let value = value.trim();
        match key.trim() {
            "Name" => name = Some(value.to_string()),
            "Exec" => exec = Some(value.to_string()),
            "MimeType" => {
                mime_types = value
                    .split(';')
                    .map(str::trim)
                    .filter(|s| !s.is_empty())
                    .map(str::to_string)
                    .collect();
            }
            "NoDisplay" | "Hidden" => hidden = hidden || value == "true",
            "Type" => is_app = value == "Application",
            _ => {}
        }
    }
    if hidden || !is_app {
        return None;
    }
    Some(DesktopApp {
        name: name?,
        exec: exec?,
        mime_types,
    })
}

/// Whether any of an entry's MimeType patterns covers `mime` — exact
/// match or a `type/*` wildcard.
pub fn mime_matches(patterns: &[String], mime: &str) -> bool {
    patterns.iter().any(|p| {
        if p == mime {
            return true;
        }
        p.strip_suffix("/*")
            .is_some_and(|prefix| mime.strip_prefix(prefix).is_some_and(|r| r.starts_with('/')))
    })
}

/// XDG application dirs, user-first — the first .desktop basename seen
/// wins, so user-local entries override system ones.
fn application_dirs() -> Vec<PathBuf> {
    let mut dirs = Vec::new();
    if let Some(home) = crate::paths::home_dir() {
        dirs.push(home.join(".local/share/applications"));
    }
    dirs.push(PathBuf::from("/usr/local/share/applications"));
    dirs.push(PathBuf::from("/usr/share/applications"));
    dirs
}

/// All installed apps declaring support for `mime`, deduped by desktop
/// basename (user dirs override system dirs) and sorted by display name.
/// Synchronous directory scan — a few hundred small files; callers run it
/// on a background task if that matters to them.
pub fn apps_for_mime(mime: &str) -> Vec<DesktopApp> {
    let mut out: Vec<DesktopApp> = Vec::new();
    let mut seen = std::collections::HashSet::new();
    for dir in application_dirs() {
        let Ok(read_dir) = std::fs::read_dir(&dir) else {
            continue;
        };
        for dir_entry in read_dir.flatten() {
            let path = dir_entry.path();
            if path.extension().and_then(|s| s.to_str()) != Some("desktop") {
                continue;
            }
            let Some(base) = path.file_name().map(|n| n.to_owned()) else {
                continue;
            };
            if seen.contains(&base) {
                continue;
            }
            let Ok(text) = std::fs::read_to_string(&path) else {
                continue;
            };
            let Some(app) = parse_desktop_entry(&text) else {
                continue;
            };
            // Registered (dedupe) even when the mime doesn't match, so a
            // user-local override shadows its system twin either way.
            seen.insert(base);
            if mime_matches(&app.mime_types, mime) {
                out.push(app);
            }
        }
    }
    out.sort_by(|a, b| a.name.to_lowercase().cmp(&b.name.to_lowercase()));
    out
}

/// Expands an Exec line into argv for `target`: %f/%F/%u/%U become the
/// path, other field codes (%i, %c, %k…) are dropped per the spec; a
/// missing placeholder appends the path.
pub fn exec_to_argv(exec: &str, target: &Path) -> Vec<String> {
    let target_str = target.display().to_string();
    let mut argv: Vec<String> = Vec::new();
    let mut used_placeholder = false;
    for token in exec.split_whitespace() {
        match token {
            "%f" | "%F" | "%u" | "%U" => {
                argv.push(target_str.clone());
                used_placeholder = true;
            }
            t if t.starts_with('%') => {}
            t => argv.push(t.trim_matches('"').to_string()),
        }
    }
    if !argv.is_empty() && !used_placeholder {
        argv.push(target_str);
    }
    argv
}

/// Launches `exec` on `target`, fire-and-forget like ops::open_file.
pub async fn launch_with(exec: &str, target: &Path) -> std::io::Result<()> {
    let argv = exec_to_argv(exec, target);
    if argv.is_empty() {
        return Err(std::io::Error::new(
            std::io::ErrorKind::InvalidInput,
            "empty Exec line",
        ));
    }
    tokio::process::Command::new(&argv[0])
        .args(&argv[1..])
        .spawn()?;
    Ok(())
}
