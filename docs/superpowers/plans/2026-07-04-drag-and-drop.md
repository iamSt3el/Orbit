# Drag-and-Drop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user drag a file/folder onto another folder to move it there, drag files in from another app onto the file view, and drag files out of this app to another app (copy-only).

**Architecture:** Refactor `paste_entry`'s batch copy/move-with-progress logic into a shared `transfer_batch` method, reused by a new `dropPaths` invokable. `FileListItem`/`FileGridItem` become drag sources (real `text/uri-list` mimeData, tagged with an app-internal routing key) and folder-row drop targets. `main.qml` gets one more `DropArea` per view for drops landing on empty space (external-only, imports into the current folder).

**Tech Stack:** Rust (cxx-qt 0.9), QML/Qt Quick `Drag`/`DropArea` API.

## Global Constraints

- Full spec: `docs/superpowers/specs/2026-07-04-drag-and-drop-design.md` — read it if anything below is ambiguous.
- **Drop targets: folder rows only**, plus the file view's own background (external-only, see below). The Sidebar is not a drop target in this plan.
- **Drag-out is copy-only.** No code deletes a source file based on an external app's reported drop outcome.
- **Internal drag is always a move** (no modifier-key/copy variant in this pass).
- **MIME data is always real `text/uri-list`** (`file://` + absolute path, entries joined by `\r\n`) — never a private-only format, so internal and external drops share one handling path.
- **`Drag.keys`** (`["text/uri-list", "application/x-filemanager-internal"]` on our own drag sources) is QML-only routing, never sent to other applications — only `Drag.mimeData` crosses the app boundary.
- **What gets dragged**: the whole current selection if the pressed row is already selected, otherwise just that single row — mirrors the existing right-click "keep selection vs. select just this one" rule already in `FileListItem.qml`/`FileGridItem.qml`.
- **Drop action rule** (folder rows and the background DropArea alike): `isMove = (drop.proposedAction === Qt.MoveAction)`, then `drop.acceptProposedAction()`. One rule for both internal and external drops.
- **Background DropArea rejects our own drags**: if `drop.keys` includes `"application/x-filemanager-internal"`, set `drop.accepted = false` and return — dropping one of our own items into empty space of the folder it's already in is a no-op, not an import.
- **Verification ceiling**: `cargo build -p fm-app` (~2 minutes per run, normal for this crate). Drag-and-drop cannot be exercised by any automated test in this project (no QML test harness, and simulating real OS-level XDND/Wayland events isn't practical here) — every task ends with a manual-verification note, and Task 3 hands off for full interactive testing.

---

### Task 1: Rust — `transfer_batch` refactor, `dropPaths`, `selectedNamesJoined`

**Files:**
- Modify: `crates/app/src/file_list_model.rs`

**Interfaces:**
- Produces: `fn transfer_batch(self: Pin<&mut FileListModel>, sources: Vec<PathBuf>, dest_dir: PathBuf, is_move: bool, verb: &'static str)` — private (not `#[qinvokable]`), used internally by both `paste_entry` and the new `drop_paths`.
- Produces: QML-visible `fileModel.dropPaths(paths: string, destDir: string, isMove: bool)` — `paths` is `\n`-joined absolute filesystem paths (no `file://` prefixes — QML strips those before calling).
- Produces: QML-visible `fileModel.selectedNamesJoined() -> string` — every currently-selected name, `\n`-joined.
- Consumes: nothing new from outside this file — `pluralize_items`, `error_occurred`, `unique_paste_destination`, `fm_core::ops::{path_size, copy_with_progress, move_entry_with_progress}` all already exist here.

- [ ] **Step 1: Add the two new invokable declarations**

In `crates/app/src/file_list_model.rs`, find this block:

```rust
        #[qinvokable]
        #[cxx_name = "singleSelectedName"]
        fn single_selected_name(self: &FileListModel) -> QString;

        #[qinvokable]
        #[cxx_name = "openSelectedEntry"]
        fn open_selected_entry(self: Pin<&mut FileListModel>);
```

Replace it with:

```rust
        #[qinvokable]
        #[cxx_name = "singleSelectedName"]
        fn single_selected_name(self: &FileListModel) -> QString;

        #[qinvokable]
        #[cxx_name = "selectedNamesJoined"]
        fn selected_names_joined(self: &FileListModel) -> QString;

        #[qinvokable]
        #[cxx_name = "openSelectedEntry"]
        fn open_selected_entry(self: Pin<&mut FileListModel>);
```

Then find this block:

```rust
        #[qinvokable]
        #[cxx_name = "pasteEntry"]
        fn paste_entry(self: Pin<&mut FileListModel>);
```

Replace it with:

```rust
        #[qinvokable]
        #[cxx_name = "pasteEntry"]
        fn paste_entry(self: Pin<&mut FileListModel>);

        /// Copies or moves an explicit list of absolute source paths into
        /// destDir — the drag-and-drop counterpart to pasteEntry, sharing
        /// its batch transfer machinery. `paths` is newline-joined (QML
        /// builds this from drop.urls, stripping each file:// prefix
        /// itself before joining, since this file never parses URIs).
        #[qinvokable]
        #[cxx_name = "dropPaths"]
        fn drop_paths(self: Pin<&mut FileListModel>, paths: &QString, dest_dir: &QString, is_move: bool);
```

- [ ] **Step 2: Implement `selected_names_joined`**

Find this method:

```rust
    fn single_selected_name(&self) -> QString {
        if self.selected.len() == 1 {
            QString::from(self.selected.iter().next().unwrap())
        } else {
            QString::from("")
        }
    }
```

Immediately after its closing `}`, add:

```rust

    fn selected_names_joined(&self) -> QString {
        let names: Vec<&str> = self.selected.iter().map(|s| s.as_str()).collect();
        QString::from(&names.join("\n"))
    }
```

- [ ] **Step 3: Extract `transfer_batch` and rewrite `paste_entry` to use it**

Find `paste_entry`'s current full implementation:

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
    }
```

Replace it with:

```rust
    fn paste_entry(mut self: core::pin::Pin<&mut Self>) {
        let sources = self.clipboard_paths.clone();
        if sources.is_empty() {
            return;
        }
        let is_cut = self.clipboard_is_cut;
        let dest_dir = PathBuf::from(self.current_path.to_string());

        // A cut clears the whole clipboard after pasting once; a copy can
        // be pasted repeatedly — same rule as before, now applied via the
        // shared transfer_batch helper (see also dropPaths, which shares
        // this same batch copy/move-with-progress machinery).
        if is_cut {
            self.as_mut().rust_mut().clipboard_paths = Vec::new();
        }

        self.as_mut().transfer_batch(sources, dest_dir, is_cut, "paste");
    }

    fn drop_paths(mut self: core::pin::Pin<&mut Self>, paths: &QString, dest_dir: &QString, is_move: bool) {
        let sources: Vec<PathBuf> = paths.to_string().lines().map(PathBuf::from).collect();
        if sources.is_empty() {
            return;
        }
        let dest = PathBuf::from(dest_dir.to_string());
        let verb = if is_move { "move" } else { "copy" };
        self.as_mut().transfer_batch(sources, dest, is_move, verb);
    }

    /// Shared copy/move-with-progress batch machinery for both pasteEntry
    /// (sources from clipboard_paths) and dropPaths (sources from a
    /// drag-and-drop). `verb` only affects the dev-facing eprintln! label
    /// and the user-facing batch error message (e.g. "paste" keeps
    /// pasteEntry's existing wording; dropPaths passes "move" or "copy").
    fn transfer_batch(
        mut self: core::pin::Pin<&mut Self>,
        sources: Vec<PathBuf>,
        dest_dir: PathBuf,
        is_move: bool,
        verb: &'static str,
    ) {
        // Computed synchronously, up front — one combined denominator for
        // the whole batch (cheap relative to the actual copy), so the
        // "done / total" display starts with a real number even for a
        // multi-item transfer.
        let total: u64 = sources.iter().map(|src| fm_core::ops::path_size(src)).sum();

        self.as_mut().set_is_busy(true);
        self.as_mut().set_busy_label(QString::from(if is_move {
            "Moving…"
        } else {
            "Copying…"
        }));
        self.as_mut().set_transfer_done_bytes(0);
        self.as_mut().set_transfer_total_bytes(total as i64);
        self.as_mut().set_transfer_speed_label(QString::from(""));

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
            let mut failed: usize = 0;
            for src in sources {
                let Some(file_name) = src.file_name().map(|n| n.to_os_string()) else {
                    continue;
                };
                let dest = unique_paste_destination(&dest_dir, std::path::Path::new(&file_name));
                let result = if is_move {
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
                    eprintln!("{verb} failed for {}: {e}", src.display());
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
                        "Couldn't {verb} {}",
                        pluralize_items(failed)
                    )));
                }
            });
        });
    }
```

- [ ] **Step 4: Build to verify**

Run: `cargo build -p fm-app`
Expected: `Finished` with no errors. `dropPaths`/`selectedNamesJoined` aren't called from QML yet (Tasks 2/3 do that) — an unused-from-QML invokable is not a compile error.

- [ ] **Step 5: Run the fm-app test suite to make sure the refactor didn't break anything**

Run: `cargo test -p fm-app`
Expected: `test result: ok. 7 passed; 0 failed` (unchanged from before this task — none of these tests touch `paste_entry`/`transfer_batch`, but this confirms the refactor didn't break compilation of anything nearby).

- [ ] **Step 6: Commit**

```bash
git add crates/app/src/file_list_model.rs
git commit -m "refactor(app): extract transfer_batch, add dropPaths and selectedNamesJoined"
```

---

### Task 2: `FileListItem.qml`/`FileGridItem.qml` — drag source and folder-row drop target

**Files:**
- Modify: `crates/app/qml/components/FileListItem.qml`
- Modify: `crates/app/qml/components/FileGridItem.qml`

**Interfaces:**
- Consumes: `fileModel.selectedNamesJoined()`, `fileModel.entryAbsolutePath(name)` (already exists), `fileModel.dropPaths(paths, destDir, isMove)` (Task 1).

- [ ] **Step 1: Add drag-source properties and threshold-based drag start to `FileListItem.qml`**

Find:

```qml
    signal contextMenuRequested(real x, real y)

    // The containing ListView's model (the FileListModel instance), read via
    // the attached ListView.view property rather than a manually-passed
    // property — more reliable across delegate recycling.
    readonly property var fileModel: ListView.view ? ListView.view.model : null
```

Replace with:

```qml
    signal contextMenuRequested(real x, real y)

    // The containing ListView's model (the FileListModel instance), read via
    // the attached ListView.view property rather than a manually-passed
    // property — more reliable across delegate recycling.
    readonly property var fileModel: ListView.view ? ListView.view.model : null

    // Drag-and-drop: exported as real text/uri-list so external apps (a
    // file browser, the desktop) can accept it too. The second key,
    // "application/x-filemanager-internal", is QML-only routing — Drag.keys
    // is never sent to other applications, only Drag.mimeData is — so
    // main.qml's background DropArea can tell an internal drag apart from
    // a genuinely external one and reject a meaningless drop-into-the-
    // same-folder no-op.
    Drag.active: false
    Drag.dragType: Drag.Automatic
    Drag.supportedActions: Qt.CopyAction | Qt.MoveAction
    Drag.proposedAction: Qt.MoveAction
    Drag.keys: ["text/uri-list", "application/x-filemanager-internal"]
    Drag.onDragFinished: (dropAction) => { root.Drag.active = false }

    // Dragging a row that's already part of the selection drags the whole
    // selection; dragging an unselected row drags just that one item —
    // mirrors the existing right-click rule in rowArea.onClicked below.
    function _startDrag() {
        var names = root.selected ? root.fileModel.selectedNamesJoined().split("\n") : [root.name]
        var uris = names.map((n) => "file://" + root.fileModel.entryAbsolutePath(n))
        root.Drag.mimeData = { "text/uri-list": uris.join("\r\n") }
        root.Drag.active = true
    }
```

- [ ] **Step 2: Add press-then-threshold drag detection to `rowArea`, guard `onClicked`**

Find:

```qml
    MouseArea {
        id: rowArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => {
```

Replace with:

```qml
    MouseArea {
        id: rowArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        property real _pressX: 0
        property real _pressY: 0
        property bool _dragging: false

        onPressed: (mouse) => {
            rowArea._pressX = mouse.x
            rowArea._pressY = mouse.y
            rowArea._dragging = false
        }
        onPositionChanged: (mouse) => {
            if (!rowArea.pressed || rowArea._dragging || !(rowArea.pressedButtons & Qt.LeftButton)) {
                return
            }
            var dx = mouse.x - rowArea._pressX
            var dy = mouse.y - rowArea._pressY
            if (Math.sqrt(dx * dx + dy * dy) < 6) {
                return
            }
            rowArea._dragging = true
            root._startDrag()
        }
        onReleased: {
            rowArea._dragging = false
        }
        onClicked: (mouse) => {
            if (rowArea._dragging) {
                return
            }
```

(The rest of `onClicked`'s body, and `onDoubleClicked` after it, are unchanged — this only adds the early-return guard line and the new handlers above it.)

- [ ] **Step 3: Add the folder-row `DropArea` to `FileListItem.qml`**

Find:

```qml
    Row {
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 12
        spacing: 16
```

Replace with:

```qml
    // Folder rows are drop targets — accepts both our own internal drags
    // (moving an item into a subfolder) and an external file dropped
    // precisely on this row. keys: ["text/uri-list"] deliberately omits
    // our internal marker so both cases match; the drop-action rule
    // (isMove from drop.proposedAction) is identical either way.
    DropArea {
        anchors.fill: parent
        enabled: root.isDir
        keys: ["text/uri-list"]
        onDropped: (drop) => {
            if (!drop.hasUrls) {
                return
            }
            var isMove = drop.proposedAction === Qt.MoveAction
            drop.acceptProposedAction()
            var paths = []
            for (var i = 0; i < drop.urls.length; i++) {
                paths.push(drop.urls[i].toString().replace("file://", ""))
            }
            var destDir = root.fileModel.currentPath + "/" + root.name
            root.fileModel.dropPaths(paths.join("\n"), destDir, isMove)
        }
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 12
        spacing: 16
```

- [ ] **Step 4: Show the existing hover highlight while something is dragged over a folder row too**

Find:

```qml
            Rectangle {
                anchors.fill: parent
                radius: Shape.medium
                color: Qt.alpha(Color.scheme.primary, 0.12)
                opacity: (root.isDir && rowArea.containsMouse) ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            }
```

Replace with:

```qml
            Rectangle {
                anchors.fill: parent
                radius: Shape.medium
                color: Qt.alpha(Color.scheme.primary, 0.12)
                opacity: (root.isDir && rowArea.containsMouse) ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            }

            Rectangle {
                // Same tonal highlight as the hover case above, but for a
                // drag hovering over this folder mid-drop — the DropArea
                // is declared further down in this file (after the Row),
                // so this binds to it by id rather than duplicating the
                // Rectangle.
                anchors.fill: parent
                radius: Shape.medium
                color: Qt.alpha(Color.scheme.primary, 0.12)
                opacity: folderDropArea.containsDrag ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            }
```

Now give the `DropArea` added in Step 3 an id so this binds — find the `DropArea { ... }` block added in Step 3 and change its first line from `DropArea {` to `DropArea { id: folderDropArea`, i.e.:

```qml
    DropArea {
        id: folderDropArea
        anchors.fill: parent
        enabled: root.isDir
```

- [ ] **Step 5: Repeat Steps 1-4 for `FileGridItem.qml`**

`FileGridItem.qml` has the same shapes with different ids (`cellArea` instead of `rowArea`, `card` wrapping the tile). Find:

```qml
    signal contextMenuRequested(real x, real y)

    readonly property var fileModel: GridView.view ? GridView.view.model : null
```

Replace with:

```qml
    signal contextMenuRequested(real x, real y)

    readonly property var fileModel: GridView.view ? GridView.view.model : null

    // See FileListItem.qml's matching properties/function for why.
    Drag.active: false
    Drag.dragType: Drag.Automatic
    Drag.supportedActions: Qt.CopyAction | Qt.MoveAction
    Drag.proposedAction: Qt.MoveAction
    Drag.keys: ["text/uri-list", "application/x-filemanager-internal"]
    Drag.onDragFinished: (dropAction) => { root.Drag.active = false }

    function _startDrag() {
        var names = root.selected ? root.fileModel.selectedNamesJoined().split("\n") : [root.name]
        var uris = names.map((n) => "file://" + root.fileModel.entryAbsolutePath(n))
        root.Drag.mimeData = { "text/uri-list": uris.join("\r\n") }
        root.Drag.active = true
    }
```

Find:

```qml
        MouseArea {
            id: cellArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (mouse) => {
```

Replace with:

```qml
        MouseArea {
            id: cellArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            property real _pressX: 0
            property real _pressY: 0
            property bool _dragging: false

            onPressed: (mouse) => {
                cellArea._pressX = mouse.x
                cellArea._pressY = mouse.y
                cellArea._dragging = false
            }
            onPositionChanged: (mouse) => {
                if (!cellArea.pressed || cellArea._dragging || !(cellArea.pressedButtons & Qt.LeftButton)) {
                    return
                }
                var dx = mouse.x - cellArea._pressX
                var dy = mouse.y - cellArea._pressY
                if (Math.sqrt(dx * dx + dy * dy) < 6) {
                    return
                }
                cellArea._dragging = true
                root._startDrag()
            }
            onReleased: {
                cellArea._dragging = false
            }
            onClicked: (mouse) => {
                if (cellArea._dragging) {
                    return
                }
```

(The rest of `onClicked` and `onDoubleClicked` are unchanged.)

Find:

```qml
                Rectangle {
                    anchors.fill: parent
                    radius: Shape.medium
                    color: Qt.alpha(Color.scheme.primary, 0.12)
                    opacity: (root.isDir && cellArea.containsMouse) ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                }
```

Replace with:

```qml
                Rectangle {
                    anchors.fill: parent
                    radius: Shape.medium
                    color: Qt.alpha(Color.scheme.primary, 0.12)
                    opacity: (root.isDir && cellArea.containsMouse) ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                }

                Rectangle {
                    // See FileListItem.qml's matching highlight for why
                    // this exists alongside the hover-highlight above.
                    anchors.fill: parent
                    radius: Shape.medium
                    color: Qt.alpha(Color.scheme.primary, 0.12)
                    opacity: folderDropArea.containsDrag ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                }
```

Find the closing of the `card` Item's `MouseArea { id: cellArea ... }` block (the final `}` that closes it, immediately before `card`'s own closing `}`) and add the `DropArea` as a new sibling inside `card`, right after that `MouseArea`'s closing brace:

```qml
        }

        DropArea {
            id: folderDropArea
            anchors.fill: parent
            enabled: root.isDir
            keys: ["text/uri-list"]
            onDropped: (drop) => {
                if (!drop.hasUrls) {
                    return
                }
                var isMove = drop.proposedAction === Qt.MoveAction
                drop.acceptProposedAction()
                var paths = []
                for (var i = 0; i < drop.urls.length; i++) {
                    paths.push(drop.urls[i].toString().replace("file://", ""))
                }
                var destDir = root.fileModel.currentPath + "/" + root.name
                root.fileModel.dropPaths(paths.join("\n"), destDir, isMove)
            }
        }
    }
}
```

(That final `}\n}` closes `card` and then the root `Item` — this `DropArea` is `card`'s last child, added right after `cellArea`.)

- [ ] **Step 6: Build to verify**

Run: `cargo build -p fm-app`
Expected: `Finished` with no errors.

- [ ] **Step 7: Commit**

```bash
git add crates/app/qml/components/FileListItem.qml crates/app/qml/components/FileGridItem.qml
git commit -m "feat(app): drag source and folder-row drop target for file rows/tiles"
```

---

### Task 3: `main.qml` — background `DropArea` for external drag-in, manual verification handoff

**Files:**
- Modify: `crates/app/qml/main.qml`

**Interfaces:**
- Consumes: `fileModel.dropPaths(paths, destDir, isMove)` (Task 1).

- [ ] **Step 1: Add the background `DropArea` to the list view**

Find:

```qml
                                Rectangle {
                                    id: listSelectionRect
                                    visible: false
                                    color: Qt.alpha(Color.scheme.primary, 0.16)
                                    border.width: 1
                                    border.color: Color.scheme.primary
                                }

                                ScrollBar {
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.rightMargin: -12
                                    flickable: listView
                                }
                            }
                        }

                        Component {
                            id: gridComponent
```

Replace with:

```qml
                                Rectangle {
                                    id: listSelectionRect
                                    visible: false
                                    color: Qt.alpha(Color.scheme.primary, 0.16)
                                    border.width: 1
                                    border.color: Color.scheme.primary
                                }

                                // Accepts drops landing on empty space (not on a
                                // specific folder row, which FileListItem's own
                                // DropArea already handles) — imports into the
                                // current folder. Rejects our own internal drags
                                // (dropping one of our own items back into the
                                // folder it's already in is a no-op, not an
                                // import); a genuinely external drop never
                                // carries that key.
                                DropArea {
                                    anchors.fill: parent
                                    keys: ["text/uri-list"]
                                    onDropped: (drop) => {
                                        if (!drop.hasUrls) {
                                            return
                                        }
                                        if (drop.keys.indexOf("application/x-filemanager-internal") !== -1) {
                                            drop.accepted = false
                                            return
                                        }
                                        var isMove = drop.proposedAction === Qt.MoveAction
                                        drop.acceptProposedAction()
                                        var paths = []
                                        for (var i = 0; i < drop.urls.length; i++) {
                                            paths.push(drop.urls[i].toString().replace("file://", ""))
                                        }
                                        fileModel.dropPaths(paths.join("\n"), fileModel.currentPath, isMove)
                                    }
                                }

                                ScrollBar {
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.rightMargin: -12
                                    flickable: listView
                                }
                            }
                        }

                        Component {
                            id: gridComponent
```

- [ ] **Step 2: Add the matching background `DropArea` to the grid view**

Find:

```qml
                                Rectangle {
                                    id: gridSelectionRect
                                    visible: false
                                    color: Qt.alpha(Color.scheme.primary, 0.16)
                                    border.width: 1
                                    border.color: Color.scheme.primary
                                }

                                ScrollBar {
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.rightMargin: -12
                                    flickable: gridView
                                }
                            }
                        }
```

Replace with:

```qml
                                Rectangle {
                                    id: gridSelectionRect
                                    visible: false
                                    color: Qt.alpha(Color.scheme.primary, 0.16)
                                    border.width: 1
                                    border.color: Color.scheme.primary
                                }

                                // See the matching comment on listView's DropArea.
                                DropArea {
                                    anchors.fill: parent
                                    keys: ["text/uri-list"]
                                    onDropped: (drop) => {
                                        if (!drop.hasUrls) {
                                            return
                                        }
                                        if (drop.keys.indexOf("application/x-filemanager-internal") !== -1) {
                                            drop.accepted = false
                                            return
                                        }
                                        var isMove = drop.proposedAction === Qt.MoveAction
                                        drop.acceptProposedAction()
                                        var paths = []
                                        for (var i = 0; i < drop.urls.length; i++) {
                                            paths.push(drop.urls[i].toString().replace("file://", ""))
                                        }
                                        fileModel.dropPaths(paths.join("\n"), fileModel.currentPath, isMove)
                                    }
                                }

                                ScrollBar {
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.rightMargin: -12
                                    flickable: gridView
                                }
                            }
                        }
```

- [ ] **Step 3: Build to verify**

Run: `cargo build -p fm-app`
Expected: `Finished` with no errors.

- [ ] **Step 4: Commit**

```bash
git add crates/app/qml/main.qml
git commit -m "feat(app): background DropArea for external drag-in"
```

- [ ] **Step 5: Hand off for manual verification**

Tell the user this is ready for interactive testing (no QML test harness in this project — don't launch/screenshot the app yourself, per this project's established verification style). Suggest concretely checking:
- Drag a file onto a folder row in the same view — it moves there (list view and grid view both).
- Select 3 files, drag one of the selected ones onto a folder — all 3 move.
- Drag a file from this app's window out onto another app (a file browser, a desktop) — it's copied there, and still exists here afterward (copy-only, confirms the source was never deleted).
- Drag a file from another app (a file browser, the desktop) into this app's file view background — it's imported (copied, or moved if the source app's drag proposed a move) into the current folder.
- Drag a file from another app directly onto a specific folder row in this app — it lands inside that subfolder, not the current folder.
- Drag one of this app's own items and drop it on empty background space of the same folder it's already in — nothing happens (no duplicate, no error).
- While dragging over a folder row, confirm the same tonal hover highlight that appears on mouse-hover also appears during the drag.
- If a drop lands exactly on the boundary between a folder row and empty background space, confirm which DropArea wins matches the intended target (this is the one behavior that can't be reasoned about from the code alone and needs an eyes-on check).
