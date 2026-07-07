use std::io;
use std::path::{Path, PathBuf};

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

pub async fn compress(parent: &Path, names: &[String], dest: &Path) -> io::Result<()> {
    let output = tokio::process::Command::new("bsdtar")
        .arg("-acf")
        .arg(dest)
        .arg("-C")
        .arg(parent)
        .arg("--")
        .args(names)
        .output()
        .await?;
    if output.status.success() {
        Ok(())
    } else {
        let _ = tokio::fs::remove_file(dest).await;
        Err(io::Error::new(
            io::ErrorKind::Other,
            String::from_utf8_lossy(&output.stderr).trim().to_string(),
        ))
    }
}

pub async fn extract(archive: &Path, dest_dir: &Path) -> io::Result<()> {
    tokio::fs::create_dir_all(dest_dir).await?;
    let output = tokio::process::Command::new("bsdtar")
        .arg("-xf")
        .arg(archive)
        .arg("-C")
        .arg(dest_dir)
        .output()
        .await?;
    if output.status.success() {
        Ok(())
    } else {
        Err(io::Error::new(
            io::ErrorKind::Other,
            String::from_utf8_lossy(&output.stderr).trim().to_string(),
        ))
    }
}
