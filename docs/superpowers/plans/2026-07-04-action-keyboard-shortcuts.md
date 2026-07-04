# Action Keyboard Shortcuts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Delete, F2, Ctrl+C/X/V, Enter, Backspace/Alt+Left, and Escape keyboard shortcuts to the file manager, plus fix the 7 popups/dialogs that currently don't close on Escape at all.

**Architecture:** Two small Rust invokables added to the existing cxx-qt bridge (`FileListModel`) for the two actions that need Rust-side selection/entry data (`openSelectedEntry`, `singleSelectedName`). Seven QML popup components each get `forceActiveFocus()` on open plus a `Keys.onEscapePressed` handler, mirroring the pattern `NewFolderDialog`/`RenameDialog` already use. `main.qml` gets one new guard property (`anyPopupOpen`) and 8 new `Shortcut` items, mirroring the existing Ctrl+A `Shortcut`.

**Tech Stack:** Rust (cxx-qt 0.9), QML/Qt Quick `Shortcut`/`Keys` API.

## Global Constraints

- Full spec: `docs/superpowers/specs/2026-07-04-action-keyboard-shortcuts-design.md` — read it if anything below is ambiguous.
- **Arrow-key navigation between items is out of scope** for this plan — tracked separately (it needs a new keyboard-focus-cursor concept this app doesn't have today).
- **Guard formula** (exact): `anyPopupOpen` is true when any of these 10 Loader ids in `main.qml` has `.active === true`: `contextMenuLoader`, `newFolderDialogLoader`, `viewOptionsMenuLoader`, `itemContextMenuLoader`, `renameDialogLoader`, `propertiesDialogLoader`, `deleteConfirmDialogLoader`, `trashContextMenuLoader`, `emptyTrashConfirmDialogLoader`, `settingsDialogLoader`. Every new `Shortcut`'s `onActivated` checks `!window.anyPopupOpen` first and returns early if it's `true` — except Escape, which has the dual behavior described in Task 3.
- **Popup Escape fix**: each of `ConfirmDialog.qml`, `PropertiesDialog.qml`, `SettingsDialog.qml`, `ItemContextMenu.qml`, `ContextMenu.qml`, `TrashContextMenu.qml`, `ViewOptionsMenu.qml` gets `root.forceActiveFocus()` added at the end of its `open(...)`/`popup(...)` function, and `Keys.onEscapePressed: root.close()` added to its root `Item`.
- **Use `StandardKey.*`** where Qt defines one (`StandardKey.Delete`, `StandardKey.Copy`, `StandardKey.Cut`, `StandardKey.Paste`, `StandardKey.Cancel` for Escape) rather than hardcoded key strings — matches the existing `StandardKey.SelectAll` Ctrl+A shortcut.
- **New Rust invokables** on `FileListModel` (exact names/signatures): `singleSelectedName() -> QString` (cxx_name `singleSelectedName`) and `openSelectedEntry()` (cxx_name `openSelectedEntry`) — both reuse the existing `navigate`/`open_entry` methods internally rather than duplicating logic.
- **Verification ceiling**: `cargo build -p fm-app` (cxx-qt codegen + C++ build + qmlcachegen, ~2 minutes per run — normal for this crate, not a hang). No QML test harness exists in this project; interactive verification (pressing each shortcut, confirming Escape closes each popup, confirming shortcuts are inert while a popup is open) is done by the user themselves.

---

### Task 1: `singleSelectedName` and `openSelectedEntry` Rust invokables

**Files:**
- Modify: `crates/app/src/file_list_model.rs`

**Interfaces:**
- Produces: `fn single_selected_name(self: &FileListModel) -> QString` — QML-visible as `fileModel.singleSelectedName()`, returns the one selected entry's name, or an empty `QString` if the selection count isn't exactly 1.
- Produces: `fn open_selected_entry(self: Pin<&mut FileListModel>)` — QML-visible as `fileModel.openSelectedEntry()`. No-ops unless exactly one entry is selected; navigates into it if it's a folder, opens it otherwise.

- [ ] **Step 1: Add the two invokable declarations**

In `crates/app/src/file_list_model.rs`, find this block (the selection-related invokables):

```rust
        #[qinvokable]
        #[cxx_name = "selectedCount"]
        fn selected_count(self: &FileListModel) -> i32;
    }
```

Replace it with:

```rust
        #[qinvokable]
        #[cxx_name = "selectedCount"]
        fn selected_count(self: &FileListModel) -> i32;

        #[qinvokable]
        #[cxx_name = "singleSelectedName"]
        fn single_selected_name(self: &FileListModel) -> QString;

        #[qinvokable]
        #[cxx_name = "openSelectedEntry"]
        fn open_selected_entry(self: Pin<&mut FileListModel>);
    }
```

- [ ] **Step 2: Implement both methods**

Find this method in the same file:

```rust
    fn selected_count(&self) -> i32 {
        self.selected.len() as i32
    }
```

Immediately after its closing `}`, add:

```rust

    fn single_selected_name(&self) -> QString {
        if self.selected.len() == 1 {
            QString::from(self.selected.iter().next().unwrap())
        } else {
            QString::from("")
        }
    }

    fn open_selected_entry(mut self: core::pin::Pin<&mut Self>) {
        if self.selected.len() != 1 {
            return;
        }
        let name = self.selected.iter().next().unwrap().clone();
        let Some(entry) = self.entries.iter().find(|e| e.name == name) else {
            return;
        };
        if entry.is_dir {
            let path = QString::from(&format!("{}/{}", self.current_path.to_string(), name));
            self.as_mut().navigate(&path);
        } else {
            let name_q = QString::from(&name);
            self.as_mut().open_entry(&name_q);
        }
    }
```

- [ ] **Step 3: Build to verify**

Run: `cargo build -p fm-app`
Expected: `Finished` with no errors. (These two methods aren't unit-testable in isolation — like every other invokable in this file, they're QObject methods requiring the cxx-qt/Qt runtime, not plain Rust functions. A clean build is this task's verification, consistent with how the rest of this file's invokables are verified.)

- [ ] **Step 4: Commit**

```bash
git add crates/app/src/file_list_model.rs
git commit -m "feat(app): add singleSelectedName and openSelectedEntry invokables"
```

---

### Task 2: Fix Escape-to-close on the 7 focus-less popups

**Files:**
- Modify: `crates/app/qml/components/ConfirmDialog.qml`
- Modify: `crates/app/qml/components/PropertiesDialog.qml`
- Modify: `crates/app/qml/components/SettingsDialog.qml`
- Modify: `crates/app/qml/components/ItemContextMenu.qml`
- Modify: `crates/app/qml/components/ContextMenu.qml`
- Modify: `crates/app/qml/components/TrashContextMenu.qml`
- Modify: `crates/app/qml/components/ViewOptionsMenu.qml`

**Interfaces:**
- Consumes: nothing from Task 1.
- Produces: nothing consumed by Task 3 directly — Task 3's Escape shortcut relies on this task's `Keys.onEscapePressed` handlers having first claim on the Escape key while a popup is focused, but doesn't call anything these files export.

Same two-part edit repeated across all 7 files: add `root.forceActiveFocus()` at the end of the function that shows the popup, and add a `Keys.onEscapePressed: root.close()` handler to the root `Item`.

- [ ] **Step 1: `ConfirmDialog.qml`**

Replace:

```qml
    function open(msg) {
        root.message = msg
        visible = true
    }

    function close() {
        visible = false
        root.closed()
    }
```

with:

```qml
    function open(msg) {
        root.message = msg
        visible = true
        root.forceActiveFocus()
    }

    function close() {
        visible = false
        root.closed()
    }

    Keys.onEscapePressed: root.close()
```

- [ ] **Step 2: `PropertiesDialog.qml`**

Replace:

```qml
    function open(name, isDir, size, modified, mimeType, permissions) {
        root.entryName = name
        root.entryIsDir = isDir
        root.entrySize = size
        root.entryModified = modified
        root.entryMimeType = mimeType
        root.entryPermissions = permissions
        visible = true
    }

    function close() {
        visible = false
        root.closed()
    }
```

with:

```qml
    function open(name, isDir, size, modified, mimeType, permissions) {
        root.entryName = name
        root.entryIsDir = isDir
        root.entrySize = size
        root.entryModified = modified
        root.entryMimeType = mimeType
        root.entryPermissions = permissions
        visible = true
        root.forceActiveFocus()
    }

    function close() {
        visible = false
        root.closed()
    }

    Keys.onEscapePressed: root.close()
```

- [ ] **Step 3: `SettingsDialog.qml`**

Replace:

```qml
    function open() {
        if (root.fileModel) {
            root.resumeLastPath = root.fileModel.resumeLastPath
        }
        visible = true
    }

    function close() {
        visible = false
        root.closed()
    }
```

with:

```qml
    function open() {
        if (root.fileModel) {
            root.resumeLastPath = root.fileModel.resumeLastPath
        }
        visible = true
        root.forceActiveFocus()
    }

    function close() {
        visible = false
        root.closed()
    }

    Keys.onEscapePressed: root.close()
```

- [ ] **Step 4: `ItemContextMenu.qml`**

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
    }

    function close() {
        visible = false
        root.closed()
    }
```

with:

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

    function close() {
        visible = false
        root.closed()
    }

    Keys.onEscapePressed: root.close()
```

- [ ] **Step 5: `ContextMenu.qml`**

Replace:

```qml
    function popup(x, y) {
        menu.x = Math.min(x, root.width - menu.width)
        menu.y = Math.min(y, root.height - menu.height)
        visible = true
    }

    function close() {
        visible = false
        root.closed()
    }
```

with:

```qml
    function popup(x, y) {
        menu.x = Math.min(x, root.width - menu.width)
        menu.y = Math.min(y, root.height - menu.height)
        visible = true
        root.forceActiveFocus()
    }

    function close() {
        visible = false
        root.closed()
    }

    Keys.onEscapePressed: root.close()
```

- [ ] **Step 6: `TrashContextMenu.qml`**

Replace:

```qml
    function popup(x, y) {
        menu.x = Math.min(x, root.width - menu.width)
        menu.y = Math.min(y, root.height - menu.height)
        visible = true
    }

    function close() {
        visible = false
        root.closed()
    }
```

with:

```qml
    function popup(x, y) {
        menu.x = Math.min(x, root.width - menu.width)
        menu.y = Math.min(y, root.height - menu.height)
        visible = true
        root.forceActiveFocus()
    }

    function close() {
        visible = false
        root.closed()
    }

    Keys.onEscapePressed: root.close()
```

- [ ] **Step 7: `ViewOptionsMenu.qml`**

Replace:

```qml
    function popup(x, y) {
        menu.x = Math.min(x, root.width - menu.width)
        menu.y = Math.min(y, root.height - menu.height)
        visible = true
    }

    function close() {
        visible = false
        root.closed()
    }
```

with:

```qml
    function popup(x, y) {
        menu.x = Math.min(x, root.width - menu.width)
        menu.y = Math.min(y, root.height - menu.height)
        visible = true
        root.forceActiveFocus()
    }

    function close() {
        visible = false
        root.closed()
    }

    Keys.onEscapePressed: root.close()
```

- [ ] **Step 8: Build to verify**

Run: `cargo build -p fm-app`
Expected: `Finished` with no errors.

- [ ] **Step 9: Commit**

```bash
git add crates/app/qml/components/ConfirmDialog.qml crates/app/qml/components/PropertiesDialog.qml crates/app/qml/components/SettingsDialog.qml crates/app/qml/components/ItemContextMenu.qml crates/app/qml/components/ContextMenu.qml crates/app/qml/components/TrashContextMenu.qml crates/app/qml/components/ViewOptionsMenu.qml
git commit -m "fix(app): close on Escape for the 7 popups that didn't"
```

---

### Task 3: `anyPopupOpen` guard and the 8 new `Shortcut` items in `main.qml`

**Files:**
- Modify: `crates/app/qml/main.qml`

**Interfaces:**
- Consumes: `fileModel.singleSelectedName()`, `fileModel.openSelectedEntry()` (Task 1); relies on Task 2's `Keys.onEscapePressed` handlers claiming the Escape key first while a popup has focus, so this task's own Escape shortcut only needs to handle the no-popup-open case.
- Consumes existing invokables already present before this plan: `fileModel.selectedCount()`, `fileModel.deleteSelection()`, `fileModel.copySelection()`, `fileModel.cutSelection()`, `fileModel.pasteEntry()`, `fileModel.clearSelection()`, `fileModel.navigate(path)`, `window.parentPath(path)`, `window.openRenameDialog(name)`.

- [ ] **Step 1: Add the guard property and 8 `Shortcut` items**

In `crates/app/qml/main.qml`, find the existing Ctrl+A shortcut:

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

Immediately after its closing `}`, add:

```qml

    // True while any popup/dialog/menu Loader is active — every shortcut
    // below no-ops while this is true, so e.g. Delete can't act on the
    // background selection while Properties or a context menu is showing
    // on top of it. Checked here (rather than in each Loader individually)
    // so there's one place to update if a new popup is added later.
    readonly property bool anyPopupOpen:
        contextMenuLoader.active || newFolderDialogLoader.active ||
        viewOptionsMenuLoader.active || itemContextMenuLoader.active ||
        renameDialogLoader.active || propertiesDialogLoader.active ||
        deleteConfirmDialogLoader.active || trashContextMenuLoader.active ||
        emptyTrashConfirmDialogLoader.active || settingsDialogLoader.active

    Shortcut {
        sequence: StandardKey.Delete
        onActivated: {
            if (window.anyPopupOpen) return
            if (fileModel.selectedCount() > 0) {
                fileModel.deleteSelection()
            }
        }
    }

    Shortcut {
        sequence: "F2"
        onActivated: {
            if (window.anyPopupOpen) return
            if (fileModel.selectedCount() === 1) {
                window.openRenameDialog(fileModel.singleSelectedName())
            }
        }
    }

    Shortcut {
        sequence: StandardKey.Copy
        onActivated: {
            if (window.anyPopupOpen) return
            fileModel.copySelection()
        }
    }

    Shortcut {
        sequence: StandardKey.Cut
        onActivated: {
            if (window.anyPopupOpen) return
            fileModel.cutSelection()
        }
    }

    Shortcut {
        sequence: StandardKey.Paste
        onActivated: {
            if (window.anyPopupOpen) return
            fileModel.pasteEntry()
        }
    }

    Shortcut {
        sequences: ["Return", "Enter"]
        onActivated: {
            if (window.anyPopupOpen) return
            fileModel.openSelectedEntry()
        }
    }

    Shortcut {
        sequences: ["Backspace", "Alt+Left"]
        onActivated: {
            if (window.anyPopupOpen) return
            if (fileModel.currentPath !== "/") {
                fileModel.navigate(window.parentPath(fileModel.currentPath))
            }
        }
    }

    Shortcut {
        sequence: StandardKey.Cancel
        onActivated: {
            if (!window.anyPopupOpen) {
                fileModel.clearSelection()
            }
        }
    }
```

- [ ] **Step 2: Build to verify**

Run: `cargo build -p fm-app`
Expected: `Finished` with no errors. This is the main risk point for a typo in a Loader id inside `anyPopupOpen` (a wrong id would be a QML reference error caught at this build step, not silently ignored) — double check the build output has no QML warnings about unknown properties.

- [ ] **Step 3: Commit**

```bash
git add crates/app/qml/main.qml
git commit -m "feat(app): add Delete/F2/Ctrl+C/X/V/Enter/Backspace/Escape shortcuts"
```

- [ ] **Step 4: Hand off for manual verification**

Tell the user this is ready for interactive testing (no QML test harness in this project — don't launch/screenshot the app yourself, per this project's established verification style). Suggest concretely checking:
- Select one or more files, press Delete — moved to trash.
- Select exactly one file, press F2 — rename dialog opens pre-filled.
- Select a file, Ctrl+C, navigate elsewhere, Ctrl+V — pastes a copy.
- Select exactly one folder, press Enter — navigates in; select exactly one file, press Enter — opens it.
- Press Backspace, then Alt+Left — both go up a directory level.
- Open Properties (or any of the other 6 popups) and press Escape — it closes. Press Escape again with nothing open — clears the current selection.
- Open any popup, then press Delete/Ctrl+C/F2 — nothing should happen until the popup is closed.
