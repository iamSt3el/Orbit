# File Manager Backend Core — Implementation Plan (Plan 1 of 3)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `fm-core`, a standalone Rust library crate implementing directory listing, file operations, freedesktop Trash, and live filesystem watching — fully unit/integration tested via `cargo test`, with no Qt/cxx-qt/QML dependency.

**Architecture:** A Cargo workspace with one member crate, `crates/core` (package `fm-core`). Six focused modules: `entry` (data type), `mime` (detection), `listing` (async streaming directory reads), `ops` (create/rename/copy/move), `trash` (freedesktop Trash spec), `watcher` (live change notifications). Each module is async-first (Tokio) and has no knowledge of Qt — the cxx-qt bridge crate built in Plan 2 will depend on this crate and wrap it for QML.

**Tech Stack:** Rust (edition 2021), Tokio (async runtime), `notify` (filesystem watching), `mime_guess` + `infer` (mime detection), `dirs` (XDG paths), `time` (ISO 8601 timestamps), `tempfile` (test fixtures).

## Global Constraints

- Target platform is Linux only — no Windows/macOS path handling needed.
- Directory listing must stream entries incrementally as they're read, not block until the full directory is read (spec section 2, "Async I/O").
- Sorting and filtering happen in Rust, not in QML — this crate provides the raw entry stream; sorting is layered on top by the cxx-qt bridge (Plan 2), not by this crate.
- Trash uses the freedesktop.org Trash specification at `$XDG_DATA_HOME/Trash/{files,info}` (spec section 2, "Trash").
- Mime detection is lightweight: file extension first, magic-byte sniffing as fallback — no shared-mime-info parsing (spec section 2, "Mime detection").
- This plan covers only `fm-core`. No Qt, cxx-qt, or QML code is in scope here — that starts in Plan 2, which will add `crates/app` as a workspace member depending on `fm-core`.

---

### Task 1: Workspace scaffold + `FileEntry` type

**Files:**
- Create: `Cargo.toml` (workspace root)
- Create: `crates/core/Cargo.toml`
- Create: `crates/core/src/lib.rs`
- Create: `crates/core/src/entry.rs`
- Test: `crates/core/tests/entry.rs`

**Interfaces:**
- Produces: `fm_core::FileEntry` struct with public fields `name: String`, `path: PathBuf`, `is_dir: bool`, `size: u64`, `modified: SystemTime`, `mime_type: String`, `icon_key: String`. Every later task constructs or consumes this exact struct and field set.

- [ ] **Step 1: Create the workspace root**

`Cargo.toml`:
```toml
[workspace]
resolver = "2"
members = ["crates/core"]
```

- [ ] **Step 2: Create the core crate manifest**

`crates/core/Cargo.toml`:
```toml
[package]
name = "fm-core"
version = "0.1.0"
edition = "2021"

[dependencies]

[dev-dependencies]
tempfile = "3"
```

- [ ] **Step 3: Write the failing test**

`crates/core/tests/entry.rs`:
```rust
use fm_core::FileEntry;
use std::path::PathBuf;
use std::time::SystemTime;

#[test]
fn file_entry_stores_all_fields() {
    let entry = FileEntry {
        name: "foo.txt".to_string(),
        path: PathBuf::from("/tmp/foo.txt"),
        is_dir: false,
        size: 42,
        modified: SystemTime::UNIX_EPOCH,
        mime_type: "text/plain".to_string(),
        icon_key: "text".to_string(),
    };

    assert_eq!(entry.name, "foo.txt");
    assert_eq!(entry.path, PathBuf::from("/tmp/foo.txt"));
    assert!(!entry.is_dir);
    assert_eq!(entry.size, 42);
    assert_eq!(entry.mime_type, "text/plain");
    assert_eq!(entry.icon_key, "text");
}
```

- [ ] **Step 4: Run test to verify it fails**

Run: `cargo test -p fm-core --test entry`
Expected: FAIL to compile — `fm_core::FileEntry` does not exist yet.

- [ ] **Step 5: Write minimal implementation**

`crates/core/src/entry.rs`:
```rust
use std::path::PathBuf;
use std::time::SystemTime;

#[derive(Debug, Clone, PartialEq)]
pub struct FileEntry {
    pub name: String,
    pub path: PathBuf,
    pub is_dir: bool,
    pub size: u64,
    pub modified: SystemTime,
    pub mime_type: String,
    pub icon_key: String,
}
```

`crates/core/src/lib.rs`:
```rust
pub mod entry;

pub use entry::FileEntry;
```

- [ ] **Step 6: Run test to verify it passes**

Run: `cargo test -p fm-core --test entry`
Expected: PASS (1 test)

- [ ] **Step 7: Commit**

```bash
git add Cargo.toml crates/core/Cargo.toml crates/core/src/lib.rs crates/core/src/entry.rs crates/core/tests/entry.rs
git commit -m "feat(core): add workspace and FileEntry type"
```

---

### Task 2: Mime detection

**Files:**
- Create: `crates/core/src/mime.rs`
- Modify: `crates/core/Cargo.toml`
- Modify: `crates/core/src/lib.rs`
- Test: `crates/core/tests/mime.rs`

**Interfaces:**
- Consumes: nothing from Task 1.
- Produces: `fm_core::mime::MimeInfo { mime_type: String, icon_key: String }`, `fm_core::mime::detect(path: &Path) -> MimeInfo`, `fm_core::mime::detect_dir() -> MimeInfo`. Task 3 (`listing.rs`) calls both of these directly.

- [ ] **Step 1: Add dependencies**

`crates/core/Cargo.toml` — add under `[dependencies]`:
```toml
mime_guess = "2"
infer = "0.16"
```

- [ ] **Step 2: Write the failing tests**

`crates/core/tests/mime.rs`:
```rust
use fm_core::mime;
use std::fs;
use tempfile::tempdir;

#[test]
fn detects_mime_by_extension() {
    let dir = tempdir().unwrap();
    let file_path = dir.path().join("notes.txt");
    fs::write(&file_path, b"hello").unwrap();

    let info = mime::detect(&file_path);

    assert_eq!(info.mime_type, "text/plain");
    assert_eq!(info.icon_key, "text");
}

#[test]
fn detects_mime_by_magic_bytes_when_extension_is_missing() {
    let dir = tempdir().unwrap();
    let file_path = dir.path().join("mystery");
    let png_signature: [u8; 8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    fs::write(&file_path, png_signature).unwrap();

    let info = mime::detect(&file_path);

    assert_eq!(info.icon_key, "image");
}

#[test]
fn falls_back_to_octet_stream_when_undetectable() {
    let dir = tempdir().unwrap();
    let file_path = dir.path().join("mystery");
    fs::write(&file_path, b"not a recognizable format").unwrap();

    let info = mime::detect(&file_path);

    assert_eq!(info.mime_type, "application/octet-stream");
    assert_eq!(info.icon_key, "file");
}

#[test]
fn directory_mime_is_inode_directory() {
    let info = mime::detect_dir();

    assert_eq!(info.mime_type, "inode/directory");
    assert_eq!(info.icon_key, "folder");
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `cargo test -p fm-core --test mime`
Expected: FAIL to compile — `fm_core::mime` does not exist yet.

- [ ] **Step 4: Write minimal implementation**

`crates/core/src/mime.rs`:
```rust
use std::fs;
use std::path::Path;

#[derive(Debug, Clone, PartialEq)]
pub struct MimeInfo {
    pub mime_type: String,
    pub icon_key: String,
}

pub fn detect_dir() -> MimeInfo {
    MimeInfo {
        mime_type: "inode/directory".to_string(),
        icon_key: "folder".to_string(),
    }
}

pub fn detect(path: &Path) -> MimeInfo {
    if let Some(guess) = mime_guess::from_path(path).first() {
        return MimeInfo {
            icon_key: icon_key_for(guess.as_ref()),
            mime_type: guess.essence_str().to_string(),
        };
    }

    if let Ok(bytes) = fs::read(path) {
        let sniff_len = bytes.len().min(8192);
        if let Some(kind) = infer::get(&bytes[..sniff_len]) {
            let mime = kind.mime_type();
            return MimeInfo {
                icon_key: icon_key_for(mime),
                mime_type: mime.to_string(),
            };
        }
    }

    MimeInfo {
        mime_type: "application/octet-stream".to_string(),
        icon_key: "file".to_string(),
    }
}

fn icon_key_for(mime: &str) -> String {
    if mime == "application/pdf" {
        return "pdf".to_string();
    }
    if mime.starts_with("image/") {
        return "image".to_string();
    }
    if mime.starts_with("video/") {
        return "video".to_string();
    }
    if mime.starts_with("audio/") {
        return "audio".to_string();
    }
    if mime.starts_with("text/") {
        return "text".to_string();
    }
    if matches!(
        mime,
        "application/zip"
            | "application/x-tar"
            | "application/gzip"
            | "application/x-7z-compressed"
            | "application/x-rar-compressed"
    ) {
        return "archive".to_string();
    }
    "file".to_string()
}
```

`crates/core/src/lib.rs`:
```rust
pub mod entry;
pub mod mime;

pub use entry::FileEntry;
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cargo test -p fm-core --test mime`
Expected: PASS (4 tests)

- [ ] **Step 6: Commit**

```bash
git add crates/core/Cargo.toml crates/core/src/lib.rs crates/core/src/mime.rs crates/core/tests/mime.rs
git commit -m "feat(core): add mime detection by extension and magic bytes"
```

---

### Task 3: Async streaming directory listing

**Files:**
- Create: `crates/core/src/listing.rs`
- Modify: `crates/core/Cargo.toml`
- Modify: `crates/core/src/lib.rs`
- Test: `crates/core/tests/listing.rs`

**Interfaces:**
- Consumes: `fm_core::FileEntry` (Task 1), `fm_core::mime::{detect, detect_dir}` (Task 2).
- Produces: `fm_core::listing::list_directory(path: PathBuf) -> tokio::sync::mpsc::Receiver<std::io::Result<FileEntry>>`. Entries arrive in OS-provided (unsorted) order — the consumer sorts if needed. Plan 2's model layer relies on this exact signature.

- [ ] **Step 1: Add the Tokio dependency**

`crates/core/Cargo.toml` — add under `[dependencies]`:
```toml
tokio = { version = "1", features = ["full"] }
```

- [ ] **Step 2: Write the failing tests**

`crates/core/tests/listing.rs`:
```rust
use fm_core::listing;
use std::collections::HashSet;
use std::fs;
use tempfile::tempdir;

#[tokio::test]
async fn streams_all_entries_in_directory() {
    let dir = tempdir().unwrap();
    fs::write(dir.path().join("a.txt"), b"a").unwrap();
    fs::write(dir.path().join("b.txt"), b"b").unwrap();
    fs::create_dir(dir.path().join("sub")).unwrap();

    let mut rx = listing::list_directory(dir.path().to_path_buf());
    let mut names = HashSet::new();
    while let Some(result) = rx.recv().await {
        names.insert(result.unwrap().name);
    }

    assert_eq!(
        names,
        HashSet::from(["a.txt".to_string(), "b.txt".to_string(), "sub".to_string()])
    );
}

#[tokio::test]
async fn marks_directories_correctly() {
    let dir = tempdir().unwrap();
    fs::create_dir(dir.path().join("sub")).unwrap();

    let mut rx = listing::list_directory(dir.path().to_path_buf());
    let entry = rx.recv().await.unwrap().unwrap();

    assert_eq!(entry.name, "sub");
    assert!(entry.is_dir);
    assert_eq!(entry.icon_key, "folder");
    assert_eq!(entry.mime_type, "inode/directory");
}

#[tokio::test]
async fn reports_error_for_nonexistent_directory() {
    let mut rx = listing::list_directory("/nonexistent/path/that/does/not/exist".into());

    let result = rx.recv().await.expect("channel should yield one error");
    assert!(result.is_err());
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `cargo test -p fm-core --test listing`
Expected: FAIL to compile — `fm_core::listing` does not exist yet.

- [ ] **Step 4: Write minimal implementation**

`crates/core/src/listing.rs`:
```rust
use crate::entry::FileEntry;
use crate::mime;
use std::path::PathBuf;
use std::time::SystemTime;
use tokio::sync::mpsc;

pub fn list_directory(path: PathBuf) -> mpsc::Receiver<std::io::Result<FileEntry>> {
    let (tx, rx) = mpsc::channel(64);

    tokio::spawn(async move {
        let mut read_dir = match tokio::fs::read_dir(&path).await {
            Ok(read_dir) => read_dir,
            Err(e) => {
                let _ = tx.send(Err(e)).await;
                return;
            }
        };

        loop {
            match read_dir.next_entry().await {
                Ok(Some(dir_entry)) => {
                    let entry_path = dir_entry.path();
                    let metadata = match dir_entry.metadata().await {
                        Ok(metadata) => metadata,
                        Err(e) => {
                            if tx.send(Err(e)).await.is_err() {
                                return;
                            }
                            continue;
                        }
                    };

                    let is_dir = metadata.is_dir();
                    let mime_info = if is_dir {
                        mime::detect_dir()
                    } else {
                        mime::detect(&entry_path)
                    };

                    let file_entry = FileEntry {
                        name: dir_entry.file_name().to_string_lossy().into_owned(),
                        path: entry_path,
                        is_dir,
                        size: metadata.len(),
                        modified: metadata.modified().unwrap_or(SystemTime::UNIX_EPOCH),
                        mime_type: mime_info.mime_type,
                        icon_key: mime_info.icon_key,
                    };

                    if tx.send(Ok(file_entry)).await.is_err() {
                        return;
                    }
                }
                Ok(None) => return,
                Err(e) => {
                    let _ = tx.send(Err(e)).await;
                    return;
                }
            }
        }
    });

    rx
}
```

`crates/core/src/lib.rs`:
```rust
pub mod entry;
pub mod listing;
pub mod mime;

pub use entry::FileEntry;
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cargo test -p fm-core --test listing`
Expected: PASS (3 tests)

- [ ] **Step 6: Commit**

```bash
git add crates/core/Cargo.toml crates/core/src/lib.rs crates/core/src/listing.rs crates/core/tests/listing.rs
git commit -m "feat(core): add async streaming directory listing"
```

---

### Task 4: File operations — create folder and rename

**Files:**
- Create: `crates/core/src/ops.rs`
- Modify: `crates/core/src/lib.rs`
- Test: `crates/core/tests/ops.rs`

**Interfaces:**
- Consumes: nothing new.
- Produces: `fm_core::ops::create_folder(parent: &Path, name: &str) -> std::io::Result<PathBuf>`, `fm_core::ops::rename(path: &Path, new_name: &str) -> std::io::Result<PathBuf>`. Later tasks add `copy` and `move_entry` to this same file/module.

- [ ] **Step 1: Write the failing tests**

`crates/core/tests/ops.rs`:
```rust
use fm_core::ops;
use std::fs;
use tempfile::tempdir;

#[tokio::test]
async fn create_folder_makes_a_new_directory() {
    let dir = tempdir().unwrap();

    let created = ops::create_folder(dir.path(), "new-folder").await.unwrap();

    assert!(created.is_dir());
    assert_eq!(created, dir.path().join("new-folder"));
}

#[tokio::test]
async fn rename_moves_file_to_new_name_in_same_directory() {
    let dir = tempdir().unwrap();
    let original = dir.path().join("old.txt");
    fs::write(&original, b"content").unwrap();

    let renamed = ops::rename(&original, "new.txt").await.unwrap();

    assert!(!original.exists());
    assert_eq!(renamed, dir.path().join("new.txt"));
    assert_eq!(fs::read_to_string(&renamed).unwrap(), "content");
}

#[tokio::test]
async fn rename_fails_for_nonexistent_path() {
    let dir = tempdir().unwrap();
    let missing = dir.path().join("missing.txt");

    let result = ops::rename(&missing, "new.txt").await;

    assert!(result.is_err());
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cargo test -p fm-core --test ops`
Expected: FAIL to compile — `fm_core::ops` does not exist yet.

- [ ] **Step 3: Write minimal implementation**

`crates/core/src/ops.rs`:
```rust
use std::io;
use std::path::{Path, PathBuf};

pub async fn create_folder(parent: &Path, name: &str) -> io::Result<PathBuf> {
    let target = parent.join(name);
    tokio::fs::create_dir(&target).await?;
    Ok(target)
}

pub async fn rename(path: &Path, new_name: &str) -> io::Result<PathBuf> {
    let parent = path
        .parent()
        .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidInput, "path has no parent"))?;
    let target = parent.join(new_name);
    tokio::fs::rename(path, &target).await?;
    Ok(target)
}
```

`crates/core/src/lib.rs`:
```rust
pub mod entry;
pub mod listing;
pub mod mime;
pub mod ops;

pub use entry::FileEntry;
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cargo test -p fm-core --test ops`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add crates/core/src/lib.rs crates/core/src/ops.rs crates/core/tests/ops.rs
git commit -m "feat(core): add create_folder and rename operations"
```

---

### Task 5: File operations — recursive copy

**Files:**
- Modify: `crates/core/src/ops.rs`
- Modify: `crates/core/tests/ops.rs`

**Interfaces:**
- Consumes: nothing new.
- Produces: `fm_core::ops::copy(src: &Path, dst: &Path) -> Pin<Box<dyn Future<Output = std::io::Result<()>> + Send + '_>>`. Task 6's `move_entry` calls this directly as its cross-filesystem fallback.

- [ ] **Step 1: Write the failing tests**

Append to `crates/core/tests/ops.rs`:
```rust
#[tokio::test]
async fn copy_duplicates_a_single_file() {
    let dir = tempdir().unwrap();
    let src = dir.path().join("source.txt");
    fs::write(&src, b"payload").unwrap();
    let dst = dir.path().join("dest.txt");

    ops::copy(&src, &dst).await.unwrap();

    assert!(src.exists());
    assert_eq!(fs::read_to_string(&dst).unwrap(), "payload");
}

#[tokio::test]
async fn copy_duplicates_a_directory_tree() {
    let dir = tempdir().unwrap();
    let src = dir.path().join("srcdir");
    fs::create_dir(&src).unwrap();
    fs::write(src.join("top.txt"), b"top").unwrap();
    fs::create_dir(src.join("nested")).unwrap();
    fs::write(src.join("nested").join("inner.txt"), b"inner").unwrap();
    let dst = dir.path().join("dstdir");

    ops::copy(&src, &dst).await.unwrap();

    assert_eq!(fs::read_to_string(dst.join("top.txt")).unwrap(), "top");
    assert_eq!(
        fs::read_to_string(dst.join("nested").join("inner.txt")).unwrap(),
        "inner"
    );
    assert!(src.exists(), "copy must not remove the source");
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cargo test -p fm-core --test ops`
Expected: FAIL to compile — `ops::copy` does not exist yet.

- [ ] **Step 3: Write minimal implementation**

Add to `crates/core/src/ops.rs` (below existing functions, add these imports to the top of the file alongside the existing `use` lines):
```rust
use std::future::Future;
use std::pin::Pin;
```

```rust
pub fn copy<'a>(
    src: &'a Path,
    dst: &'a Path,
) -> Pin<Box<dyn Future<Output = io::Result<()>> + Send + 'a>> {
    Box::pin(async move {
        let metadata = tokio::fs::metadata(src).await?;

        if metadata.is_dir() {
            tokio::fs::create_dir_all(dst).await?;
            let mut read_dir = tokio::fs::read_dir(src).await?;
            while let Some(dir_entry) = read_dir.next_entry().await? {
                let child_src = dir_entry.path();
                let child_dst = dst.join(dir_entry.file_name());
                copy(&child_src, &child_dst).await?;
            }
            Ok(())
        } else {
            tokio::fs::copy(src, dst).await?;
            Ok(())
        }
    })
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cargo test -p fm-core --test ops`
Expected: PASS (5 tests)

- [ ] **Step 5: Commit**

```bash
git add crates/core/src/ops.rs crates/core/tests/ops.rs
git commit -m "feat(core): add recursive copy operation"
```

---

### Task 6: File operations — move

**Files:**
- Modify: `crates/core/src/ops.rs`
- Modify: `crates/core/Cargo.toml`
- Modify: `crates/core/tests/ops.rs`

**Interfaces:**
- Consumes: `fm_core::ops::copy` (Task 5).
- Produces: `fm_core::ops::move_entry(src: &Path, dst: &Path) -> std::io::Result<()>`. Plan 2's bridge invokable `move` calls this directly.

- [ ] **Step 1: Add the libc dependency**

`crates/core/Cargo.toml` — add under `[dependencies]`:
```toml
libc = "0.2"
```

- [ ] **Step 2: Write the failing tests**

Append to `crates/core/tests/ops.rs`:
```rust
#[tokio::test]
async fn move_entry_relocates_a_file_within_same_filesystem() {
    let dir = tempdir().unwrap();
    let src = dir.path().join("a.txt");
    fs::write(&src, b"hello").unwrap();
    let dst = dir.path().join("b.txt");

    ops::move_entry(&src, &dst).await.unwrap();

    assert!(!src.exists());
    assert_eq!(fs::read_to_string(&dst).unwrap(), "hello");
}

#[tokio::test]
async fn move_entry_relocates_a_directory_within_same_filesystem() {
    let dir = tempdir().unwrap();
    let src = dir.path().join("srcdir");
    fs::create_dir(&src).unwrap();
    fs::write(src.join("inner.txt"), b"x").unwrap();
    let dst = dir.path().join("dstdir");

    ops::move_entry(&src, &dst).await.unwrap();

    assert!(!src.exists());
    assert_eq!(fs::read_to_string(dst.join("inner.txt")).unwrap(), "x");
}
```

Note: the cross-filesystem (`EXDEV`) fallback path re-uses `copy` (Task 5, tested) and a plain recursive remove — it isn't covered by its own automated test here because exercising an actual cross-device rename requires two separate mounted filesystems, which isn't available in a standard test sandbox.

- [ ] **Step 3: Run tests to verify they fail**

Run: `cargo test -p fm-core --test ops`
Expected: FAIL to compile — `ops::move_entry` does not exist yet.

- [ ] **Step 4: Write minimal implementation**

Add to `crates/core/src/ops.rs`:
```rust
pub async fn move_entry(src: &Path, dst: &Path) -> io::Result<()> {
    match tokio::fs::rename(src, dst).await {
        Ok(()) => Ok(()),
        Err(e) if e.raw_os_error() == Some(libc::EXDEV) => {
            copy(src, dst).await?;
            remove_all(src).await
        }
        Err(e) => Err(e),
    }
}

async fn remove_all(path: &Path) -> io::Result<()> {
    let metadata = tokio::fs::metadata(path).await?;
    if metadata.is_dir() {
        tokio::fs::remove_dir_all(path).await
    } else {
        tokio::fs::remove_file(path).await
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cargo test -p fm-core --test ops`
Expected: PASS (7 tests)

- [ ] **Step 6: Commit**

```bash
git add crates/core/Cargo.toml crates/core/src/ops.rs crates/core/tests/ops.rs
git commit -m "feat(core): add move operation with cross-filesystem fallback"
```

---

### Task 7: Trash (freedesktop.org spec)

**Files:**
- Create: `crates/core/src/trash.rs`
- Modify: `crates/core/Cargo.toml`
- Modify: `crates/core/src/lib.rs`
- Test: `crates/core/tests/trash.rs`

**Interfaces:**
- Consumes: nothing new.
- Produces: `fm_core::trash::move_to_trash(path: &Path) -> std::io::Result<PathBuf>` (uses the real XDG data dir), `fm_core::trash::move_to_trash_in(path: &Path, data_home: &Path) -> std::io::Result<PathBuf>` (testable seam, also the basis for future per-mount trash support). Plan 2's bridge invokable `delete` calls `move_to_trash`.

- [ ] **Step 1: Add dependencies**

`crates/core/Cargo.toml` — add under `[dependencies]`:
```toml
dirs = "5"
time = { version = "0.3", features = ["formatting"] }
```

- [ ] **Step 2: Write the failing tests**

`crates/core/tests/trash.rs`:
```rust
use fm_core::trash;
use std::fs;
use tempfile::tempdir;

#[tokio::test]
async fn moves_file_into_trash_files_dir_and_writes_info_file() {
    let data_home = tempdir().unwrap();
    let source_dir = tempdir().unwrap();
    let file_path = source_dir.path().join("doomed.txt");
    fs::write(&file_path, b"bye").unwrap();

    let trashed_path = trash::move_to_trash_in(&file_path, data_home.path())
        .await
        .unwrap();

    assert!(!file_path.exists());
    assert!(trashed_path.exists());
    assert_eq!(fs::read_to_string(&trashed_path).unwrap(), "bye");

    let info_path = data_home
        .path()
        .join("Trash")
        .join("info")
        .join("doomed.txt.trashinfo");
    let info_contents = fs::read_to_string(&info_path).unwrap();
    assert!(info_contents.contains("[Trash Info]"));
    assert!(info_contents.contains(&format!("Path={}", file_path.display())));
    assert!(info_contents.contains("DeletionDate="));
}

#[tokio::test]
async fn dedupes_name_collisions_in_trash() {
    let data_home = tempdir().unwrap();
    let source_dir = tempdir().unwrap();

    let first = source_dir.path().join("dup.txt");
    fs::write(&first, b"one").unwrap();
    trash::move_to_trash_in(&first, data_home.path())
        .await
        .unwrap();

    let second = source_dir.path().join("dup.txt");
    fs::write(&second, b"two").unwrap();
    let trashed_second = trash::move_to_trash_in(&second, data_home.path())
        .await
        .unwrap();

    assert_eq!(
        trashed_second.file_name().unwrap().to_str().unwrap(),
        "dup_1.txt"
    );
    assert_eq!(fs::read_to_string(&trashed_second).unwrap(), "two");
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `cargo test -p fm-core --test trash`
Expected: FAIL to compile — `fm_core::trash` does not exist yet.

- [ ] **Step 4: Write minimal implementation**

`crates/core/src/trash.rs`:
```rust
use std::io;
use std::path::{Path, PathBuf};
use time::format_description::well_known::Iso8601;
use time::OffsetDateTime;

pub async fn move_to_trash(path: &Path) -> io::Result<PathBuf> {
    let data_home = dirs::data_dir()
        .ok_or_else(|| io::Error::new(io::ErrorKind::NotFound, "XDG data dir not found"))?;
    move_to_trash_in(path, &data_home).await
}

pub async fn move_to_trash_in(path: &Path, data_home: &Path) -> io::Result<PathBuf> {
    let files_dir = data_home.join("Trash").join("files");
    let info_dir = data_home.join("Trash").join("info");
    tokio::fs::create_dir_all(&files_dir).await?;
    tokio::fs::create_dir_all(&info_dir).await?;

    let original_name = path
        .file_name()
        .and_then(|n| n.to_str())
        .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidInput, "path has no file name"))?
        .to_string();

    let trash_name = unique_trash_name(&files_dir, &original_name);
    let trashed_path = files_dir.join(&trash_name);
    let info_path = info_dir.join(format!("{trash_name}.trashinfo"));

    let absolute_path = if path.is_absolute() {
        path.to_path_buf()
    } else {
        std::env::current_dir()?.join(path)
    };

    tokio::fs::write(&info_path, trash_info_contents(&absolute_path)?).await?;
    tokio::fs::rename(path, &trashed_path).await?;

    Ok(trashed_path)
}

fn unique_trash_name(files_dir: &Path, original_name: &str) -> String {
    let path = Path::new(original_name);
    let stem = path
        .file_stem()
        .and_then(|s| s.to_str())
        .unwrap_or(original_name);
    let ext = path.extension().and_then(|s| s.to_str());

    let mut candidate = original_name.to_string();
    let mut counter = 1;
    while files_dir.join(&candidate).exists() {
        candidate = match ext {
            Some(ext) => format!("{stem}_{counter}.{ext}"),
            None => format!("{stem}_{counter}"),
        };
        counter += 1;
    }
    candidate
}

fn trash_info_contents(original_path: &Path) -> io::Result<String> {
    let deletion_date = OffsetDateTime::now_utc()
        .format(&Iso8601::DEFAULT)
        .map_err(|e| io::Error::new(io::ErrorKind::Other, e.to_string()))?;
    Ok(format!(
        "[Trash Info]\nPath={}\nDeletionDate={}\n",
        original_path.display(),
        deletion_date
    ))
}
```

`crates/core/src/lib.rs`:
```rust
pub mod entry;
pub mod listing;
pub mod mime;
pub mod ops;
pub mod trash;

pub use entry::FileEntry;
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cargo test -p fm-core --test trash`
Expected: PASS (2 tests)

- [ ] **Step 6: Commit**

```bash
git add crates/core/Cargo.toml crates/core/src/lib.rs crates/core/src/trash.rs crates/core/tests/trash.rs
git commit -m "feat(core): add freedesktop.org Trash spec implementation"
```

---

### Task 8: Live filesystem watcher

**Files:**
- Create: `crates/core/src/watcher.rs`
- Modify: `crates/core/Cargo.toml`
- Modify: `crates/core/src/lib.rs`
- Test: `crates/core/tests/watcher.rs`

**Interfaces:**
- Consumes: nothing new.
- Produces: `fm_core::watcher::WatchEvent` enum (`Created(PathBuf)`, `Removed(PathBuf)`, `Modified(PathBuf)`, `Renamed { from: PathBuf, to: PathBuf }`), `fm_core::watcher::DirWatcher::new(path: &Path, tx: tokio::sync::mpsc::UnboundedSender<WatchEvent>) -> notify::Result<DirWatcher>`. Plan 2's bridge holds a `DirWatcher` per active directory and forwards `WatchEvent`s into the QML-facing model.

- [ ] **Step 1: Add the notify dependency**

`crates/core/Cargo.toml` — add under `[dependencies]`:
```toml
notify = "6"
```

- [ ] **Step 2: Write the failing test**

`crates/core/tests/watcher.rs`:
```rust
use fm_core::watcher::{DirWatcher, WatchEvent};
use std::fs;
use tempfile::tempdir;
use tokio::sync::mpsc;
use tokio::time::{timeout, Duration};

#[tokio::test]
async fn emits_created_event_for_new_file() {
    let dir = tempdir().unwrap();
    let (tx, mut rx) = mpsc::unbounded_channel();
    let _watcher = DirWatcher::new(dir.path(), tx).unwrap();

    let file_path = dir.path().join("new.txt");
    fs::write(&file_path, b"hi").unwrap();

    let event = timeout(Duration::from_secs(5), rx.recv())
        .await
        .expect("timed out waiting for a watch event")
        .expect("channel closed unexpectedly");

    assert_eq!(event, WatchEvent::Created(file_path));
}

#[tokio::test]
async fn emits_removed_event_for_deleted_file() {
    let dir = tempdir().unwrap();
    let file_path = dir.path().join("doomed.txt");
    fs::write(&file_path, b"bye").unwrap();

    let (tx, mut rx) = mpsc::unbounded_channel();
    let _watcher = DirWatcher::new(dir.path(), tx).unwrap();

    fs::remove_file(&file_path).unwrap();

    let mut saw_removed = false;
    for _ in 0..10 {
        let event = timeout(Duration::from_secs(5), rx.recv())
            .await
            .expect("timed out waiting for a watch event")
            .expect("channel closed unexpectedly");
        if event == WatchEvent::Removed(file_path.clone()) {
            saw_removed = true;
            break;
        }
    }
    assert!(saw_removed, "expected a Removed event for the deleted file");
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cargo test -p fm-core --test watcher`
Expected: FAIL to compile — `fm_core::watcher` does not exist yet.

- [ ] **Step 4: Write minimal implementation**

`crates/core/src/watcher.rs`:
```rust
use notify::{Event, EventKind, RecommendedWatcher, RecursiveMode, Watcher};
use std::path::{Path, PathBuf};
use tokio::sync::mpsc;

#[derive(Debug, Clone, PartialEq)]
pub enum WatchEvent {
    Created(PathBuf),
    Removed(PathBuf),
    Modified(PathBuf),
    Renamed { from: PathBuf, to: PathBuf },
}

pub struct DirWatcher {
    _watcher: RecommendedWatcher,
}

impl DirWatcher {
    pub fn new(path: &Path, tx: mpsc::UnboundedSender<WatchEvent>) -> notify::Result<Self> {
        let mut watcher = notify::recommended_watcher(move |result: notify::Result<Event>| {
            let Ok(event) = result else { return };
            for mapped in map_event(event) {
                let _ = tx.send(mapped);
            }
        })?;
        watcher.watch(path, RecursiveMode::NonRecursive)?;
        Ok(Self { _watcher: watcher })
    }
}

fn map_event(event: Event) -> Vec<WatchEvent> {
    match event.kind {
        EventKind::Create(_) => event.paths.into_iter().map(WatchEvent::Created).collect(),
        EventKind::Remove(_) => event.paths.into_iter().map(WatchEvent::Removed).collect(),
        EventKind::Modify(notify::event::ModifyKind::Name(notify::event::RenameMode::Both)) => {
            if event.paths.len() == 2 {
                vec![WatchEvent::Renamed {
                    from: event.paths[0].clone(),
                    to: event.paths[1].clone(),
                }]
            } else {
                vec![]
            }
        }
        EventKind::Modify(_) => event.paths.into_iter().map(WatchEvent::Modified).collect(),
        _ => vec![],
    }
}
```

`crates/core/src/lib.rs`:
```rust
pub mod entry;
pub mod listing;
pub mod mime;
pub mod ops;
pub mod trash;
pub mod watcher;

pub use entry::FileEntry;
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cargo test -p fm-core --test watcher`
Expected: PASS (2 tests)

- [ ] **Step 6: Run the full crate test suite**

Run: `cargo test -p fm-core`
Expected: PASS (all tests across entry, mime, listing, ops, trash, watcher)

- [ ] **Step 7: Commit**

```bash
git add crates/core/Cargo.toml crates/core/src/lib.rs crates/core/src/watcher.rs crates/core/tests/watcher.rs
git commit -m "feat(core): add live filesystem watcher"
```

---

## Plan Complete

At this point `fm-core` provides everything the spec's section 2 (Rust backend) calls for: the `FileEntry` model, mime detection, streaming directory listing, create/rename/copy/move operations, freedesktop Trash, and live watching — all covered by `cargo test -p fm-core`. Plan 2 will add `crates/app`, a cxx-qt bridge crate depending on `fm-core`, and a minimal unstyled QML shell to prove the whole stack wires together end to end. Plan 3 will then layer the Material 3 Expressive design system on top.
