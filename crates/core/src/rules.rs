use crate::settings::Rule;
use std::path::PathBuf;

pub fn glob_match(pattern: &str, name: &str) -> bool {
    fn matches(p: &[char], n: &[char]) -> bool {
        if p.is_empty() {
            return n.is_empty();
        }
        match p[0] {
            '*' => (0..=n.len()).any(|i| matches(&p[1..], &n[i..])),
            '?' => !n.is_empty() && matches(&p[1..], &n[1..]),
            c => !n.is_empty() && n[0] == c && matches(&p[1..], &n[1..]),
        }
    }
    let p: Vec<char> = pattern.to_lowercase().chars().collect();
    let n: Vec<char> = name.to_lowercase().chars().collect();
    matches(&p, &n)
}

fn split_name(name: &str) -> (String, String) {
    match name.rfind('.') {
        Some(i) if i > 0 => (name[..i].to_string(), name[i..].to_string()),
        _ => (name.to_string(), String::new()),
    }
}

pub async fn apply_rule(rule: &Rule) -> Vec<(PathBuf, PathBuf)> {
    let src_dir = PathBuf::from(&rule.dir);
    let dest_dir = PathBuf::from(&rule.dest);
    let mut moved = Vec::new();
    if src_dir == dest_dir || rule.pattern.is_empty() {
        return moved;
    }
    let Ok(mut read_dir) = tokio::fs::read_dir(&src_dir).await else {
        return moved;
    };
    let mut targets: Vec<(PathBuf, String)> = Vec::new();
    while let Ok(Some(entry)) = read_dir.next_entry().await {
        let name = entry.file_name().to_string_lossy().into_owned();
        if name.starts_with('.') {
            continue;
        }
        let Ok(meta) = entry.metadata().await else {
            continue;
        };
        if !meta.is_file() {
            continue;
        }
        if glob_match(&rule.pattern, &name) {
            targets.push((entry.path(), name));
        }
    }
    if targets.is_empty() {
        return moved;
    }
    if tokio::fs::create_dir_all(&dest_dir).await.is_err() {
        return moved;
    }
    for (src, name) in targets {
        let (stem, suffix) = split_name(&name);
        let dest = crate::archive::unique_sibling(&dest_dir, &stem, &suffix);
        if tokio::fs::rename(&src, &dest).await.is_ok() {
            moved.push((src, dest));
        }
    }
    moved
}
