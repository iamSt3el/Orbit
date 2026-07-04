# Restore From Trash Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user restore a trashed item back to its original location, or permanently delete an individual trashed item, both from a trash-aware per-item context menu — single item and multi-selection for both.

**Architecture:** Two new `fm-core::trash` functions (`restore`, `delete_permanently`) with real integration tests. Four new cxx-qt invokables on `FileListModel`, each mirroring an existing invokable's exact shape (`deleteEntry`/`deleteSelection`). `ItemContextMenu.qml` grows a trash-aware menu variant. `main.qml` wires it up, including a new confirm dialog for the irreversible permanent-delete action, matching the existing Delete-to-Trash confirm dialog pattern exactly.

**Tech Stack:** Rust (tokio async fs, `tempfile` for tests), cxx-qt 0.9, QML/Qt Quick.

## Global Constraints

- Full spec: `docs/superpowers/specs/2026-07-04-restore-from-trash-design.md` — read it if anything below is ambiguous.
- **Out of scope**: the background right-click menu (`ContextMenu.qml`) is unchanged even when browsing Trash. Only the per-item menu (`ItemContextMenu.qml`) becomes trash-aware.
- **Restore conflict handling**: auto-rename with a `"(restored)"` / `"(restored 2)"` / ... suffix (mirrors `unique_paste_destination`'s `"(copy)"` pattern, just a different word) — not a real conflict-resolution prompt (that's separate, already-tracked future work).
- **Error messages** (exact strings, reusing the `errorOccurred` signal/Snackbar infrastructure already in this codebase):
  - `Couldn't restore "{name}": {e}`
  - `Couldn't permanently delete "{name}": {e}`
  - Batch (via the existing `pluralize_items` helper): `Couldn't restore {N} items`, `Couldn't permanently delete {N} items`
- **Busy labels** for the two batch invokables: `"Restoring…"`, `"Deleting Permanently…"`.
- **Restore has no confirmation dialog** (not destructive). **Delete Permanently does** — mirrors the existing Delete-to-Trash `ConfirmDialog` pattern exactly, including its own pending-state properties and its own Loader, added to the existing `anyPopupOpen` guard list.
- **Verification ceiling**: `cargo build -p fm-app` (~2 minutes per run, normal for this crate) plus, for the first time, real `cargo test -p fm-core` content. No QML test harness exists; interactive verification is done by the user themselves.

---

### Task 1: `fm-core::trash::restore` and `delete_permanently`

**Files:**
- Modify: `crates/core/src/trash.rs`

**Interfaces:**
- Produces: `pub async fn restore(trashed_path: &Path) -> io::Result<PathBuf>`, `pub async fn restore_in(trashed_path: &Path, data_home: &Path) -> io::Result<PathBuf>`
- Produces: `pub async fn delete_permanently(trashed_path: &Path) -> io::Result<()>`, `pub async fn delete_permanently_in(trashed_path: &Path, data_home: &Path) -> io::Result<()>`
- Consumes: nothing new — reuses this file's existing `move_to_trash_in` in its own tests.

- [ ] **Step 1: Write the failing tests**

Append to the end of `crates/core/src/trash.rs`:

```rust

#[cfg(test)]
mod restore_tests {
    use super::*;

    #[tokio::test]
    async fn restores_a_trashed_file_to_its_original_location() {
        let data_home = tempfile::tempdir().unwrap();
        let original_dir = tempfile::tempdir().unwrap();
        let original_path = original_dir.path().join("note.txt");
        tokio::fs::write(&original_path, b"hello").await.unwrap();

        let trashed_path = move_to_trash_in(&original_path, data_home.path()).await.unwrap();
        assert!(!original_path.exists());

        let restored_path = restore_in(&trashed_path, data_home.path()).await.unwrap();

        assert_eq!(restored_path, original_path);
        assert!(restored_path.exists());
        assert_eq!(
            tokio::fs::read_to_string(&restored_path).await.unwrap(),
            "hello"
        );
        assert!(!trashed_path.exists());
        let info_path = data_home
            .path()
            .join("Trash")
            .join("info")
            .join(format!(
                "{}.trashinfo",
                trashed_path.file_name().unwrap().to_str().unwrap()
            ));
        assert!(!info_path.exists());
    }

    #[tokio::test]
    async fn recreates_a_missing_parent_directory_on_restore() {
        let data_home = tempfile::tempdir().unwrap();
        let original_dir = tempfile::tempdir().unwrap();
        let nested_dir = original_dir.path().join("subfolder");
        tokio::fs::create_dir_all(&nested_dir).await.unwrap();
        let original_path = nested_dir.join("note.txt");
        tokio::fs::write(&original_path, b"hello").await.unwrap();

        let trashed_path = move_to_trash_in(&original_path, data_home.path()).await.unwrap();
        tokio::fs::remove_dir_all(&nested_dir).await.unwrap();

        let restored_path = restore_in(&trashed_path, data_home.path()).await.unwrap();

        assert_eq!(restored_path, original_path);
        assert!(restored_path.exists());
    }

    #[tokio::test]
    async fn auto_renames_on_conflict_at_the_original_location() {
        let data_home = tempfile::tempdir().unwrap();
        let original_dir = tempfile::tempdir().unwrap();
        let original_path = original_dir.path().join("note.txt");
        tokio::fs::write(&original_path, b"first").await.unwrap();

        let trashed_path = move_to_trash_in(&original_path, data_home.path()).await.unwrap();
        tokio::fs::write(&original_path, b"second").await.unwrap();

        let restored_path = restore_in(&trashed_path, data_home.path()).await.unwrap();

        assert_eq!(restored_path, original_dir.path().join("note (restored).txt"));
        assert_eq!(
            tokio::fs::read_to_string(&original_path).await.unwrap(),
            "second"
        );
        assert_eq!(
            tokio::fs::read_to_string(&restored_path).await.unwrap(),
            "first"
        );
    }

    #[tokio::test]
    async fn errors_when_the_trashinfo_file_is_missing() {
        let data_home = tempfile::tempdir().unwrap();
        let files_dir = data_home.path().join("Trash").join("files");
        tokio::fs::create_dir_all(&files_dir).await.unwrap();
        let phantom_path = files_dir.join("ghost.txt");
        tokio::fs::write(&phantom_path, b"boo").await.unwrap();

        let result = restore_in(&phantom_path, data_home.path()).await;

        assert!(result.is_err());
    }
}

#[cfg(test)]
mod delete_permanently_tests {
    use super::*;

    #[tokio::test]
    async fn permanently_deletes_a_trashed_file_and_its_info() {
        let data_home = tempfile::tempdir().unwrap();
        let original_dir = tempfile::tempdir().unwrap();
        let original_path = original_dir.path().join("note.txt");
        tokio::fs::write(&original_path, b"hello").await.unwrap();

        let trashed_path = move_to_trash_in(&original_path, data_home.path()).await.unwrap();
        let info_path = data_home
            .path()
            .join("Trash")
            .join("info")
            .join(format!(
                "{}.trashinfo",
                trashed_path.file_name().unwrap().to_str().unwrap()
            ));
        assert!(info_path.exists());

        delete_permanently_in(&trashed_path, data_home.path()).await.unwrap();

        assert!(!trashed_path.exists());
        assert!(!info_path.exists());
    }

    #[tokio::test]
    async fn permanently_deletes_a_trashed_directory_recursively() {
        let data_home = tempfile::tempdir().unwrap();
        let original_dir = tempfile::tempdir().unwrap();
        let folder_path = original_dir.path().join("stuff");
        tokio::fs::create_dir_all(&folder_path).await.unwrap();
        tokio::fs::write(folder_path.join("inner.txt"), b"hi").await.unwrap();

        let trashed_path = move_to_trash_in(&folder_path, data_home.path()).await.unwrap();
        assert!(trashed_path.is_dir());

        delete_permanently_in(&trashed_path, data_home.path()).await.unwrap();

        assert!(!trashed_path.exists());
    }

    #[tokio::test]
    async fn permanent_delete_succeeds_even_if_trashinfo_already_missing() {
        let data_home = tempfile::tempdir().unwrap();
        let files_dir = data_home.path().join("Trash").join("files");
        tokio::fs::create_dir_all(&files_dir).await.unwrap();
        let phantom_path = files_dir.join("ghost.txt");
        tokio::fs::write(&phantom_path, b"boo").await.unwrap();

        let result = delete_permanently_in(&phantom_path, data_home.path()).await;

        assert!(result.is_ok());
        assert!(!phantom_path.exists());
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cargo test -p fm-core`
Expected: FAIL to compile — `cannot find function 'restore_in' in this scope` (and `delete_permanently_in`).

- [ ] **Step 3: Implement `restore`/`restore_in` and their private helpers**

Add these functions to `crates/core/src/trash.rs`, anywhere before the `#[cfg(test)]` modules (e.g. right after the existing `empty_trash_in` function):

```rust

pub async fn restore(trashed_path: &Path) -> io::Result<PathBuf> {
    let data_home = dirs::data_dir()
        .ok_or_else(|| io::Error::new(io::ErrorKind::NotFound, "XDG data dir not found"))?;
    restore_in(trashed_path, &data_home).await
}

pub async fn restore_in(trashed_path: &Path, data_home: &Path) -> io::Result<PathBuf> {
    let info_dir = data_home.join("Trash").join("info");
    let trash_name = trashed_path
        .file_name()
        .and_then(|n| n.to_str())
        .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidInput, "path has no file name"))?;
    let info_path = info_dir.join(format!("{trash_name}.trashinfo"));

    let info_contents = tokio::fs::read_to_string(&info_path).await?;
    let original_path = parse_trashinfo_path(&info_contents)?;

    if let Some(parent) = original_path.parent() {
        tokio::fs::create_dir_all(parent).await?;
    }
    let destination = unique_restore_destination(&original_path);

    tokio::fs::rename(trashed_path, &destination).await?;
    tokio::fs::remove_file(&info_path).await?;

    Ok(destination)
}

fn parse_trashinfo_path(contents: &str) -> io::Result<PathBuf> {
    contents
        .lines()
        .find_map(|line| line.strip_prefix("Path="))
        .map(PathBuf::from)
        .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidData, "trashinfo missing Path="))
}

fn unique_restore_destination(original: &Path) -> PathBuf {
    if !original.exists() {
        return original.to_path_buf();
    }
    let parent = original.parent().unwrap_or_else(|| Path::new(""));
    let stem = original
        .file_stem()
        .and_then(|s| s.to_str())
        .unwrap_or_default();
    let ext = original.extension().and_then(|s| s.to_str());

    let mut candidate = match ext {
        Some(ext) => parent.join(format!("{stem} (restored).{ext}")),
        None => parent.join(format!("{stem} (restored)")),
    };
    let mut n = 2;
    while candidate.exists() {
        candidate = match ext {
            Some(ext) => parent.join(format!("{stem} (restored {n}).{ext}")),
            None => parent.join(format!("{stem} (restored {n})")),
        };
        n += 1;
    }
    candidate
}
```

- [ ] **Step 4: Implement `delete_permanently`/`delete_permanently_in`**

Add right after the functions from Step 3:

```rust

pub async fn delete_permanently(trashed_path: &Path) -> io::Result<()> {
    let data_home = dirs::data_dir()
        .ok_or_else(|| io::Error::new(io::ErrorKind::NotFound, "XDG data dir not found"))?;
    delete_permanently_in(trashed_path, &data_home).await
}

pub async fn delete_permanently_in(trashed_path: &Path, data_home: &Path) -> io::Result<()> {
    let info_dir = data_home.join("Trash").join("info");
    let trash_name = trashed_path
        .file_name()
        .and_then(|n| n.to_str())
        .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidInput, "path has no file name"))?;
    let info_path = info_dir.join(format!("{trash_name}.trashinfo"));

    if tokio::fs::metadata(trashed_path).await?.is_dir() {
        tokio::fs::remove_dir_all(trashed_path).await?;
    } else {
        tokio::fs::remove_file(trashed_path).await?;
    }
    let _ = tokio::fs::remove_file(&info_path).await;
    Ok(())
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `cargo test -p fm-core`
Expected: `test result: ok. 7 passed; 0 failed` (the 7 new tests — this crate had zero tests before this task).

- [ ] **Step 6: Commit**

```bash
git add crates/core/src/trash.rs
git commit -m "feat(core): add trash restore and delete_permanently"
```

---

### Task 2: `FileListModel` invokables

**Files:**
- Modify: `crates/app/src/file_list_model.rs`

**Interfaces:**
- Consumes: `fm_core::trash::restore(path) -> io::Result<PathBuf>`, `fm_core::trash::delete_permanently(path) -> io::Result<()>` (Task 1); `pluralize_items(count: usize) -> String` and `self.as_mut().error_occurred(QString)` (both already exist in this file from the error-surfacing feature).
- Produces: QML-visible `fileModel.restoreEntry(name)`, `fileModel.restoreSelection()`, `fileModel.deletePermanentlyEntry(name)`, `fileModel.deletePermanentlySelection()`.

- [ ] **Step 1: Add the four invokable declarations**

Find this block in `crates/app/src/file_list_model.rs`:

```rust
        /// Multi-item counterpart to duplicateEntry — same background-task
        /// pattern as deleteSelection.
        #[qinvokable]
        #[cxx_name = "duplicateSelection"]
        fn duplicate_selection(self: Pin<&mut FileListModel>);
```

Immediately after it (still inside the same `unsafe extern "RustQt"` block), add:

```rust

        #[qinvokable]
        #[cxx_name = "restoreEntry"]
        fn restore_entry(self: Pin<&mut FileListModel>, name: &QString);

        /// Multi-item counterpart to restoreEntry — same background-task
        /// pattern as deleteSelection.
        #[qinvokable]
        #[cxx_name = "restoreSelection"]
        fn restore_selection(self: Pin<&mut FileListModel>);

        #[qinvokable]
        #[cxx_name = "deletePermanentlyEntry"]
        fn delete_permanently_entry(self: Pin<&mut FileListModel>, name: &QString);

        /// Multi-item counterpart to deletePermanentlyEntry — same
        /// background-task pattern as deleteSelection.
        #[qinvokable]
        #[cxx_name = "deletePermanentlySelection"]
        fn delete_permanently_selection(self: Pin<&mut FileListModel>);
```

- [ ] **Step 2: Implement the four methods**

Find `duplicate_selection`'s implementation (it ends with this exact closing block):

```rust
            let _ = qt_thread.queue(move |mut model| {
                model.as_mut().set_is_busy(false);
                model.as_mut().refresh_entries_diff();
                if failed > 0 {
                    model.as_mut().error_occurred(QString::from(&format!(
                        "Couldn't duplicate {}",
                        pluralize_items(failed)
                    )));
                }
            });
        });
    }
```

Immediately after that closing `}` (which ends `duplicate_selection`), add:

```rust

    fn restore_entry(mut self: core::pin::Pin<&mut Self>, name: &QString) {
        let current = PathBuf::from(self.current_path.to_string());
        let target = current.join(name.to_string());
        if let Err(e) = runtime().block_on(fm_core::trash::restore(&target)) {
            eprintln!("restore_entry failed: {e}");
            self.as_mut().error_occurred(QString::from(&format!(
                "Couldn't restore \"{}\": {e}",
                name.to_string()
            )));
        }
        self.as_mut().refresh_entries_diff();
    }

    fn restore_selection(mut self: core::pin::Pin<&mut Self>) {
        let current = PathBuf::from(self.current_path.to_string());
        let targets: Vec<PathBuf> = self.selected.iter().map(|name| current.join(name)).collect();
        if targets.is_empty() {
            return;
        }

        self.as_mut().set_is_busy(true);
        self.as_mut().set_busy_label(QString::from("Restoring…"));

        let qt_thread = self.qt_thread();
        runtime().spawn(async move {
            let mut failed: usize = 0;
            for target in targets {
                if let Err(e) = fm_core::trash::restore(&target).await {
                    eprintln!("restore_selection failed for {}: {e}", target.display());
                    failed += 1;
                }
            }
            let _ = qt_thread.queue(move |mut model| {
                model.as_mut().set_is_busy(false);
                model.as_mut().refresh_entries_diff();
                if failed > 0 {
                    model.as_mut().error_occurred(QString::from(&format!(
                        "Couldn't restore {}",
                        pluralize_items(failed)
                    )));
                }
            });
        });
    }

    fn delete_permanently_entry(mut self: core::pin::Pin<&mut Self>, name: &QString) {
        let current = PathBuf::from(self.current_path.to_string());
        let target = current.join(name.to_string());
        if let Err(e) = runtime().block_on(fm_core::trash::delete_permanently(&target)) {
            eprintln!("delete_permanently_entry failed: {e}");
            self.as_mut().error_occurred(QString::from(&format!(
                "Couldn't permanently delete \"{}\": {e}",
                name.to_string()
            )));
        }
        self.as_mut().refresh_entries_diff();
    }

    fn delete_permanently_selection(mut self: core::pin::Pin<&mut Self>) {
        let current = PathBuf::from(self.current_path.to_string());
        let targets: Vec<PathBuf> = self.selected.iter().map(|name| current.join(name)).collect();
        if targets.is_empty() {
            return;
        }

        self.as_mut().set_is_busy(true);
        self.as_mut().set_busy_label(QString::from("Deleting Permanently…"));

        let qt_thread = self.qt_thread();
        runtime().spawn(async move {
            let mut failed: usize = 0;
            for target in targets {
                if let Err(e) = fm_core::trash::delete_permanently(&target).await {
                    eprintln!(
                        "delete_permanently_selection failed for {}: {e}",
                        target.display()
                    );
                    failed += 1;
                }
            }
            let _ = qt_thread.queue(move |mut model| {
                model.as_mut().set_is_busy(false);
                model.as_mut().refresh_entries_diff();
                if failed > 0 {
                    model.as_mut().error_occurred(QString::from(&format!(
                        "Couldn't permanently delete {}",
                        pluralize_items(failed)
                    )));
                }
            });
        });
    }
```

- [ ] **Step 3: Build to verify**

Run: `cargo build -p fm-app`
Expected: `Finished` with no errors. (These four methods aren't unit-testable in isolation — same reasoning as every other invokable in this file: they're QObject methods requiring the cxx-qt/Qt runtime. A clean build is this task's verification.)

- [ ] **Step 4: Commit**

```bash
git add crates/app/src/file_list_model.rs
git commit -m "feat(app): add restore and deletePermanently invokables"
```

---

### Task 3: Trash-aware `ItemContextMenu.qml`

**Files:**
- Modify: `crates/app/qml/components/ItemContextMenu.qml`

**Interfaces:**
- Produces: new property `isTrashView: bool` (set via an extra `popup(...)` argument), new signals `restoreRequested(string name)` and `deletePermanentlyRequested(string name)`.
- Consumes: nothing from Task 1/2 directly — this task only changes what the menu displays and which signals it emits; `main.qml` (Task 4) connects those signals to the invokables from Task 2.

- [ ] **Step 1: Add the `isTrashView` property and two new signals**

Replace:

```qml
    // How many items are selected at the moment this menu was popped up —
    // if more than 1, the menu shows only the actions that make sense in
    // bulk (Cut/Copy/Duplicate/Delete) instead of the full single-item menu.
    property int selectionCount: 1

    signal openRequested(string name)
    signal renameRequested(string name)
    signal duplicateRequested(string name)
    signal copyPathRequested(string name)
    signal copyRequested(string name)
    signal cutRequested(string name)
    signal deleteRequested(string name)
    signal propertiesRequested(string name, bool isDir, real size, string modified, string mimeType, string permissions)
```

with:

```qml
    // How many items are selected at the moment this menu was popped up —
    // if more than 1, the menu shows only the actions that make sense in
    // bulk (Cut/Copy/Duplicate/Delete) instead of the full single-item menu.
    property int selectionCount: 1
    // True while browsing the Trash folder — swaps the whole menu for a
    // Restore/Delete Permanently pair instead of the generic file menu,
    // none of which (Rename/Cut/Copy/Duplicate/Properties) make sense for
    // an already-trashed item.
    property bool isTrashView: false

    signal openRequested(string name)
    signal renameRequested(string name)
    signal duplicateRequested(string name)
    signal copyPathRequested(string name)
    signal copyRequested(string name)
    signal cutRequested(string name)
    signal deleteRequested(string name)
    signal restoreRequested(string name)
    signal deletePermanentlyRequested(string name)
    signal propertiesRequested(string name, bool isDir, real size, string modified, string mimeType, string permissions)
```

- [ ] **Step 2: Branch `_items` on `isTrashView`**

Replace:

```qml
    readonly property var _items: root.selectionCount > 1
        ? [
            { icon: "content_cut", label: "Cut " + root.selectionCount + " items", action: "cut" },
            { icon: "content_copy", label: "Copy " + root.selectionCount + " items", action: "copy" },
            { icon: "file_copy", label: "Duplicate " + root.selectionCount + " items", action: "duplicate" },
            { icon: "delete", label: "Delete " + root.selectionCount + " items", action: "delete", destructive: true }
        ]
        : [
            { icon: "open_in_new", label: "Open", action: "open" },
            { icon: "content_cut", label: "Cut", action: "cut" },
            { icon: "content_copy", label: "Copy", action: "copy" },
            { icon: "edit", label: "Rename", action: "rename" },
            { icon: "file_copy", label: "Duplicate", action: "duplicate" },
            { icon: "link", label: "Copy Path", action: "copyPath" },
            { icon: "delete", label: "Delete", action: "delete", destructive: true },
            { icon: "info", label: "Properties", action: "properties" }
        ]
```

with:

```qml
    readonly property var _items: root.isTrashView
        ? (root.selectionCount > 1
            ? [
                { icon: "restore_from_trash", label: "Restore " + root.selectionCount + " items", action: "restore" },
                { icon: "delete_forever", label: "Delete " + root.selectionCount + " items Permanently", action: "deletePermanently", destructive: true }
            ]
            : [
                { icon: "restore_from_trash", label: "Restore", action: "restore" },
                { icon: "delete_forever", label: "Delete Permanently", action: "deletePermanently", destructive: true }
            ])
        : root.selectionCount > 1
        ? [
            { icon: "content_cut", label: "Cut " + root.selectionCount + " items", action: "cut" },
            { icon: "content_copy", label: "Copy " + root.selectionCount + " items", action: "copy" },
            { icon: "file_copy", label: "Duplicate " + root.selectionCount + " items", action: "duplicate" },
            { icon: "delete", label: "Delete " + root.selectionCount + " items", action: "delete", destructive: true }
        ]
        : [
            { icon: "open_in_new", label: "Open", action: "open" },
            { icon: "content_cut", label: "Cut", action: "cut" },
            { icon: "content_copy", label: "Copy", action: "copy" },
            { icon: "edit", label: "Rename", action: "rename" },
            { icon: "file_copy", label: "Duplicate", action: "duplicate" },
            { icon: "link", label: "Copy Path", action: "copyPath" },
            { icon: "delete", label: "Delete", action: "delete", destructive: true },
            { icon: "info", label: "Properties", action: "properties" }
        ]
```

- [ ] **Step 3: Accept `isTrashView` in `popup(...)`**

Replace:

```qml
    function popup(x, y, name, isDir, size, modified, mimeType, permissions, selectionCount) {
        root.entryName = name
        root.entryIsDir = isDir
        root.entrySize = size
        root.entryModified = modified
        root.entryMimeType = mimeType
        root.entryPermissions = permissions
        root.selectionCount = selectionCount
        menu.x = Math.min(x, root.width - menu.width)
        menu.y = Math.min(y, root.height - menu.height)
        visible = true
        root.forceActiveFocus()
    }
```

with:

```qml
    function popup(x, y, name, isDir, size, modified, mimeType, permissions, selectionCount, isTrashView) {
        root.entryName = name
        root.entryIsDir = isDir
        root.entrySize = size
        root.entryModified = modified
        root.entryMimeType = mimeType
        root.entryPermissions = permissions
        root.selectionCount = selectionCount
        root.isTrashView = isTrashView
        menu.x = Math.min(x, root.width - menu.width)
        menu.y = Math.min(y, root.height - menu.height)
        visible = true
        root.forceActiveFocus()
    }
```

- [ ] **Step 4: Emit the two new signals from the menu item click handler**

Replace:

```qml
                        onClicked: {
                            root.close()
                            switch (menuItem.modelData.action) {
                            case "open": root.openRequested(root.entryName); break
                            case "cut": root.cutRequested(root.entryName); break
                            case "copy": root.copyRequested(root.entryName); break
                            case "rename": root.renameRequested(root.entryName); break
                            case "duplicate": root.duplicateRequested(root.entryName); break
                            case "copyPath": root.copyPathRequested(root.entryName); break
                            case "delete": root.deleteRequested(root.entryName); break
                            case "properties":
                                root.propertiesRequested(root.entryName, root.entryIsDir, root.entrySize, root.entryModified, root.entryMimeType, root.entryPermissions)
                                break
                            }
                        }
```

with:

```qml
                        onClicked: {
                            root.close()
                            switch (menuItem.modelData.action) {
                            case "open": root.openRequested(root.entryName); break
                            case "cut": root.cutRequested(root.entryName); break
                            case "copy": root.copyRequested(root.entryName); break
                            case "rename": root.renameRequested(root.entryName); break
                            case "duplicate": root.duplicateRequested(root.entryName); break
                            case "copyPath": root.copyPathRequested(root.entryName); break
                            case "delete": root.deleteRequested(root.entryName); break
                            case "restore": root.restoreRequested(root.entryName); break
                            case "deletePermanently": root.deletePermanentlyRequested(root.entryName); break
                            case "properties":
                                root.propertiesRequested(root.entryName, root.entryIsDir, root.entrySize, root.entryModified, root.entryMimeType, root.entryPermissions)
                                break
                            }
                        }
```

- [ ] **Step 5: Build to verify**

Run: `cargo build -p fm-app`
Expected: `Finished` with no errors.

- [ ] **Step 6: Commit**

```bash
git add crates/app/qml/components/ItemContextMenu.qml
git commit -m "feat(app): trash-aware ItemContextMenu (Restore/Delete Permanently)"
```

---

### Task 4: Wire it all up in `main.qml`

**Files:**
- Modify: `crates/app/qml/main.qml`

**Interfaces:**
- Consumes: `fileModel.restoreEntry(name)`, `fileModel.restoreSelection()`, `fileModel.deletePermanentlyEntry(name)`, `fileModel.deletePermanentlySelection()` (Task 2); `ItemContextMenu`'s new `isTrashView` popup argument and `restoreRequested`/`deletePermanentlyRequested` signals (Task 3).

- [ ] **Step 1: Add pending-state properties for the new confirm dialog**

Replace:

```qml
    property string _pendingDeleteName: ""
    property bool _pendingDeleteIsSelection: false
```

with:

```qml
    property string _pendingDeleteName: ""
    property bool _pendingDeleteIsSelection: false
    property string _pendingDeletePermanentlyName: ""
    property bool _pendingDeletePermanentlyIsSelection: false
```

- [ ] **Step 2: Pass `isTrashView` into the popup call**

Replace:

```qml
    function openItemContextMenu(x, y, name, isDir, size, modified, mimeType, permissions) {
        itemContextMenuLoader.active = true
        itemContextMenuLoader.item.popup(x, y, name, isDir, size, modified, mimeType, permissions, fileModel.selectedCount())
    }
```

with:

```qml
    function openItemContextMenu(x, y, name, isDir, size, modified, mimeType, permissions) {
        itemContextMenuLoader.active = true
        itemContextMenuLoader.item.popup(x, y, name, isDir, size, modified, mimeType, permissions, fileModel.selectedCount(), fileModel.currentPath === fileModel.trashPath)
    }
```

- [ ] **Step 3: Add the two new dialog-opener functions**

Replace:

```qml
    function openDeleteSelectionConfirmDialog(count) {
        window._pendingDeleteIsSelection = true
        deleteConfirmDialogLoader.active = true
        deleteConfirmDialogLoader.item.open("Move " + count + " items to Trash?")
    }
```

with:

```qml
    function openDeleteSelectionConfirmDialog(count) {
        window._pendingDeleteIsSelection = true
        deleteConfirmDialogLoader.active = true
        deleteConfirmDialogLoader.item.open("Move " + count + " items to Trash?")
    }

    function openDeletePermanentlyConfirmDialog(name) {
        window._pendingDeletePermanentlyName = name
        window._pendingDeletePermanentlyIsSelection = false
        deletePermanentlyConfirmDialogLoader.active = true
        deletePermanentlyConfirmDialogLoader.item.open("Permanently delete \"" + name + "\"? This can't be undone.")
    }

    function openDeletePermanentlySelectionConfirmDialog(count) {
        window._pendingDeletePermanentlyIsSelection = true
        deletePermanentlyConfirmDialogLoader.active = true
        deletePermanentlyConfirmDialogLoader.item.open("Permanently delete " + count + " items? This can't be undone.")
    }
```

- [ ] **Step 4: Add the new loader to `anyPopupOpen`**

Replace:

```qml
    readonly property bool anyPopupOpen:
        contextMenuLoader.active || newFolderDialogLoader.active ||
        viewOptionsMenuLoader.active || itemContextMenuLoader.active ||
        renameDialogLoader.active || propertiesDialogLoader.active ||
        deleteConfirmDialogLoader.active || trashContextMenuLoader.active ||
        emptyTrashConfirmDialogLoader.active || settingsDialogLoader.active
```

with:

```qml
    readonly property bool anyPopupOpen:
        contextMenuLoader.active || newFolderDialogLoader.active ||
        viewOptionsMenuLoader.active || itemContextMenuLoader.active ||
        renameDialogLoader.active || propertiesDialogLoader.active ||
        deleteConfirmDialogLoader.active || trashContextMenuLoader.active ||
        emptyTrashConfirmDialogLoader.active || settingsDialogLoader.active ||
        deletePermanentlyConfirmDialogLoader.active
```

- [ ] **Step 5: Wire the new signals in `itemContextMenuLoader`**

Replace:

```qml
            onDeleteRequested: (name) => {
                if (itemContextMenu.selectionCount > 1) {
                    window.openDeleteSelectionConfirmDialog(itemContextMenu.selectionCount)
                } else {
                    window.openDeleteConfirmDialog(name)
                }
            }
            onPropertiesRequested: (name, isDir, size, modified, mimeType, permissions) =>
                window.openPropertiesDialog(name, isDir, size, modified, mimeType, permissions)
```

with:

```qml
            onDeleteRequested: (name) => {
                if (itemContextMenu.selectionCount > 1) {
                    window.openDeleteSelectionConfirmDialog(itemContextMenu.selectionCount)
                } else {
                    window.openDeleteConfirmDialog(name)
                }
            }
            onRestoreRequested: (name) => {
                if (itemContextMenu.selectionCount > 1) {
                    fileModel.restoreSelection()
                } else {
                    fileModel.restoreEntry(name)
                }
            }
            onDeletePermanentlyRequested: (name) => {
                if (itemContextMenu.selectionCount > 1) {
                    window.openDeletePermanentlySelectionConfirmDialog(itemContextMenu.selectionCount)
                } else {
                    window.openDeletePermanentlyConfirmDialog(name)
                }
            }
            onPropertiesRequested: (name, isDir, size, modified, mimeType, permissions) =>
                window.openPropertiesDialog(name, isDir, size, modified, mimeType, permissions)
```

- [ ] **Step 6: Add the new `deletePermanentlyConfirmDialogLoader`**

Find the existing `deleteConfirmDialogLoader` Loader:

```qml
    Loader {
        id: deleteConfirmDialogLoader
        anchors.fill: parent
        active: false
        sourceComponent: ConfirmDialog {
            title: "Move to Trash"
            confirmLabel: "Delete"
            onConfirmed: {
                if (window._pendingDeleteIsSelection) {
                    fileModel.deleteSelection()
                } else {
                    fileModel.deleteEntry(window._pendingDeleteName)
                }
            }
            onClosed: Qt.callLater(() => deleteConfirmDialogLoader.active = false)
        }
    }
```

Immediately after its closing `}`, add:

```qml

    Loader {
        id: deletePermanentlyConfirmDialogLoader
        anchors.fill: parent
        active: false
        sourceComponent: ConfirmDialog {
            title: "Delete Permanently"
            confirmLabel: "Delete Permanently"
            onConfirmed: {
                if (window._pendingDeletePermanentlyIsSelection) {
                    fileModel.deletePermanentlySelection()
                } else {
                    fileModel.deletePermanentlyEntry(window._pendingDeletePermanentlyName)
                }
            }
            onClosed: Qt.callLater(() => deletePermanentlyConfirmDialogLoader.active = false)
        }
    }
```

- [ ] **Step 7: Build to verify**

Run: `cargo build -p fm-app`
Expected: `Finished` with no errors. Double-check there's no QML warning about an unknown `deletePermanentlyConfirmDialogLoader` id (would indicate a typo between Steps 4 and 6).

- [ ] **Step 8: Commit**

```bash
git add crates/app/qml/main.qml
git commit -m "feat(app): wire restore/delete-permanently into main.qml"
```

- [ ] **Step 9: Hand off for manual verification**

Tell the user this is ready for interactive testing (no QML test harness in this project — don't launch/screenshot the app yourself, per this project's established verification style). Suggest concretely checking:
- Delete a file (moves to Trash), navigate into Trash, right-click it — menu shows only Restore / Delete Permanently.
- Restore it — reappears at its original location, gone from Trash.
- Delete something, then delete/rename its original parent folder, then restore it from Trash — the parent folder is recreated.
- Trash two files with the same name from different folders (or trash one, then create a new file with the same name at the original location), restore the older one — it lands as `"name (restored)"` instead of overwriting.
- Select multiple items in Trash, right-click — menu shows "Restore N items" / "Delete N items Permanently"; try both.
- Permanently delete something — a confirm dialog appears first (title "Delete Permanently"); confirm and it's gone from Trash for good.
- While the Delete Permanently confirm dialog is open, press the Delete/Escape/etc. shortcuts — nothing should happen until it's closed.
- Right-click the background (not an item) while browsing Trash — still shows the normal New Folder/Paste/Select All/Open Terminal menu, unaffected by this feature.
