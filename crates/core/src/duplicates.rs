use sha2::{Digest, Sha256};
use std::collections::HashMap;
use std::io::Read;
use std::path::{Path, PathBuf};
use std::time::SystemTime;

pub struct DuplicateGroup {
    pub size: u64,
    pub paths: Vec<String>,
}

fn hash_file(path: &Path) -> Option<[u8; 32]> {
    let mut file = std::fs::File::open(path).ok()?;
    let mut hasher = Sha256::new();
    let mut buf = [0u8; 65536];
    loop {
        let n = file.read(&mut buf).ok()?;
        if n == 0 {
            break;
        }
        hasher.update(&buf[..n]);
    }
    Some(hasher.finalize().into())
}

pub fn find_duplicates(
    root: &Path,
    include_hidden: bool,
    max_files: usize,
    should_stop: &dyn Fn() -> bool,
) -> Vec<DuplicateGroup> {
    let mut files: Vec<(String, u64, SystemTime)> = Vec::new();
    let mut queue = std::collections::VecDeque::new();
    queue.push_back(PathBuf::new());
    while let Some(rel_dir) = queue.pop_front() {
        if should_stop() || files.len() >= max_files {
            break;
        }
        let Ok(read_dir) = std::fs::read_dir(root.join(&rel_dir)) else {
            continue;
        };
        for entry in read_dir.flatten() {
            if should_stop() || files.len() >= max_files {
                break;
            }
            let name = entry.file_name().to_string_lossy().into_owned();
            if !include_hidden && name.starts_with('.') {
                continue;
            }
            let rel = if rel_dir.as_os_str().is_empty() {
                PathBuf::from(&name)
            } else {
                rel_dir.join(&name)
            };
            let Ok(meta) = entry.metadata() else {
                continue;
            };
            if meta.is_dir() {
                queue.push_back(rel);
            } else if meta.is_file() && meta.len() > 0 {
                files.push((
                    rel.to_string_lossy().into_owned(),
                    meta.len(),
                    meta.modified().unwrap_or(SystemTime::UNIX_EPOCH),
                ));
            }
        }
    }

    let mut by_size: HashMap<u64, Vec<(String, SystemTime)>> = HashMap::new();
    for (rel, size, modified) in files {
        by_size.entry(size).or_default().push((rel, modified));
    }

    let mut groups: Vec<DuplicateGroup> = Vec::new();
    for (size, candidates) in by_size {
        if candidates.len() < 2 {
            continue;
        }
        let mut by_hash: HashMap<[u8; 32], Vec<(String, SystemTime)>> = HashMap::new();
        for (rel, modified) in candidates {
            if should_stop() {
                return groups;
            }
            if let Some(hash) = hash_file(&root.join(&rel)) {
                by_hash.entry(hash).or_default().push((rel, modified));
            }
        }
        for (_, mut members) in by_hash {
            if members.len() < 2 {
                continue;
            }
            members.sort_by(|a, b| b.1.cmp(&a.1));
            groups.push(DuplicateGroup {
                size,
                paths: members.into_iter().map(|(rel, _)| rel).collect(),
            });
        }
    }
    groups.sort_by(|a, b| {
        (b.size * (b.paths.len() as u64 - 1)).cmp(&(a.size * (a.paths.len() as u64 - 1)))
    });
    groups
}
