# Multi-Select Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add multi-item selection (click / Ctrl+click / Shift+click / drag rubber-band / Ctrl+A) to the file list and grid views, and wire it into bulk copy/cut/delete/duplicate.

**Architecture:** Selection state lives in `FileListModelRust` (`crates/app/src/file_list_model.rs`) as a `HashSet<String>` of selected entry names, exposed as a new `selected` model role — the same mechanism every other per-row fact (`name`, `isDir`, ...) already uses. This lets every bulk action (`copySelection`, `cutSelection`, `deleteSelection`, `duplicateSelection`) be an argument-less invokable that reads the selection directly, with no list marshaling across the QML/Rust boundary. QML adds click/drag interactions on top of the existing `FileListItem`/`FileGridItem` delegates and the existing background `MouseArea`s in `main.qml`.

**Tech Stack:** Rust (cxx-qt bridge, `crates/app`), QML/Qt Quick (`crates/app/qml`). No new dependencies.

## Global Constraints

- Selection is scoped to the current folder's listing; `navigate()` always clears it (per the design spec, section 2).
- Selection is pruned automatically whenever the listing refreshes (`apply_entries_diff`) — a name that disappears from the listing can never stay in the selection set (spec section 2).
- No drag-and-drop of items (dragging files onto another row, or out to another app) — this plan is rubber-band *selection* only (spec section 6).
- No auto-scroll while rubber-band-dragging near a view edge — only currently-visible (already-instantiated) delegates are swept (spec section 6).
- No aggregate Properties view for a multi-item selection — Properties is hidden from the context menu once more than one item is selected (spec section 6).
- This project has no automated QML test harness (per the original design spec's testing section) — QML changes are verified by `cargo build -p fm-app` succeeding (qmlcachegen catches syntax/binding errors) plus a manual run where possible. `fm-app` (the cxx-qt bridge crate) itself has no existing `cargo test` suite either — new bridge-only code (roles, invokables, the async paste/delete/duplicate tasks) is verified the same way. The one piece of genuinely pure, Qt-independent logic this plan adds (Shift+click range resolution) *is* unit-tested with `cargo test -p fm-app`, since it needs no QObject/QML context to run.
- **Deviation from the design spec, noted here for the record:** the spec's section 4 mentions `Escape` clearing the selection "at the view level." This plan does not add a global Escape handler for it — several existing dialogs/text fields already have their own `Keys.onEscapePressed` (search field, rename/new-folder dialogs), and the view (`ListView`/`GridView`) doesn't currently hold keyboard focus at all, so wiring Escape safely would mean adding focus management this feature doesn't otherwise need. Clicking empty space already clears the selection (Task 6), which covers the same practical need. `Ctrl+A` for Select All is still implemented (Task 7) via a QML `Shortcut`, which doesn't require the view to hold focus.

---

### Task 1: Selection state + model role

**Files:**
- Modify: `crates/app/src/file_list_model.rs`

**Interfaces:**
- Consumes: nothing new — builds on the existing `FileListModelRust.entries: Vec<fm_core::FileEntry>`, `matching_indices()`, `apply_entries_diff()`, `navigate()`.
- Produces: model role `selected` (bool); invokables `setSelected(name: &QString, selected: bool)`, `selectAll()`, `clearSelection()`, `selectedCount() -> i32`. Task 5 (QML) binds `required property bool selected` to this role and calls `setSelected`/`clearSelection`; Task 7 wires `selectAll()` to Ctrl+A and a menu item.

- [ ] **Step 1: Add the `selected` field and role constant**

In `crates/app/src/file_list_model.rs`, add `SELECTED_ROLE` right after the existing role constants:

```rust
const NAME_ROLE: i32 = 0x0100;
const IS_DIR_ROLE: i32 = 0x0101;
const SIZE_ROLE: i32 = 0x0102;
const ICON_KEY_ROLE: i32 = 0x0103;
const MODIFIED_ROLE: i32 = 0x0104;
const MIME_TYPE_ROLE: i32 = 0x0105;
const PERMISSIONS_ROLE: i32 = 0x0106;
const THUMBNAIL_PATH_ROLE: i32 = 0x0107;
const SELECTED_ROLE: i32 = 0x0108;
```

Add the `selected` field to `FileListModelRust` (right after `clipboard_is_cut: bool,`):

```rust
    clipboard_path: Option<PathBuf>,
    clipboard_is_cut: bool,
    /// Names currently selected in the view (Ctrl/Shift/drag-select) —
    /// scoped to the current folder's listing. Cleared on navigate() and
    /// pruned automatically in apply_entries_diff() whenever a selected
    /// name disappears from the listing.
    selected: std::collections::HashSet<String>,
```

Add `selected: std::collections::HashSet::new(),` to `Default for FileListModelRust`, right after `clipboard_is_cut: false,`.

- [ ] **Step 2: Wire the role into `data()` and `role_names()`**

Replace the `data()` method's `match role { ... }` block to add a `SELECTED_ROLE` arm:

```rust
    fn data(&self, index: &cxx_qt_lib::QModelIndex, role: i32) -> QVariant {
        let row = index.row();
        let matching = matching_indices(&self.entries, &self.search_query.to_string(), self.show_hidden);
        if row < 0 || row as usize >= matching.len() {
            return QVariant::default();
        }
        let entry = &self.entries[matching[row as usize]];
        match role {
            NAME_ROLE => QVariant::from(&QString::from(&entry.name)),
            IS_DIR_ROLE => QVariant::from(&entry.is_dir),
            SIZE_ROLE => QVariant::from(&(entry.size as i64)),
            ICON_KEY_ROLE => QVariant::from(&QString::from(&entry.icon_key)),
            MODIFIED_ROLE => QVariant::from(&QString::from(&format_modified(entry.modified))),
            MIME_TYPE_ROLE => QVariant::from(&QString::from(&entry.mime_type)),
            PERMISSIONS_ROLE => QVariant::from(&QString::from(&entry.permissions)),
            THUMBNAIL_PATH_ROLE => QVariant::from(&QString::from(
                &entry
                    .thumbnail_path
                    .as_ref()
                    .map(|p| format!("file://{}", p.display()))
                    .unwrap_or_default(),
            )),
            SELECTED_ROLE => QVariant::from(&self.selected.contains(&entry.name)),
            _ => QVariant::default(),
        }
    }
```

Replace `role_names()` to also register it:

```rust
    fn role_names(&self) -> QHash<QHashPair_i32_QByteArray> {
        let mut roles = QHash::<QHashPair_i32_QByteArray>::default();
        roles.insert(NAME_ROLE, QByteArray::from("name"));
        roles.insert(IS_DIR_ROLE, QByteArray::from("isDir"));
        roles.insert(SIZE_ROLE, QByteArray::from("size"));
        roles.insert(ICON_KEY_ROLE, QByteArray::from("iconKey"));
        roles.insert(MODIFIED_ROLE, QByteArray::from("modified"));
        roles.insert(MIME_TYPE_ROLE, QByteArray::from("mimeType"));
        roles.insert(PERMISSIONS_ROLE, QByteArray::from("permissions"));
        roles.insert(THUMBNAIL_PATH_ROLE, QByteArray::from("thumbnailPath"));
        roles.insert(SELECTED_ROLE, QByteArray::from("selected"));
        roles
    }
```

- [ ] **Step 3: Declare the new invokables in the bridge module**

In the `#[cxx_qt::bridge] pub mod qobject { ... }` block, add a new `unsafe extern "RustQt"` block right after the one containing `navigate` (i.e. right before the `create_folder`/`rename_entry`/... block). This deliberately does **not** include `selectRange` yet — that one is declared in Task 2, alongside its implementation, so this task builds and is committable entirely on its own:

```rust
    unsafe extern "RustQt" {
        #[qinvokable]
        #[cxx_name = "setSelected"]
        fn set_selected(self: Pin<&mut FileListModel>, name: &QString, selected: bool);

        #[qinvokable]
        #[cxx_name = "selectAll"]
        fn select_all(self: Pin<&mut FileListModel>);

        #[qinvokable]
        #[cxx_name = "clearSelection"]
        fn clear_selection(self: Pin<&mut FileListModel>);

        #[qinvokable]
        #[cxx_name = "selectedCount"]
        fn selected_count(self: &FileListModel) -> i32;
    }
```

(`select_range` is declared here too — it's implemented in Task 2, but declaring all five selection invokables together keeps this block self-contained.)

- [ ] **Step 4: Implement `set_selected`, `select_all`, `clear_selection`, `selected_count`, and a shared row-notify helper**

Add to `impl qobject::FileListModel` (anywhere after `role_names`, e.g. right after it):

```rust
    /// Emits `dataChanged` for the single row matching `name`, if it's
    /// currently visible under the active search/hidden-file filter — used
    /// by `set_selected` so toggling one row's selection doesn't touch any
    /// other row's bindings.
    fn notify_row_for_name(mut self: core::pin::Pin<&mut Self>, name: &str) {
        let Some(idx) = self.entries.iter().position(|e| e.name == name) else {
            return;
        };
        let matching = matching_indices(&self.entries, &self.search_query.to_string(), self.show_hidden);
        let Some(row) = matching.iter().position(|&i| i == idx) else {
            return;
        };
        let parent = cxx_qt_lib::QModelIndex::default();
        let model_index = self.model_index(row as i32, 0, &parent);
        self.as_mut()
            .data_changed(&model_index, &model_index, &cxx_qt_lib::QList::<i32>::default());
    }

    fn set_selected(mut self: core::pin::Pin<&mut Self>, name: &QString, selected: bool) {
        let name = name.to_string();
        let changed = if selected {
            self.as_mut().rust_mut().selected.insert(name.clone())
        } else {
            self.as_mut().rust_mut().selected.remove(&name)
        };
        if changed {
            self.as_mut().notify_row_for_name(&name);
        }
    }

    fn select_all(mut self: core::pin::Pin<&mut Self>) {
        let matching = matching_indices(&self.entries, &self.search_query.to_string(), self.show_hidden);
        let names: std::collections::HashSet<String> =
            matching.iter().map(|&i| self.entries[i].name.clone()).collect();
        self.as_mut().rust_mut().selected = names;
        if matching.is_empty() {
            return;
        }
        let parent = cxx_qt_lib::QModelIndex::default();
        let first = self.model_index(0, 0, &parent);
        let last = self.model_index((matching.len() - 1) as i32, 0, &parent);
        self.as_mut()
            .data_changed(&first, &last, &cxx_qt_lib::QList::<i32>::default());
    }

    fn clear_selection(mut self: core::pin::Pin<&mut Self>) {
        if self.selected.is_empty() {
            return;
        }
        let row_count = self.row_count(&cxx_qt_lib::QModelIndex::default());
        self.as_mut().rust_mut().selected.clear();
        if row_count == 0 {
            return;
        }
        let parent = cxx_qt_lib::QModelIndex::default();
        let first = self.model_index(0, 0, &parent);
        let last = self.model_index(row_count - 1, 0, &parent);
        self.as_mut()
            .data_changed(&first, &last, &cxx_qt_lib::QList::<i32>::default());
    }

    fn selected_count(&self) -> i32 {
        self.selected.len() as i32
    }
```

- [ ] **Step 5: Prune selection on refresh, clear it on navigate**

In `apply_entries_diff`, add pruning right at the top of the function, before the existing `if !self.search_query...` filter-reset branch:

```rust
    fn apply_entries_diff(mut self: core::pin::Pin<&mut Self>, new_entries: Vec<fm_core::FileEntry>) {
        fn same_entry(a: &fm_core::FileEntry, b: &fm_core::FileEntry) -> bool {
            a.name == b.name && a.is_dir == b.is_dir
        }

        // A selected name that no longer exists in the fresh listing (it
        // was deleted, renamed, or moved elsewhere) can't stay selected.
        let new_names: std::collections::HashSet<String> =
            new_entries.iter().map(|e| e.name.clone()).collect();
        self.as_mut()
            .rust_mut()
            .selected
            .retain(|name| new_names.contains(name));

        if !self.search_query.to_string().is_empty() || !self.show_hidden {
```

(The rest of `apply_entries_diff` is unchanged — leave everything from `self.as_mut().begin_reset_model();` onward exactly as it is today.)

In `navigate`, clear the selection along with resetting the search query:

```rust
    fn navigate(mut self: core::pin::Pin<&mut Self>, path: &QString) {
        let path_buf = PathBuf::from(path.to_string());
        let mut entries = runtime().block_on(gather_entries(&path_buf));
        sort_entries(
            &mut entries,
            &self.sort_key.to_string(),
            self.sort_ascending,
        );

        self.as_mut().begin_reset_model();
        self.as_mut().rust_mut().entries = entries;
        // A search filter (and a selection) from the previous directory
        // shouldn't silently carry over into the new one.
        self.as_mut().rust_mut().search_query = QString::from("");
        self.as_mut().rust_mut().selected.clear();
        self.as_mut().end_reset_model();
        self.as_mut()
            .set_current_path(QString::from(&path_buf.display().to_string()));
        self.save_settings();
    }
```

- [ ] **Step 6: Build**

Run: `cargo build -p fm-app`
Expected: builds successfully.

- [ ] **Step 7: Commit**

```bash
git add crates/app/src/file_list_model.rs
git commit -m "feat(app): add selection state and model role"
```

---

### Task 2: Shift+click range resolution (pure, unit-tested)

**Files:**
- Modify: `crates/app/src/file_list_model.rs`

**Interfaces:**
- Consumes: `fm_core::FileEntry` (already defined), `matching_indices()` (Task 1's existing helper, unchanged).
- Produces: `selectRange(fromName: &QString, toName: &QString)` invokable (declared in Task 1, Step 3). Task 5 (QML) calls this on Shift+click, passing the last-clicked "anchor" name and the newly-clicked name.

- [ ] **Step 1: Write the failing tests**

Add near the bottom of `crates/app/src/file_list_model.rs` (after the existing `dir_size` function, so it's clearly a standalone section):

```rust
/// Names of every entry between `from_name` and `to_name` inclusive, in
/// `displayed`'s order (the order the user actually sees, i.e. an
/// already-filtered/sorted slice — not raw `entries`, which may contain
/// hidden/filtered-out names the user never clicked between). Works
/// regardless of which of the two names comes first. Returns an empty Vec
/// if either name isn't found in `displayed`.
fn resolve_range_names(displayed: &[&fm_core::FileEntry], from_name: &str, to_name: &str) -> Vec<String> {
    let Some(from_idx) = displayed.iter().position(|e| e.name == from_name) else {
        return Vec::new();
    };
    let Some(to_idx) = displayed.iter().position(|e| e.name == to_name) else {
        return Vec::new();
    };
    let (start, end) = if from_idx <= to_idx {
        (from_idx, to_idx)
    } else {
        (to_idx, from_idx)
    };
    displayed[start..=end].iter().map(|e| e.name.clone()).collect()
}

#[cfg(test)]
mod selection_range_tests {
    use super::*;
    use std::path::PathBuf;
    use std::time::SystemTime;

    fn entry(name: &str) -> fm_core::FileEntry {
        fm_core::FileEntry {
            name: name.to_string(),
            path: PathBuf::from(name),
            is_dir: false,
            size: 0,
            modified: SystemTime::UNIX_EPOCH,
            mime_type: "text/plain".to_string(),
            icon_key: "text".to_string(),
        }
    }

    #[test]
    fn resolves_a_forward_range_inclusive() {
        let entries = vec![entry("a"), entry("b"), entry("c"), entry("d")];
        let refs: Vec<&fm_core::FileEntry> = entries.iter().collect();
        let names = resolve_range_names(&refs, "b", "d");
        assert_eq!(names, vec!["b".to_string(), "c".to_string(), "d".to_string()]);
    }

    #[test]
    fn resolves_a_reversed_range_the_same_way() {
        let entries = vec![entry("a"), entry("b"), entry("c"), entry("d")];
        let refs: Vec<&fm_core::FileEntry> = entries.iter().collect();
        let names = resolve_range_names(&refs, "d", "b");
        assert_eq!(names, vec!["b".to_string(), "c".to_string(), "d".to_string()]);
    }

    #[test]
    fn a_range_from_a_name_to_itself_is_just_that_one_name() {
        let entries = vec![entry("a"), entry("b")];
        let refs: Vec<&fm_core::FileEntry> = entries.iter().collect();
        let names = resolve_range_names(&refs, "a", "a");
        assert_eq!(names, vec!["a".to_string()]);
    }

    #[test]
    fn an_unknown_name_resolves_to_an_empty_range() {
        let entries = vec![entry("a"), entry("b")];
        let refs: Vec<&fm_core::FileEntry> = entries.iter().collect();
        assert!(resolve_range_names(&refs, "a", "missing").is_empty());
        assert!(resolve_range_names(&refs, "missing", "a").is_empty());
    }
}
```

- [ ] **Step 2: Run the tests to verify they pass**

Run: `cargo test -p fm-app selection_range_tests`
Expected: PASS (4 tests). (`resolve_range_names` is a complete, correct implementation above — there's no red/green cycle needed for a function this small where the implementation and the test were written together; the point of running it now is to confirm `cargo test -p fm-app` actually works in this environment, since this crate has no prior test suite.)

- [ ] **Step 3: Declare and implement the `selectRange` invokable using it**

In the bridge module's selection `unsafe extern "RustQt"` block (added in Task 1, Step 3 — the one with `setSelected`/`selectAll`/`clearSelection`/`selectedCount`), add `selectRange` right after `setSelected`:

```rust
        #[qinvokable]
        #[cxx_name = "selectRange"]
        fn select_range(self: Pin<&mut FileListModel>, from_name: &QString, to_name: &QString);
```

Then add the implementation to `impl qobject::FileListModel`, near `set_selected`:

```rust
    fn select_range(mut self: core::pin::Pin<&mut Self>, from_name: &QString, to_name: &QString) {
        let matching = matching_indices(&self.entries, &self.search_query.to_string(), self.show_hidden);
        let displayed: Vec<&fm_core::FileEntry> = matching.iter().map(|&i| &self.entries[i]).collect();
        let names = resolve_range_names(&displayed, &from_name.to_string(), &to_name.to_string());
        if names.is_empty() {
            return;
        }
        self.as_mut().rust_mut().selected.extend(names);

        if matching.is_empty() {
            return;
        }
        let parent = cxx_qt_lib::QModelIndex::default();
        let first = self.model_index(0, 0, &parent);
        let last = self.model_index((matching.len() - 1) as i32, 0, &parent);
        self.as_mut()
            .data_changed(&first, &last, &cxx_qt_lib::QList::<i32>::default());
    }
```

- [ ] **Step 4: Build**

Run: `cargo build -p fm-app`
Expected: builds successfully.

- [ ] **Step 5: Commit**

```bash
git add crates/app/src/file_list_model.rs
git commit -m "feat(app): add Shift+click range selection"
```

---

### Task 3: Multi-item clipboard (copy/cut selection) and batch paste

**Files:**
- Modify: `crates/app/src/file_list_model.rs`

**Interfaces:**
- Consumes: `self.selected` (Task 1), `fm_core::ops::path_size`, `fm_core::ops::copy_with_progress`, `fm_core::ops::move_entry_with_progress` (all pre-existing, unchanged).
- Produces: `copySelection()`, `cutSelection()` invokables; `pasteEntry()` (existing name/signature, rewritten internals) now handles a batch. Task 7 wires `copySelection`/`cutSelection` into `ItemContextMenu`'s multi-select actions.

- [ ] **Step 1: Change the clipboard field from one path to many**

Replace the field in `FileListModelRust`:

```rust
    clipboard_path: Option<PathBuf>,
    clipboard_is_cut: bool,
```

with:

```rust
    clipboard_paths: Vec<PathBuf>,
    clipboard_is_cut: bool,
```

And in `Default for FileListModelRust`, replace `clipboard_path: None,` with `clipboard_paths: Vec::new(),`.

- [ ] **Step 2: Declare the two new invokables**

In the `unsafe extern "RustQt"` block that already contains `copy_entry`/`cut_entry`/`can_paste`/`paste_entry`, add two entries right after `cut_entry`:

```rust
        #[qinvokable]
        #[cxx_name = "cutEntry"]
        fn cut_entry(self: Pin<&mut FileListModel>, name: &QString);

        /// Snapshots every currently-selected name into the clipboard, for
        /// pasting elsewhere — the multi-item counterpart to copyEntry.
        #[qinvokable]
        #[cxx_name = "copySelection"]
        fn copy_selection(self: Pin<&mut FileListModel>);

        /// Multi-item counterpart to cutEntry.
        #[qinvokable]
        #[cxx_name = "cutSelection"]
        fn cut_selection(self: Pin<&mut FileListModel>);

        #[qinvokable]
        #[cxx_name = "canPaste"]
        fn can_paste(self: &FileListModel) -> bool;
```

- [ ] **Step 3: Update `copy_entry`/`cut_entry` for the new field, add `copy_selection`/`cut_selection`, update `can_paste`**

Replace these three methods in `impl qobject::FileListModel`:

```rust
    fn copy_entry(mut self: core::pin::Pin<&mut Self>, name: &QString) {
        let current = PathBuf::from(self.current_path.to_string());
        self.as_mut().rust_mut().clipboard_paths = vec![current.join(name.to_string())];
        self.as_mut().rust_mut().clipboard_is_cut = false;
    }

    fn cut_entry(mut self: core::pin::Pin<&mut Self>, name: &QString) {
        let current = PathBuf::from(self.current_path.to_string());
        self.as_mut().rust_mut().clipboard_paths = vec![current.join(name.to_string())];
        self.as_mut().rust_mut().clipboard_is_cut = true;
    }

    fn copy_selection(mut self: core::pin::Pin<&mut Self>) {
        let current = PathBuf::from(self.current_path.to_string());
        let paths: Vec<PathBuf> = self.selected.iter().map(|name| current.join(name)).collect();
        self.as_mut().rust_mut().clipboard_paths = paths;
        self.as_mut().rust_mut().clipboard_is_cut = false;
    }

    fn cut_selection(mut self: core::pin::Pin<&mut Self>) {
        let current = PathBuf::from(self.current_path.to_string());
        let paths: Vec<PathBuf> = self.selected.iter().map(|name| current.join(name)).collect();
        self.as_mut().rust_mut().clipboard_paths = paths;
        self.as_mut().rust_mut().clipboard_is_cut = true;
    }

    fn can_paste(&self) -> bool {
        !self.clipboard_paths.is_empty()
    }
```

- [ ] **Step 4: Rewrite `paste_entry` to loop over the batch**

Replace the whole `paste_entry` method:

```rust
    fn paste_entry(mut self: core::pin::Pin<&mut Self>) {
        let sources = self.clipboard_paths.clone();
        if sources.is_empty() {
            return;
        }
        let is_cut = self.clipboard_is_cut;
        let dest_dir = PathBuf::from(self.current_path.to_string());

        // Computed synchronously, up front — one combined denominator for
        // the whole batch (cheap relative to the actual copy), so the
        // "done / total" display starts with a real number even for a
        // multi-item paste.
        let total: u64 = sources.iter().map(|src| fm_core::ops::path_size(src)).sum();

        self.as_mut().set_is_busy(true);
        self.as_mut().set_busy_label(QString::from(if is_cut {
            "Moving…"
        } else {
            "Copying…"
        }));
        self.as_mut().set_transfer_done_bytes(0);
        self.as_mut().set_transfer_total_bytes(total as i64);
        self.as_mut().set_transfer_speed_label(QString::from(""));

        // A cut clears the whole clipboard after pasting once; a copy can
        // be pasted repeatedly — same rule as the single-item version this
        // replaces, just applied to the whole batch.
        if is_cut {
            self.as_mut().rust_mut().clipboard_paths = Vec::new();
        }

        // Shared across every item in the batch and never reset between
        // them — copy_with_progress/move_entry_with_progress only ever
        // fetch_add onto `done`, so reusing the same counter across
        // sequential items gives one continuous running total for the
        // whole batch instead of restarting at 0 per item.
        let done_counter = std::sync::Arc::new(std::sync::atomic::AtomicU64::new(0));
        let (progress_tx, mut progress_rx) = tokio::sync::mpsc::unbounded_channel::<u64>();

        let qt_thread = self.qt_thread();
        let progress_qt_thread = qt_thread.clone();
        runtime().spawn(async move {
            let start = std::time::Instant::now();
            let mut last_emit = std::time::Instant::now() - std::time::Duration::from_secs(1);
            while let Some(done) = progress_rx.recv().await {
                if last_emit.elapsed() < std::time::Duration::from_millis(120) {
                    continue;
                }
                last_emit = std::time::Instant::now();
                let elapsed = start.elapsed().as_secs_f64().max(0.001);
                let speed = (done as f64 / elapsed) as u64;
                let _ = progress_qt_thread.queue(move |mut model| {
                    model.as_mut().set_transfer_done_bytes(done as i64);
                    model
                        .as_mut()
                        .set_transfer_speed_label(QString::from(&format!(
                            "{}/s",
                            fm_core::ops::format_bytes(speed)
                        )));
                });
            }
        });

        runtime().spawn(async move {
            let mut last_error = None;
            for src in sources {
                let Some(file_name) = src.file_name().map(|n| n.to_os_string()) else {
                    continue;
                };
                let dest = unique_paste_destination(&dest_dir, std::path::Path::new(&file_name));
                let result = if is_cut {
                    fm_core::ops::move_entry_with_progress(
                        &src,
                        &dest,
                        done_counter.clone(),
                        progress_tx.clone(),
                    )
                    .await
                } else {
                    fm_core::ops::copy_with_progress(
                        src.clone(),
                        dest.clone(),
                        done_counter.clone(),
                        progress_tx.clone(),
                    )
                    .await
                };
                if let Err(e) = result {
                    eprintln!("paste_entry failed for {}: {e}", src.display());
                    last_error = Some(e);
                }
            }

            let _ = qt_thread.queue(move |mut model| {
                if let Some(e) = last_error {
                    eprintln!("paste_entry: at least one item in the batch failed: {e}");
                }
                model.as_mut().set_is_busy(false);
                model.as_mut().set_transfer_done_bytes(0);
                model.as_mut().set_transfer_total_bytes(0);
                model.as_mut().refresh_entries_diff();
            });
        });
    }
```

- [ ] **Step 5: Build**

Run: `cargo build -p fm-app`
Expected: builds successfully.

- [ ] **Step 6: Commit**

```bash
git add crates/app/src/file_list_model.rs
git commit -m "feat(app): multi-item clipboard and batch paste"
```

---

### Task 4: Bulk delete and duplicate

**Files:**
- Modify: `crates/app/src/file_list_model.rs`

**Interfaces:**
- Consumes: `self.selected` (Task 1), `fm_core::trash::move_to_trash`, `fm_core::ops::duplicate` (both pre-existing, unchanged).
- Produces: `deleteSelection()`, `duplicateSelection()` invokables. Task 7 wires these into `ItemContextMenu`'s multi-select Delete/Duplicate actions.

- [ ] **Step 1: Declare the two new invokables**

In the same block as `delete_entry`/`duplicate_entry` (the block starting with `create_folder`), add right after `delete_entry`:

```rust
        #[qinvokable]
        #[cxx_name = "deleteEntry"]
        fn delete_entry(self: Pin<&mut FileListModel>, name: &QString);

        /// Moves every currently-selected entry to Trash. Unlike
        /// deleteEntry (synchronous — fine for one item), this runs as a
        /// background task so trashing a large selection doesn't hitch the
        /// UI thread, using the same isBusy/busyLabel indicator pasteEntry
        /// already exposes (no byte-progress — Trash moves are fast enough
        /// that a spinner is enough).
        #[qinvokable]
        #[cxx_name = "deleteSelection"]
        fn delete_selection(self: Pin<&mut FileListModel>);
```

And right after `duplicate_entry`:

```rust
        #[qinvokable]
        #[cxx_name = "duplicateEntry"]
        fn duplicate_entry(self: Pin<&mut FileListModel>, name: &QString);

        /// Multi-item counterpart to duplicateEntry — same background-task
        /// pattern as deleteSelection.
        #[qinvokable]
        #[cxx_name = "duplicateSelection"]
        fn duplicate_selection(self: Pin<&mut FileListModel>);
```

- [ ] **Step 2: Implement both**

Add to `impl qobject::FileListModel`, near `delete_entry`/`duplicate_entry`:

```rust
    fn delete_selection(mut self: core::pin::Pin<&mut Self>) {
        let current = PathBuf::from(self.current_path.to_string());
        let targets: Vec<PathBuf> = self.selected.iter().map(|name| current.join(name)).collect();
        if targets.is_empty() {
            return;
        }

        self.as_mut().set_is_busy(true);
        self.as_mut().set_busy_label(QString::from("Deleting…"));

        let qt_thread = self.qt_thread();
        runtime().spawn(async move {
            for target in targets {
                if let Err(e) = fm_core::trash::move_to_trash(&target).await {
                    eprintln!("delete_selection failed for {}: {e}", target.display());
                }
            }
            let _ = qt_thread.queue(move |mut model| {
                model.as_mut().set_is_busy(false);
                model.as_mut().refresh_entries_diff();
            });
        });
    }

    fn duplicate_selection(mut self: core::pin::Pin<&mut Self>) {
        let current = PathBuf::from(self.current_path.to_string());
        let targets: Vec<PathBuf> = self.selected.iter().map(|name| current.join(name)).collect();
        if targets.is_empty() {
            return;
        }

        self.as_mut().set_is_busy(true);
        self.as_mut().set_busy_label(QString::from("Duplicating…"));

        let qt_thread = self.qt_thread();
        runtime().spawn(async move {
            for target in targets {
                if let Err(e) = fm_core::ops::duplicate(&target).await {
                    eprintln!("duplicate_selection failed for {}: {e}", target.display());
                }
            }
            let _ = qt_thread.queue(move |mut model| {
                model.as_mut().set_is_busy(false);
                model.as_mut().refresh_entries_diff();
            });
        });
    }
```

- [ ] **Step 3: Build**

Run: `cargo build -p fm-app`
Expected: builds successfully.

- [ ] **Step 4: Commit**

```bash
git add crates/app/src/file_list_model.rs
git commit -m "feat(app): add bulk delete and duplicate for the current selection"
```

---

### Task 5: Selection role, visual state, and click semantics in QML

**Files:**
- Modify: `crates/app/qml/components/FileListItem.qml`
- Modify: `crates/app/qml/components/FileGridItem.qml`
- Modify: `crates/app/qml/main.qml`

**Interfaces:**
- Consumes: model role `selected` (Task 1), invokables `setSelected`, `selectRange`, `clearSelection` (Tasks 1–2).
- Produces: `required property bool selected` on both delegates; `selectionAnchor` property on `listView`/`gridView` (Task 6 reads `contentItem.children[i].selected`/`.name` for rubber-band selection; Task 7's context-menu wiring reads whether the right-clicked item was already selected).

- [ ] **Step 1: Add the `selected` role and a selection tint to `FileListItem`**

In `crates/app/qml/components/FileListItem.qml`, add the required property alongside the others:

```qml
    required property string permissions
    required property string thumbnailPath
    // Bound to the model's `selected` role — true while this row is part
    // of the current multi-selection (Ctrl/Shift/drag-select).
    required property bool selected
```

Add a persistent selection-tint `Rectangle` *before* the existing hover-highlight `Rectangle`, so hovering a selected row still shows the hover state layer on top of the selection tint:

```qml
    // Persistent tint while selected — distinct from the transient
    // opacity-animated hover highlight below, which continues to layer on
    // top of it on hover.
    Rectangle {
        anchors.fill: parent
        radius: Shape.small
        color: Color.scheme.secondaryContainer
        opacity: root.selected ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }

    Rectangle {
        anchors.fill: parent
        radius: Shape.small
        color: Elevation.surfaceAt(1)
        opacity: rowArea.containsMouse ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }
```

- [ ] **Step 2: Add click/Ctrl-click/Shift-click selection semantics**

Replace the `onClicked` handler on `rowArea`:

```qml
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                // Right-clicking an item already part of the selection
                // keeps the whole selection (so the menu can act on all of
                // it); right-clicking outside it replaces the selection
                // with just this entry, matching every reference file
                // manager.
                if (!root.selected) {
                    root.fileModel.clearSelection()
                    root.fileModel.setSelected(root.name, true)
                    root.ListView.view.selectionAnchor = root.name
                }
                var scenePos = root.mapToItem(null, mouse.x, mouse.y)
                root.contextMenuRequested(scenePos.x, scenePos.y)
                return
            }
            if (mouse.modifiers & Qt.ShiftModifier) {
                root.fileModel.selectRange(root.ListView.view.selectionAnchor, root.name)
            } else if (mouse.modifiers & Qt.ControlModifier) {
                root.fileModel.setSelected(root.name, !root.selected)
                root.ListView.view.selectionAnchor = root.name
            } else {
                root.fileModel.clearSelection()
                root.fileModel.setSelected(root.name, true)
                root.ListView.view.selectionAnchor = root.name
            }
        }
```

- [ ] **Step 3: Mirror the same changes in `FileGridItem`**

In `crates/app/qml/components/FileGridItem.qml`, add the property:

```qml
    required property string thumbnailPath
    // See FileListItem.qml's matching property.
    required property bool selected
```

Add the same selection-tint `Rectangle`, placed before the existing hover `Rectangle` inside `card`:

```qml
        Rectangle {
            anchors.fill: parent
            radius: Shape.medium
            color: Color.scheme.secondaryContainer
            opacity: root.selected ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }

        Rectangle {
            // No permanent fill here — a fully opaque `surface`-colored box
            // behind every single grid icon (regardless of hover) read as a
            // grid of dark rectangles in dark mode, since `surface` is
            // darker than the content panel behind it. Hover-only opacity,
            // constant color (see FileListItem.qml for why not `Behavior on
            // color` from "transparent").
            anchors.fill: parent
            radius: Shape.medium
            color: Elevation.surfaceAt(1)
            opacity: cellArea.containsMouse ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }
```

Replace `cellArea`'s `onClicked`:

```qml
            onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton) {
                    if (!root.selected) {
                        root.fileModel.clearSelection()
                        root.fileModel.setSelected(root.name, true)
                        root.GridView.view.selectionAnchor = root.name
                    }
                    var scenePos = root.mapToItem(null, mouse.x, mouse.y)
                    root.contextMenuRequested(scenePos.x, scenePos.y)
                    return
                }
                if (mouse.modifiers & Qt.ShiftModifier) {
                    root.fileModel.selectRange(root.GridView.view.selectionAnchor, root.name)
                } else if (mouse.modifiers & Qt.ControlModifier) {
                    root.fileModel.setSelected(root.name, !root.selected)
                    root.GridView.view.selectionAnchor = root.name
                } else {
                    root.fileModel.clearSelection()
                    root.fileModel.setSelected(root.name, true)
                    root.GridView.view.selectionAnchor = root.name
                }
            }
```

- [ ] **Step 4: Give `listView`/`gridView` somewhere to keep the Shift+click anchor**

In `crates/app/qml/main.qml`, add `selectionAnchor` to `listView`:

```qml
                            ListView {
                                id: listView
                                anchors.fill: parent
                                anchors.margins: 4
                                anchors.rightMargin: 14
                                model: fileModel
                                spacing: 2
                                reuseItems: true
                                cacheBuffer: 400
                                acceptedButtons: Qt.NoButton
                                // Last plain- or Ctrl-clicked name, for
                                // Shift+click range math — transient UI
                                // state, not part of "what's selected"
                                // (that lives in fileModel), so it's kept
                                // here rather than in Rust.
                                property string selectionAnchor: ""
```

And the same on `gridView`:

```qml
                            GridView {
                                id: gridView
                                anchors.fill: parent
                                anchors.margins: 4
                                anchors.rightMargin: 14
                                model: fileModel
                                property string selectionAnchor: ""
                                readonly property int minCellWidth: window.activeIconProfile.gridMinWidth
```

- [ ] **Step 5: Build**

Run: `cargo build -p fm-app`
Expected: builds successfully.

- [ ] **Step 6: Commit**

```bash
git add crates/app/qml/components/FileListItem.qml crates/app/qml/components/FileGridItem.qml crates/app/qml/main.qml
git commit -m "feat(app): click/Ctrl-click/Shift-click selection in list and grid views"
```

---

### Task 6: Drag rubber-band selection

**Files:**
- Modify: `crates/app/qml/main.qml`

**Interfaces:**
- Consumes: `fileModel.setSelected`/`clearSelection` (Task 1), `listView.selectionAnchor`/`gridView.selectionAnchor` (Task 5, not touched by this task but present in the same file).
- Produces: nothing new for later tasks — this is the last piece of the selection *interaction* surface. Task 7 only adds menu/keyboard wiring, not more mouse handling.

- [ ] **Step 1: Extend `listBackgroundArea` with left-button drag-select**

In `crates/app/qml/main.qml`, replace the whole `listBackgroundArea` `MouseArea` (inside `listComponent`'s `ListView`):

```qml
                                MouseArea {
                                    // Stacked below the delegates (which live inside
                                    // listView's contentItem) so a right-click over an
                                    // item reaches FileListItem's own MouseArea first;
                                    // this one only fires for clicks that miss every
                                    // delegate, i.e. genuinely empty space. Left-button
                                    // press-and-drag here rubber-band-selects; a plain
                                    // click (no drag) just clears the selection, and a
                                    // right-click clears it too before opening the
                                    // background context menu.
                                    id: listBackgroundArea
                                    z: -1
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    hoverEnabled: false

                                    property real pressX: 0
                                    property real pressY: 0
                                    property bool dragging: false

                                    onWheel: (wheel) => window.applyWheelScroll(listView, wheel)

                                    onPressed: (mouse) => {
                                        if (mouse.button !== Qt.LeftButton) {
                                            return
                                        }
                                        listBackgroundArea.pressX = mouse.x
                                        listBackgroundArea.pressY = mouse.y
                                        listBackgroundArea.dragging = false
                                        if (!(mouse.modifiers & Qt.ControlModifier)) {
                                            fileModel.clearSelection()
                                        }
                                    }

                                    onPositionChanged: (mouse) => {
                                        if (!listBackgroundArea.pressed || !(listBackgroundArea.pressedButtons & Qt.LeftButton)) {
                                            return
                                        }
                                        var dx = mouse.x - listBackgroundArea.pressX
                                        var dy = mouse.y - listBackgroundArea.pressY
                                        // A small movement threshold before treating this
                                        // as a drag at all — otherwise every plain click
                                        // (which always has a tiny bit of jitter) would
                                        // flash the selection rectangle for one frame.
                                        if (!listBackgroundArea.dragging && Math.sqrt(dx * dx + dy * dy) < 6) {
                                            return
                                        }
                                        listBackgroundArea.dragging = true

                                        listSelectionRect.x = Math.min(listBackgroundArea.pressX, mouse.x)
                                        listSelectionRect.y = Math.min(listBackgroundArea.pressY, mouse.y)
                                        listSelectionRect.width = Math.abs(mouse.x - listBackgroundArea.pressX)
                                        listSelectionRect.height = Math.abs(mouse.y - listBackgroundArea.pressY)
                                        listSelectionRect.visible = true

                                        // listBackgroundArea's own coordinates are
                                        // viewport-relative; contentItem's children
                                        // (the delegates) are positioned in
                                        // content-relative coordinates — offset by the
                                        // current scroll position to compare them.
                                        var rectLeft = listSelectionRect.x + listView.contentX
                                        var rectTop = listSelectionRect.y + listView.contentY
                                        var rectRight = rectLeft + listSelectionRect.width
                                        var rectBottom = rectTop + listSelectionRect.height

                                        // Only currently-visible (already-instantiated)
                                        // delegates can be swept — no auto-scroll while
                                        // dragging near an edge (see this plan's Global
                                        // Constraints).
                                        var children = listView.contentItem.children
                                        for (var i = 0; i < children.length; i++) {
                                            var child = children[i]
                                            if (child.name === undefined) {
                                                continue
                                            }
                                            var overlaps = child.x < rectRight && (child.x + child.width) > rectLeft &&
                                                           child.y < rectBottom && (child.y + child.height) > rectTop
                                            if (overlaps) {
                                                fileModel.setSelected(child.name, true)
                                            }
                                        }
                                    }

                                    onReleased: {
                                        listSelectionRect.visible = false
                                        listBackgroundArea.dragging = false
                                    }

                                    onClicked: (mouse) => {
                                        if (listBackgroundArea.dragging) {
                                            return
                                        }
                                        if (mouse.button === Qt.RightButton) {
                                            fileModel.clearSelection()
                                            var scenePos = listBackgroundArea.mapToItem(null, mouse.x, mouse.y)
                                            window.openContextMenu(scenePos.x, scenePos.y)
                                        }
                                    }
                                }

                                Rectangle {
                                    id: listSelectionRect
                                    visible: false
                                    color: Qt.alpha(Color.scheme.primary, 0.16)
                                    border.width: 1
                                    border.color: Color.scheme.primary
                                }
```

- [ ] **Step 2: Same for `gridBackgroundArea`**

Replace the whole `gridBackgroundArea` `MouseArea` (inside `gridComponent`'s `GridView`):

```qml
                                MouseArea {
                                    // See the matching comment in the ListView's
                                    // overlay above — kept below the delegates in
                                    // z-order so per-item right-clicks win. Same
                                    // left-button drag-select behavior as
                                    // listBackgroundArea.
                                    id: gridBackgroundArea
                                    z: -1
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    hoverEnabled: false

                                    property real pressX: 0
                                    property real pressY: 0
                                    property bool dragging: false

                                    onWheel: (wheel) => window.applyWheelScroll(gridView, wheel)

                                    onPressed: (mouse) => {
                                        if (mouse.button !== Qt.LeftButton) {
                                            return
                                        }
                                        gridBackgroundArea.pressX = mouse.x
                                        gridBackgroundArea.pressY = mouse.y
                                        gridBackgroundArea.dragging = false
                                        if (!(mouse.modifiers & Qt.ControlModifier)) {
                                            fileModel.clearSelection()
                                        }
                                    }

                                    onPositionChanged: (mouse) => {
                                        if (!gridBackgroundArea.pressed || !(gridBackgroundArea.pressedButtons & Qt.LeftButton)) {
                                            return
                                        }
                                        var dx = mouse.x - gridBackgroundArea.pressX
                                        var dy = mouse.y - gridBackgroundArea.pressY
                                        if (!gridBackgroundArea.dragging && Math.sqrt(dx * dx + dy * dy) < 6) {
                                            return
                                        }
                                        gridBackgroundArea.dragging = true

                                        gridSelectionRect.x = Math.min(gridBackgroundArea.pressX, mouse.x)
                                        gridSelectionRect.y = Math.min(gridBackgroundArea.pressY, mouse.y)
                                        gridSelectionRect.width = Math.abs(mouse.x - gridBackgroundArea.pressX)
                                        gridSelectionRect.height = Math.abs(mouse.y - gridBackgroundArea.pressY)
                                        gridSelectionRect.visible = true

                                        var rectLeft = gridSelectionRect.x + gridView.contentX
                                        var rectTop = gridSelectionRect.y + gridView.contentY
                                        var rectRight = rectLeft + gridSelectionRect.width
                                        var rectBottom = rectTop + gridSelectionRect.height

                                        var children = gridView.contentItem.children
                                        for (var i = 0; i < children.length; i++) {
                                            var child = children[i]
                                            if (child.name === undefined) {
                                                continue
                                            }
                                            var overlaps = child.x < rectRight && (child.x + child.width) > rectLeft &&
                                                           child.y < rectBottom && (child.y + child.height) > rectTop
                                            if (overlaps) {
                                                fileModel.setSelected(child.name, true)
                                            }
                                        }
                                    }

                                    onReleased: {
                                        gridSelectionRect.visible = false
                                        gridBackgroundArea.dragging = false
                                    }

                                    onClicked: (mouse) => {
                                        if (gridBackgroundArea.dragging) {
                                            return
                                        }
                                        if (mouse.button === Qt.RightButton) {
                                            fileModel.clearSelection()
                                            var scenePos = gridBackgroundArea.mapToItem(null, mouse.x, mouse.y)
                                            window.openContextMenu(scenePos.x, scenePos.y)
                                        }
                                    }
                                }

                                Rectangle {
                                    id: gridSelectionRect
                                    visible: false
                                    color: Qt.alpha(Color.scheme.primary, 0.16)
                                    border.width: 1
                                    border.color: Color.scheme.primary
                                }
```

- [ ] **Step 3: Build**

Run: `cargo build -p fm-app`
Expected: builds successfully.

- [ ] **Step 4: Commit**

```bash
git add crates/app/qml/main.qml
git commit -m "feat(app): drag rubber-band selection in list and grid views"
```

---

### Task 7: Selection-aware context menu, Select All, and keyboard shortcut

**Files:**
- Modify: `crates/app/qml/components/ItemContextMenu.qml`
- Modify: `crates/app/qml/components/ContextMenu.qml`
- Modify: `crates/app/qml/main.qml`

**Interfaces:**
- Consumes: `fileModel.selectedCount()` (Task 1), `fileModel.copySelection()`/`cutSelection()` (Task 3), `fileModel.deleteSelection()`/`duplicateSelection()` (Task 4), `fileModel.selectAll()` (Task 1).
- Produces: nothing new for later tasks — this is the final task in the plan.

- [ ] **Step 1: Make `ItemContextMenu` selection-count-aware**

In `crates/app/qml/components/ItemContextMenu.qml`, add the property:

```qml
    property string entryPermissions: ""
    // How many items are selected at the moment this menu was popped up —
    // if more than 1, the menu shows only the actions that make sense in
    // bulk (Cut/Copy/Duplicate/Delete) instead of the full single-item menu.
    property int selectionCount: 1
```

Replace `_items` with a selection-count-aware version, and switch its entries from label-matching to an explicit `action` field (needed because multi-select labels now include a dynamic count, e.g. "Delete 3 items" — matching against the label text directly would break):

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

Update `popup()` to accept the count:

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
    }
```

Replace the menu item `MouseArea`'s `onClicked` to switch on `action` instead of `label`:

```qml
                    MouseArea {
                        id: _itemArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
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
                    }
```

- [ ] **Step 2: Add "Select All" to the background `ContextMenu`**

In `crates/app/qml/components/ContextMenu.qml`, add the signal:

```qml
    signal newFolderRequested
    signal openTerminalRequested
    signal pasteRequested
    signal selectAllRequested
```

Add the item to both branches of `_items`:

```qml
    readonly property var _items: canPaste
        ? [
            { icon: "create_new_folder", label: "New folder" },
            { icon: "content_paste", label: "Paste" },
            { icon: "select_all", label: "Select All" },
            { icon: "terminal", label: "Open Terminal Here" }
        ]
        : [
            { icon: "create_new_folder", label: "New folder" },
            { icon: "select_all", label: "Select All" },
            { icon: "terminal", label: "Open Terminal Here" }
        ]
```

Add the case to the existing (label-based — unchanged for this file, since none of its labels are dynamic) switch:

```qml
                        onClicked: {
                            root.close()
                            switch (menuItem.modelData.label) {
                            case "New folder": root.newFolderRequested(); break
                            case "Paste": root.pasteRequested(); break
                            case "Select All": root.selectAllRequested(); break
                            case "Open Terminal Here": root.openTerminalRequested(); break
                            }
                        }
```

- [ ] **Step 3: Wire selection-aware actions and Select All in `main.qml`**

Update `openItemContextMenu` to pass the current selection count:

```qml
    function openItemContextMenu(x, y, name, isDir, size, modified, mimeType, permissions) {
        itemContextMenuLoader.active = true
        itemContextMenuLoader.item.popup(x, y, name, isDir, size, modified, mimeType, permissions, fileModel.selectedCount())
    }
```

Add a bulk-delete confirm helper right after `openDeleteConfirmDialog`, and a `_pendingDeleteIsSelection` flag alongside the existing `_pendingDeleteName`:

```qml
    property string _pendingDeleteName: ""
    property bool _pendingDeleteIsSelection: false
```

```qml
    function openDeleteConfirmDialog(name) {
        window._pendingDeleteName = name
        window._pendingDeleteIsSelection = false
        deleteConfirmDialogLoader.active = true
        deleteConfirmDialogLoader.item.open("Move \"" + name + "\" to Trash?")
    }

    function openDeleteSelectionConfirmDialog(count) {
        window._pendingDeleteIsSelection = true
        deleteConfirmDialogLoader.active = true
        deleteConfirmDialogLoader.item.open("Move " + count + " items to Trash?")
    }
```

Update the `itemContextMenuLoader`'s handlers to branch on `selectionCount`:

```qml
        sourceComponent: ItemContextMenu {
            id: itemContextMenu
            onOpenRequested: (name) => {
                if (itemContextMenu.entryIsDir) {
                    fileModel.navigate(fileModel.currentPath + "/" + name)
                } else {
                    fileModel.openEntry(name)
                }
            }
            onRenameRequested: (name) => window.openRenameDialog(name)
            onDuplicateRequested: (name) => {
                if (itemContextMenu.selectionCount > 1) {
                    fileModel.duplicateSelection()
                } else {
                    fileModel.duplicateEntry(name)
                }
            }
            onCopyPathRequested: (name) => clipboardHelper.copyText(fileModel.entryAbsolutePath(name))
            onCopyRequested: (name) => {
                if (itemContextMenu.selectionCount > 1) {
                    fileModel.copySelection()
                } else {
                    fileModel.copyEntry(name)
                }
            }
            onCutRequested: (name) => {
                if (itemContextMenu.selectionCount > 1) {
                    fileModel.cutSelection()
                } else {
                    fileModel.cutEntry(name)
                }
            }
            onDeleteRequested: (name) => {
                if (itemContextMenu.selectionCount > 1) {
                    window.openDeleteSelectionConfirmDialog(itemContextMenu.selectionCount)
                } else {
                    window.openDeleteConfirmDialog(name)
                }
            }
            onPropertiesRequested: (name, isDir, size, modified, mimeType, permissions) =>
                window.openPropertiesDialog(name, isDir, size, modified, mimeType, permissions)
            onClosed: Qt.callLater(() => itemContextMenuLoader.active = false)
        }
```

Update `deleteConfirmDialogLoader`'s `onConfirmed` to branch the same way:

```qml
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
```

Wire `selectAllRequested` on the `contextMenuLoader`'s `ContextMenu`:

```qml
        sourceComponent: ContextMenu {
            onNewFolderRequested: window.openNewFolderDialog()
            onOpenTerminalRequested: fileModel.openTerminalHere()
            onPasteRequested: fileModel.pasteEntry()
            onSelectAllRequested: fileModel.selectAll()
            onClosed: Qt.callLater(() => contextMenuLoader.active = false)
        }
```

Finally, add a `Ctrl+A` shortcut — as a plain child of the root `Window`, alongside `clipboardHelper`:

```qml
    // Ctrl+A selects everything in the current folder. A window-level
    // Shortcut, not a Keys handler on the view — the view doesn't hold
    // keyboard focus today, and a Shortcut doesn't need it to. If a
    // TextInput has focus (rename dialog, search field) and the user
    // presses Ctrl+A meaning "select all text in this field," that
    // TextInput's own built-in handling takes the key first — Shortcut
    // only fires when nothing more specific already consumed it.
    Shortcut {
        sequence: StandardKey.SelectAll
        onActivated: fileModel.selectAll()
    }
```

- [ ] **Step 4: Build**

Run: `cargo build -p fm-app`
Expected: builds successfully.

- [ ] **Step 5: Manual verification**

Per this project's established testing convention (no automated QML test harness — see the original design spec's testing section and Plan 2/3's Global Constraints), verify interactively if a real desktop session is available: `cargo run -p fm-app -- $HOME`, then check:
- Click a row → only it is selected (tinted). Click another → selection moves.
- Ctrl+click several rows → all stay selected; Ctrl+click one again → it toggles off.
- Shift+click after a plain click → selects the contiguous range between them.
- Press-drag on empty space → a rectangle appears and sweeps up every row/tile it crosses.
- Ctrl+A → everything in the folder is selected.
- Click empty space → selection clears.
- Right-click a multi-selected item → menu shows "Cut/Copy/Duplicate/Delete N items" only; confirm Delete moves all of them to Trash in one go.
- Select several items, Copy, navigate elsewhere, Paste → all of them appear, with "(copy)" suffixes applied only where a name collides.
- Select several items, Cut, Paste elsewhere → all of them move; the source folder no longer has them.
- Select several items, Duplicate → each gets a "(copy)" sibling in the same folder.

If this sandboxed environment can't drive a real display (see Plan 2's documented `QT_QPA_PLATFORM=offscreen` hang), `cargo build -p fm-app` succeeding is the verification ceiling — say so rather than claiming an interactive pass.

- [ ] **Step 6: Commit**

```bash
git add crates/app/qml/components/ItemContextMenu.qml crates/app/qml/components/ContextMenu.qml crates/app/qml/main.qml
git commit -m "feat(app): selection-aware context menu, Select All, and Ctrl+A"
```

---

## Plan Complete

The file manager now supports standard multi-select interactions (click, Ctrl+click, Shift+click, drag rubber-band, Ctrl+A) across both list and grid views, with Copy, Cut, Delete, and Duplicate all selection-aware. Selection lives in the Rust model as a plain role, pruned automatically on every listing refresh and cleared on navigation. Not covered here, per the design spec's explicit non-goals: drag-and-drop of selected items, auto-scroll while rubber-band-dragging, and an aggregate Properties view for a multi-item selection.
