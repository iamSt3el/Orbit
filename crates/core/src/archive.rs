use std::collections::HashMap;
use std::io;
use std::path::{Path, PathBuf};
use tokio::io::AsyncBufReadExt;

pub const ARCHIVE_EXTENSIONS: [&str; 11] = [
    ".tar.gz", ".tar.xz", ".tar.zst", ".tar.bz2", ".tgz", ".txz", ".tbz2", ".tar", ".zip",
    ".7z", ".rar",
];

pub fn is_archive_name(name: &str) -> bool {
    let lower = name.to_lowercase();
    ARCHIVE_EXTENSIONS.iter().any(|ext| lower.ends_with(ext))
}

pub fn archive_stem(name: &str) -> String {
    let lower = name.to_lowercase();
    for ext in ARCHIVE_EXTENSIONS {
        if lower.ends_with(ext) {
            return name[..name.len() - ext.len()].to_string();
        }
    }
    name.to_string()
}

pub fn unique_sibling(dir: &Path, stem: &str, suffix: &str) -> PathBuf {
    let mut candidate = dir.join(format!("{stem}{suffix}"));
    let mut n = 2;
    while candidate.exists() {
        candidate = dir.join(format!("{stem} ({n}){suffix}"));
        n += 1;
    }
    candidate
}

pub fn source_sizes(parent: &Path, names: &[String]) -> (HashMap<String, u64>, u64) {
    fn walk(base: &Path, rel: &str, map: &mut HashMap<String, u64>, total: &mut u64) {
        let abs = base.join(rel);
        let Ok(meta) = std::fs::symlink_metadata(&abs) else {
            return;
        };
        if meta.is_dir() {
            if let Ok(read_dir) = std::fs::read_dir(&abs) {
                for entry in read_dir.flatten() {
                    if let Some(name) = entry.file_name().to_str() {
                        walk(base, &format!("{rel}/{name}"), map, total);
                    }
                }
            }
        } else {
            map.insert(rel.to_string(), meta.len());
            *total += meta.len();
        }
    }
    let mut map = HashMap::new();
    let mut total = 0;
    for name in names {
        walk(parent, name, &mut map, &mut total);
    }
    (map, total)
}

async fn run_verbose_with_progress(
    mut command: tokio::process::Command,
    line_prefix: &str,
    sizes: &HashMap<String, u64>,
    progress: tokio::sync::mpsc::UnboundedSender<u64>,
) -> io::Result<()> {
    let mut child = command
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::piped())
        .spawn()?;
    let stderr = child
        .stderr
        .take()
        .ok_or_else(|| io::Error::new(io::ErrorKind::Other, "no stderr pipe"))?;
    let mut lines = tokio::io::BufReader::new(stderr).lines();
    let mut done: u64 = 0;
    let mut error_lines: Vec<String> = Vec::new();
    while let Some(line) = lines.next_line().await? {
        if let Some(path) = line.strip_prefix(line_prefix) {
            if let Some(size) = sizes.get(path) {
                done += size;
                let _ = progress.send(done);
            }
        } else if !line.trim().is_empty() {
            error_lines.push(line);
        }
    }
    let status = child.wait().await?;
    if status.success() {
        Ok(())
    } else {
        Err(io::Error::new(
            io::ErrorKind::Other,
            error_lines.join("\n").trim().to_string(),
        ))
    }
}

pub async fn compress_with_progress(
    parent: &Path,
    names: &[String],
    dest: &Path,
    sizes: &HashMap<String, u64>,
    progress: tokio::sync::mpsc::UnboundedSender<u64>,
) -> io::Result<()> {
    let mut command = tokio::process::Command::new("bsdtar");
    command
        .arg("-acvf")
        .arg(dest)
        .arg("-C")
        .arg(parent)
        .arg("--")
        .args(names);
    let result = run_verbose_with_progress(command, "a ", sizes, progress).await;
    if result.is_err() {
        let _ = tokio::fs::remove_file(dest).await;
    }
    result
}

pub async fn compress(parent: &Path, names: &[String], dest: &Path) -> io::Result<()> {
    let (tx, _rx) = tokio::sync::mpsc::unbounded_channel();
    compress_with_progress(parent, names, dest, &HashMap::new(), tx).await
}

pub async fn archive_entry_sizes(archive: &Path) -> io::Result<(HashMap<String, u64>, u64)> {
    fn parse_tv_line(line: &str) -> Option<(String, u64)> {
        let mut rest = line.trim_start();
        let mut fields: Vec<&str> = Vec::new();
        for _ in 0..8 {
            let end = rest.find(char::is_whitespace)?;
            fields.push(&rest[..end]);
            rest = rest[end..].trim_start();
        }
        let size: u64 = fields[4].parse().ok()?;
        if rest.is_empty() {
            return None;
        }
        Some((rest.to_string(), size))
    }

    let output = tokio::process::Command::new("bsdtar")
        .arg("-tvf")
        .arg(archive)
        .output()
        .await?;
    if !output.status.success() {
        return Err(io::Error::new(
            io::ErrorKind::Other,
            String::from_utf8_lossy(&output.stderr).trim().to_string(),
        ));
    }
    let mut map = HashMap::new();
    let mut total = 0;
    for line in String::from_utf8_lossy(&output.stdout).lines() {
        if let Some((path, size)) = parse_tv_line(line) {
            map.insert(path, size);
            total += size;
        }
    }
    Ok((map, total))
}

pub async fn extract_with_progress(
    archive: &Path,
    dest_dir: &Path,
    sizes: &HashMap<String, u64>,
    progress: tokio::sync::mpsc::UnboundedSender<u64>,
) -> io::Result<()> {
    tokio::fs::create_dir_all(dest_dir).await?;
    let mut command = tokio::process::Command::new("bsdtar");
    command.arg("-xvf").arg(archive).arg("-C").arg(dest_dir);
    run_verbose_with_progress(command, "x ", sizes, progress).await
}

pub async fn extract(archive: &Path, dest_dir: &Path) -> io::Result<()> {
    let (tx, _rx) = tokio::sync::mpsc::unbounded_channel();
    extract_with_progress(archive, dest_dir, &HashMap::new(), tx).await
}
