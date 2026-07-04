# Error Surfacing (Snackbar) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every user-triggered file operation that can fail (create folder, rename, delete, paste, duplicate, open, open-terminal) show the user a message via a global M3 Snackbar, instead of silently `eprintln!`-ing to a terminal nobody's watching.

**Architecture:** Add one custom Qt signal (`errorOccurred(QString message)`) to the existing `FileListModel` cxx-qt bridge in `crates/app/src/file_list_model.rs`. Every scoped failure site emits it alongside its existing `eprintln!`. A new QML component, `Snackbar.qml`, lives once in `main.qml` and shows whatever message the signal carries, auto-dismissing after 4 seconds.

**Tech Stack:** Rust (cxx-qt 0.9, already the version in this workspace), QML/Qt Quick.

## Global Constraints

- Full spec: `docs/superpowers/specs/2026-07-04-error-surfacing-design.md` — read it if anything below is ambiguous.
- **Scope** — only these operations emit `errorOccurred`: `create_folder`, `rename_entry`, `delete_entry`/`delete_selection`, `empty_trash`, `duplicate_entry`/`duplicate_selection`, `paste_entry`, `open_entry`, `open_terminal_here`. Do **not** wire `save_settings` or `start_theme_colors_watch` — explicitly out of scope per the spec.
- **Batch operations summarize, they don't enumerate** — `delete_selection`, `duplicate_selection`, `paste_entry` emit exactly one signal for the whole batch (e.g. `"Couldn't delete 3 items"`), never one per failed item.
- **Existing `eprintln!` calls stay** — this adds a second, user-facing path; it does not replace the dev-facing stderr logging.
- **Snackbar behavior**: auto-dismiss after 4000ms, no action button, and a new message *replaces* whatever's currently showing and restarts the timer (no queueing).
- **Verification ceiling**: `cargo build -p fm-app` (runs the full cxx-qt codegen + C++ build + qmlcachegen — expect ~2 minutes per build, this is normal for this crate, not a hung build). There is no QML test harness in this project; anything that can't be unit-tested in plain Rust is verified by the user running the app themselves, not via any automated screenshot/launch tooling.
- Message format is exact strings given in each task below — don't paraphrase them.

---

### Task 1: `errorOccurred` signal + `pluralize_items` helper

**Files:**
- Modify: `crates/app/src/file_list_model.rs`

**Interfaces:**
- Produces: `fn error_occurred(self: Pin<&mut FileListModel>, message: QString)` — a cxx-qt signal, QML-visible as `errorOccurred(message)` / `onErrorOccurred`. Called elsewhere in this file as `self.as_mut().error_occurred(QString::from(&some_string))`.
- Produces: `fn pluralize_items(count: usize) -> String` — free function, e.g. `pluralize_items(1) == "1 item"`, `pluralize_items(3) == "3 items"`.

- [ ] **Step 1: Write the failing tests for `pluralize_items`**

Append to the end of `crates/app/src/file_list_model.rs` (after the existing `mod selection_range_tests { ... }` block, which currently ends the file at line 1366):

```rust

#[cfg(test)]
mod pluralize_items_tests {
    use super::*;

    #[test]
    fn pluralizes_a_single_item() {
        assert_eq!(pluralize_items(1), "1 item");
    }

    #[test]
    fn pluralizes_multiple_items() {
        assert_eq!(pluralize_items(3), "3 items");
    }

    #[test]
    fn pluralizes_zero_as_plural() {
        assert_eq!(pluralize_items(0), "0 items");
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cargo test -p fm-app pluralize_items_tests`
Expected: FAIL to compile — `cannot find function 'pluralize_items' in this scope`. (This triggers the full cxx-qt/C++ build pipeline via `build.rs`, so the failure takes about as long to appear as a normal build — that's expected for this crate, not a sign something's wrong.)

- [ ] **Step 3: Implement `pluralize_items`**

Add this function right after `resolve_range_names` (which currently ends at line 1313, just before the `#[cfg(test)] mod selection_range_tests` block):

```rust

/// "1 item" vs "N items" — used to summarize a batch operation's failure
/// count instead of listing every individual failure.
fn pluralize_items(count: usize) -> String {
    if count == 1 {
        "1 item".to_string()
    } else {
        format!("{count} items")
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cargo test -p fm-app pluralize_items_tests`
Expected: `test result: ok. 3 passed; 0 failed`

- [ ] **Step 5: Add the `errorOccurred` signal declaration**

In `crates/app/src/file_list_model.rs`, find the `unsafe extern "RustQt"` block that ends with the `request_thumbnail` declaration:

```rust
        #[qinvokable]
        #[cxx_name = "requestThumbnail"]
        fn request_thumbnail(self: Pin<&mut FileListModel>, name: &QString);
    }
```

Immediately after that block's closing `}`, add a new block:

```rust

    unsafe extern "RustQt" {
        /// Emitted whenever a user-triggered file operation fails, carrying
        /// a short user-facing message. QML listens via
        /// `Connections { target: fileModel; function onErrorOccurred(message) { ... } }`.
        #[qsignal]
        #[cxx_name = "errorOccurred"]
        fn error_occurred(self: Pin<&mut FileListModel>, message: QString);
    }
```

- [ ] **Step 6: Build to verify the signal declaration compiles**

Run: `cargo build -p fm-app`
Expected: `Finished` with no errors (the signal is declared but not yet emitted anywhere — that's fine, an unused signal is not a compile error).

- [ ] **Step 7: Commit**

```bash
git add crates/app/src/file_list_model.rs
git commit -m "feat(app): add errorOccurred signal and pluralize_items helper"
```

---

### Task 2: Wire single-item operations to emit `errorOccurred`

**Files:**
- Modify: `crates/app/src/file_list_model.rs`

**Interfaces:**
- Consumes: `self.as_mut().error_occurred(QString::from(&string))` from Task 1.

- [ ] **Step 1: Wire `create_folder`**

Replace:

```rust
    fn create_folder(mut self: core::pin::Pin<&mut Self>, name: &QString) {
        let current = PathBuf::from(self.current_path.to_string());
        if let Err(e) =
            runtime().block_on(fm_core::ops::create_folder(&current, &name.to_string()))
        {
            eprintln!("create_folder failed: {e}");
        }
        self.as_mut().refresh_entries_diff();
    }
```

with:

```rust
    fn create_folder(mut self: core::pin::Pin<&mut Self>, name: &QString) {
        let current = PathBuf::from(self.current_path.to_string());
        if let Err(e) =
            runtime().block_on(fm_core::ops::create_folder(&current, &name.to_string()))
        {
            eprintln!("create_folder failed: {e}");
            self.as_mut()
                .error_occurred(QString::from(&format!("Couldn't create folder: {e}")));
        }
        self.as_mut().refresh_entries_diff();
    }
```

- [ ] **Step 2: Wire `rename_entry`**

Replace:

```rust
    fn rename_entry(mut self: core::pin::Pin<&mut Self>, old_name: &QString, new_name: &QString) {
        let current = PathBuf::from(self.current_path.to_string());
        let target = current.join(old_name.to_string());
        if let Err(e) = runtime().block_on(fm_core::ops::rename(&target, &new_name.to_string())) {
            eprintln!("rename failed: {e}");
        }
        self.as_mut().refresh_entries_diff();
    }
```

with:

```rust
    fn rename_entry(mut self: core::pin::Pin<&mut Self>, old_name: &QString, new_name: &QString) {
        let current = PathBuf::from(self.current_path.to_string());
        let target = current.join(old_name.to_string());
        if let Err(e) = runtime().block_on(fm_core::ops::rename(&target, &new_name.to_string())) {
            eprintln!("rename failed: {e}");
            self.as_mut().error_occurred(QString::from(&format!(
                "Couldn't rename \"{}\": {e}",
                old_name.to_string()
            )));
        }
        self.as_mut().refresh_entries_diff();
    }
```

- [ ] **Step 3: Wire `delete_entry`**

Replace:

```rust
    fn delete_entry(mut self: core::pin::Pin<&mut Self>, name: &QString) {
        let current = PathBuf::from(self.current_path.to_string());
        let target = current.join(name.to_string());
        if let Err(e) = runtime().block_on(fm_core::trash::move_to_trash(&target)) {
            eprintln!("delete_entry failed: {e}");
        }
        self.as_mut().refresh_entries_diff();
    }
```

with:

```rust
    fn delete_entry(mut self: core::pin::Pin<&mut Self>, name: &QString) {
        let current = PathBuf::from(self.current_path.to_string());
        let target = current.join(name.to_string());
        if let Err(e) = runtime().block_on(fm_core::trash::move_to_trash(&target)) {
            eprintln!("delete_entry failed: {e}");
            self.as_mut().error_occurred(QString::from(&format!(
                "Couldn't delete \"{}\": {e}",
                name.to_string()
            )));
        }
        self.as_mut().refresh_entries_diff();
    }
```

- [ ] **Step 4: Wire `empty_trash`**

Replace:

```rust
    fn empty_trash(mut self: core::pin::Pin<&mut Self>) {
        if let Err(e) = runtime().block_on(fm_core::trash::empty_trash()) {
            eprintln!("empty_trash failed: {e}");
        }
        if self.current_path.to_string() == self.trash_path.to_string() {
            self.as_mut().refresh_entries_diff();
        }
    }
```

with:

```rust
    fn empty_trash(mut self: core::pin::Pin<&mut Self>) {
        if let Err(e) = runtime().block_on(fm_core::trash::empty_trash()) {
            eprintln!("empty_trash failed: {e}");
            self.as_mut()
                .error_occurred(QString::from(&format!("Couldn't empty trash: {e}")));
        }
        if self.current_path.to_string() == self.trash_path.to_string() {
            self.as_mut().refresh_entries_diff();
        }
    }
```

- [ ] **Step 5: Wire `open_entry`**

Replace:

```rust
    fn open_entry(self: core::pin::Pin<&mut Self>, name: &QString) {
        let current = PathBuf::from(self.current_path.to_string());
        let target = current.join(name.to_string());
        if let Err(e) = runtime().block_on(fm_core::ops::open_file(&target)) {
            eprintln!("open_entry failed: {e}");
        }
    }
```

with (note the added `mut` before `self` — it's now required for `self.as_mut()`):

```rust
    fn open_entry(mut self: core::pin::Pin<&mut Self>, name: &QString) {
        let current = PathBuf::from(self.current_path.to_string());
        let target = current.join(name.to_string());
        if let Err(e) = runtime().block_on(fm_core::ops::open_file(&target)) {
            eprintln!("open_entry failed: {e}");
            self.as_mut().error_occurred(QString::from(&format!(
                "Couldn't open \"{}\": {e}",
                name.to_string()
            )));
        }
    }
```

- [ ] **Step 6: Wire `duplicate_entry`**

Replace:

```rust
    fn duplicate_entry(mut self: core::pin::Pin<&mut Self>, name: &QString) {
        let current = PathBuf::from(self.current_path.to_string());
        let target = current.join(name.to_string());
        if let Err(e) = runtime().block_on(fm_core::ops::duplicate(&target)) {
            eprintln!("duplicate_entry failed: {e}");
        }
        self.as_mut().refresh_entries_diff();
    }
```

with:

```rust
    fn duplicate_entry(mut self: core::pin::Pin<&mut Self>, name: &QString) {
        let current = PathBuf::from(self.current_path.to_string());
        let target = current.join(name.to_string());
        if let Err(e) = runtime().block_on(fm_core::ops::duplicate(&target)) {
            eprintln!("duplicate_entry failed: {e}");
            self.as_mut().error_occurred(QString::from(&format!(
                "Couldn't duplicate \"{}\": {e}",
                name.to_string()
            )));
        }
        self.as_mut().refresh_entries_diff();
    }
```

- [ ] **Step 7: Wire `open_terminal_here`**

Replace:

```rust
    fn open_terminal_here(self: core::pin::Pin<&mut Self>) {
        let current = PathBuf::from(self.current_path.to_string());
        if let Err(e) = runtime().block_on(fm_core::ops::open_terminal(&current)) {
            eprintln!("open_terminal_here failed: {e}");
        }
    }
```

with (note the added `mut` before `self`):

```rust
    fn open_terminal_here(mut self: core::pin::Pin<&mut Self>) {
        let current = PathBuf::from(self.current_path.to_string());
        if let Err(e) = runtime().block_on(fm_core::ops::open_terminal(&current)) {
            eprintln!("open_terminal_here failed: {e}");
            self.as_mut()
                .error_occurred(QString::from(&format!("Couldn't open terminal here: {e}")));
        }
    }
```

- [ ] **Step 8: Build to verify**

Run: `cargo build -p fm-app`
Expected: `Finished` with no errors.

- [ ] **Step 9: Commit**

```bash
git add crates/app/src/file_list_model.rs
git commit -m "feat(app): emit errorOccurred from single-item file operations"
```

---

### Task 3: Wire batch operations to emit one summary `errorOccurred`

**Files:**
- Modify: `crates/app/src/file_list_model.rs`

**Interfaces:**
- Consumes: `self.as_mut().error_occurred(...)` (Task 1), `pluralize_items(count: usize) -> String` (Task 1).

- [ ] **Step 1: Wire `delete_selection`**

Replace:

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
```

with:

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
            let mut failed: usize = 0;
            for target in targets {
                if let Err(e) = fm_core::trash::move_to_trash(&target).await {
                    eprintln!("delete_selection failed for {}: {e}", target.display());
                    failed += 1;
                }
            }
            let _ = qt_thread.queue(move |mut model| {
                model.as_mut().set_is_busy(false);
                model.as_mut().refresh_entries_diff();
                if failed > 0 {
                    model.as_mut().error_occurred(QString::from(&format!(
                        "Couldn't delete {}",
                        pluralize_items(failed)
                    )));
                }
            });
        });
    }
```

- [ ] **Step 2: Wire `duplicate_selection`**

Replace:

```rust
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

with:

```rust
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
            let mut failed: usize = 0;
            for target in targets {
                if let Err(e) = fm_core::ops::duplicate(&target).await {
                    eprintln!("duplicate_selection failed for {}: {e}", target.display());
                    failed += 1;
                }
            }
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

- [ ] **Step 3: Wire `paste_entry`**

Find this block inside `paste_entry` (the per-item copy/move loop and its trailing `qt_thread.queue`):

```rust
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
```

Replace it with:

```rust
        runtime().spawn(async move {
            let mut failed: usize = 0;
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
                    failed += 1;
                }
            }

            let _ = qt_thread.queue(move |mut model| {
                model.as_mut().set_is_busy(false);
                model.as_mut().set_transfer_done_bytes(0);
                model.as_mut().set_transfer_total_bytes(0);
                model.as_mut().refresh_entries_diff();
                if failed > 0 {
                    model.as_mut().error_occurred(QString::from(&format!(
                        "Couldn't paste {}",
                        pluralize_items(failed)
                    )));
                }
            });
        });
```

- [ ] **Step 4: Build to verify**

Run: `cargo build -p fm-app`
Expected: `Finished` with no errors.

- [ ] **Step 5: Run the full fm-app test suite to make sure nothing broke**

Run: `cargo test -p fm-app`
Expected: all tests pass (`pluralize_items_tests` from Task 1 plus the pre-existing `selection_range_tests`).

- [ ] **Step 6: Commit**

```bash
git add crates/app/src/file_list_model.rs
git commit -m "feat(app): summarize batch operation failures into one errorOccurred"
```

---

### Task 4: `Snackbar.qml` component

**Files:**
- Create: `crates/app/qml/components/Snackbar.qml`
- Modify: `crates/app/build.rs`

**Interfaces:**
- Produces: `Snackbar` QML type with one callable function `show(text: string)`. No other properties are meant to be set from outside.

- [ ] **Step 1: Create the component**

Write `crates/app/qml/components/Snackbar.qml`:

```qml
import QtQuick
import com.filemanager.app 1.0

// A single global M3-style transient snackbar for surfacing failed
// operations (create/rename/delete/paste/etc.) that would otherwise fail
// silently — see docs/superpowers/specs/2026-07-04-error-surfacing-design.md.
// One instance lives in main.qml; call show(message) on it. Auto-dismisses
// after 4s — a new message while one is already showing replaces it and
// restarts the timer, rather than queuing multiple messages.
Item {
    id: root

    property string message: ""

    function show(text) {
        root.message = text
        _bubble.visible = true
        _dismissTimer.restart()
    }

    anchors.fill: parent
    z: 5000

    Timer {
        id: _dismissTimer
        interval: 4000
        onTriggered: _bubble.visible = false
    }

    Rectangle {
        id: _bubble
        visible: false
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        width: Math.min(400, root.width - 48)
        height: _label.implicitHeight + 24
        radius: Shape.extraSmall
        color: Color.scheme.inverseSurface

        Text {
            id: _label
            anchors.centerIn: parent
            width: parent.width - 32
            text: root.message
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            color: Color.scheme.inverseOnSurface
            font.family: Type.bodyMedium.family
            font.pixelSize: Type.bodyMedium.size
        }
    }
}
```

- [ ] **Step 2: Register it in `build.rs`**

In `crates/app/build.rs`, find this line (in the QML file list):

```rust
                "qml/components/DecorativeShapesBackground.qml",
                "qml/components/M3Slider.qml",
```

Replace with:

```rust
                "qml/components/DecorativeShapesBackground.qml",
                "qml/components/M3Slider.qml",
                "qml/components/Snackbar.qml",
```

- [ ] **Step 3: Build to verify**

Run: `cargo build -p fm-app`
Expected: `Finished` with no errors (the component compiles even though nothing instantiates it yet).

- [ ] **Step 4: Commit**

```bash
git add crates/app/qml/components/Snackbar.qml crates/app/build.rs
git commit -m "feat(app): add Snackbar QML component"
```

---

### Task 5: Wire `main.qml` to show the Snackbar on `errorOccurred`

**Files:**
- Modify: `crates/app/qml/main.qml`

**Interfaces:**
- Consumes: `fileModel.errorOccurred(message)` signal (Task 1/2/3), `Snackbar.show(text)` (Task 4).

- [ ] **Step 1: Add the Connections and Snackbar instance**

In `crates/app/qml/main.qml`, find the last `Loader` block (`settingsDialogLoader`), which currently ends the `Window`:

```qml
    Loader {
        id: settingsDialogLoader
        anchors.fill: parent
        active: false
        sourceComponent: SettingsDialog {
            fileModel: window.fileListModel
            onClosed: Qt.callLater(() => settingsDialogLoader.active = false)
        }
    }
}
```

Replace the closing `}` with:

```qml
    Loader {
        id: settingsDialogLoader
        anchors.fill: parent
        active: false
        sourceComponent: SettingsDialog {
            fileModel: window.fileListModel
            onClosed: Qt.callLater(() => settingsDialogLoader.active = false)
        }
    }

    Connections {
        target: fileModel
        function onErrorOccurred(message) { snackbar.show(message) }
    }

    Snackbar {
        id: snackbar
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `cargo build -p fm-app`
Expected: `Finished` with no errors. This is the automated verification ceiling for this project (no QML test harness) — the `Connections { target: fileModel; function onErrorOccurred... }` syntax matching the signal's cxx_name is the main thing that could silently fail at runtime instead of build time, so double check the signal name in `file_list_model.rs` reads `#[cxx_name = "errorOccurred"]` exactly.

- [ ] **Step 3: Commit**

```bash
git add crates/app/qml/main.qml
git commit -m "feat(app): show Snackbar on fileModel.errorOccurred"
```

- [ ] **Step 4: Hand off for manual verification**

Tell the user this is ready for interactive testing, since there's no QML test harness in this project (per `feedback-verification-style` — don't launch/screenshot the app yourself). Suggest a couple of concrete ways to trigger a real failure to see the Snackbar:
- Rename a file to a name that collides with an existing directory in the same folder.
- `chmod 000` a file/folder, or navigate to a folder you don't have read access to, then try to delete/duplicate it.
- Select several files, remove your permission on one of them, then delete/duplicate/paste the whole selection — confirms the batch summary message shows a count, not one message per file.
