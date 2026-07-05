# Component Upgrades Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement UI/UX roadmap items 2, 10, 11 — FAB menu with New folder/New file/Paste here, split button for view options, selected-tile corner morph — per `docs/superpowers/specs/2026-07-05-component-upgrades-design.md`.

**Architecture:** New fm-core `create_file` op + `createFile` bridge invokable with `UndoOp::CreateFile` (mirrors `CreateFolder`). Three new QML components (`NewFileDialog`, `FabMenu`, `SplitButton`); `TopAppBar`'s right side swaps two controls for the split button; `FileGridItem` gains one radius `Behavior`.

**Tech Stack:** Rust + Tokio (`fm-core`), cxx-qt bridge (`fm-app`), QML on plain Qt Quick primitives, vendored `ShapeCanvas`/`material-shapes.js`, token singletons.

## Global Constraints

- Motion rule: everything in this slice is component-level state change — `SpringAnimation`, never bezier pairs.
- QML components are hand-built from primitives — never Qt Quick Controls.
- Every new `.qml` file must be registered in `crates/app/build.rs`.
- fm-core tests live in `crates/core/tests/` (external files), never inline `#[cfg(test)]` in `src/`.
- Bind model references as `window.fileListModel` on any component declaring its own `property var fileModel`.
- **Correction over the spec:** FabMenu must NOT declare its own `StandardKey.Cancel` Shortcut — two enabled shortcuts on the same sequence are ambiguous in Qt and neither fires. Esc-dismiss is wired into main.qml's existing Cancel shortcut instead (Task 4).
- Verification ceiling: `cargo build -p fm-app` + `cargo test -p fm-app` + `cargo test -p fm-core`. Do NOT launch the GUI — the user verifies visually.
- Commit after every task.

---

### Task 1: `fm_core::ops::create_file` (TDD)

**Files:**
- Modify: `crates/core/src/ops.rs` (directly after `create_folder`, ~line 39)
- Test: `crates/core/tests/ops.rs`

**Interfaces:**
- Produces: `pub async fn create_file(parent: &Path, name: &str) -> io::Result<PathBuf>` — creates an empty file, errors (AlreadyExists) if the name exists. Task 2's bridge invokable calls it.

- [ ] **Step 1: Write the failing tests**

In `crates/core/tests/ops.rs`, directly after the `create_folder_makes_a_new_directory` test, add:

```rust
#[tokio::test]
async fn create_file_makes_a_new_empty_file() {
    let dir = tempdir().unwrap();

    let created = ops::create_file(dir.path(), "notes.txt").await.unwrap();

    assert!(created.is_file());
    assert_eq!(created, dir.path().join("notes.txt"));
    assert_eq!(fs::metadata(&created).unwrap().len(), 0);
}

#[tokio::test]
async fn create_file_fails_if_the_name_already_exists() {
    let dir = tempdir().unwrap();
    fs::write(dir.path().join("notes.txt"), b"keep me").unwrap();

    let result = ops::create_file(dir.path(), "notes.txt").await;

    assert!(result.is_err());
    assert_eq!(
        fs::read_to_string(dir.path().join("notes.txt")).unwrap(),
        "keep me"
    );
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cargo test -p fm-core --test ops create_file`
Expected: FAIL to compile — `cannot find function create_file in module ops`.

- [ ] **Step 3: Implement the op**

In `crates/core/src/ops.rs`, directly after the `create_folder` function, add:

```rust
pub async fn create_file(parent: &Path, name: &str) -> io::Result<PathBuf> {
    let target = parent.join(name);
    // create_new: errors with AlreadyExists instead of truncating an
    // existing file — the same never-clobber contract create_folder gets
    // from create_dir failing on an existing directory.
    tokio::fs::File::options()
        .write(true)
        .create_new(true)
        .open(&target)
        .await?;
    Ok(target)
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cargo test -p fm-core --test ops`
Expected: PASS, including both new tests.

- [ ] **Step 5: Commit**

```bash
git add crates/core/src/ops.rs crates/core/tests/ops.rs
git commit -m "feat(core): create_file op with never-clobber contract"
```

---

### Task 2: `createFile` invokable + `UndoOp::CreateFile`

**Files:**
- Modify: `crates/app/src/file_list_model.rs` (bridge invokable block holding `createFolder` ~line 175; `create_folder` impl ~line 977; `enum UndoOp` ~line 2292; `describe()` ~line 2320; `execute_undo` CreateFolder arm ~line 2027; `undo_journal_tests` module)

**Interfaces:**
- Consumes: `fm_core::ops::create_file` (Task 1).
- Produces: QML-callable `fileModel.createFile(name)` — Task 3's NewFileDialog wiring calls it. Undo trashes the created file.

- [ ] **Step 1: Declare the invokable**

In the bridge `unsafe extern "RustQt"` block, directly under the `createFolder` declaration (`#[cxx_name = "createFolder"] fn create_folder(...)`), add:

```rust
        #[qinvokable]
        #[cxx_name = "createFile"]
        fn create_file(self: Pin<&mut FileListModel>, name: &QString);
```

- [ ] **Step 2: Add the UndoOp variant and its arms**

In `enum UndoOp`, directly under the `CreateFolder { path: PathBuf },` variant, add:

```rust
    /// Undo moves the created file to Trash.
    CreateFile { path: PathBuf },
```

In `describe()`, directly under the `UndoOp::CreateFolder` arm, add:

```rust
            UndoOp::CreateFile { path } => format!("Created file \"{}\"", leaf(path)),
```

In `execute_undo`, directly under the full `UndoOp::CreateFolder { path } => match ... },` arm, add:

```rust
        UndoOp::CreateFile { path } => match fm_core::trash::move_to_trash(&path).await {
            Ok(_) => (Some(UndoOp::CreateFile { path }), 0),
            Err(e) => {
                eprintln!("undo create-file failed for {}: {e}", path.display());
                (None, 1)
            }
        },
```

- [ ] **Step 3: Implement the invokable**

Directly after the `create_folder` method impl, add:

```rust
    fn create_file(mut self: core::pin::Pin<&mut Self>, name: &QString) {
        let current = PathBuf::from(self.current_path.to_string());
        match runtime().block_on(fm_core::ops::create_file(&current, &name.to_string())) {
            Ok(path) => {
                let op = UndoOp::CreateFile { path };
                let desc = op.describe();
                self.as_mut().rust_mut().journal.record(op);
                self.as_mut().operation_completed(QString::from(&desc), true);
            }
            Err(e) => {
                eprintln!("create_file failed: {e}");
                self.as_mut()
                    .error_occurred(QString::from(&format!("Couldn't create file: {e}")));
            }
        }
        self.as_mut().refresh_entries_diff();
    }
```

- [ ] **Step 4: Cover the new variant in the describe test**

In the `undo_journal_tests` module's `describes_each_operation_kind` test, alongside the existing `UndoOp::CreateFolder` assertion, add (match the existing assertions' exact construction style — if they build paths with `PathBuf::from`, do the same):

```rust
        assert_eq!(
            UndoOp::CreateFile { path: PathBuf::from("/tmp/x/notes.txt") }.describe(),
            "Created file \"notes.txt\""
        );
```

- [ ] **Step 5: Build and test**

Run: `cargo build -p fm-app && cargo test -p fm-app`
Expected: build succeeds; all tests pass including the extended describe test.

- [ ] **Step 6: Commit**

```bash
git add crates/app/src/file_list_model.rs
git commit -m "feat(app): createFile invokable with trash-on-undo"
```

---

### Task 3: NewFileDialog + main.qml plumbing

**Files:**
- Create: `crates/app/qml/components/NewFileDialog.qml`
- Modify: `crates/app/build.rs` (qml_files list, after `"qml/components/EmptyState.qml",`)
- Modify: `crates/app/qml/main.qml` (popup helpers ~line 110; `anyPopupOpen` ~line 210; dialog Loaders at the bottom, after `newFolderDialogLoader`)

**Interfaces:**
- Consumes: `fileModel.createFile(name)` (Task 2).
- Produces: `window.openNewFileDialog()` — Task 4's FabMenu wiring calls it. `newFileDialogLoader` participates in `anyPopupOpen`.

- [ ] **Step 1: Create `crates/app/qml/components/NewFileDialog.qml`**

A clone of `NewFolderDialog.qml` with file wording (kept separate rather than parameterized — the two may diverge with extension hints/templates later):

```qml
import QtQuick
import com.filemanager.app 1.0

// A minimal custom modal dialog (no Qt Quick Controls Dialog) for entering
// a new file name — NewFolderDialog's file-flavored twin, opened from the
// FAB menu.
Item {
    id: root

    signal accepted(string name)
    // See ContextMenu.qml — lets the Loader wrapping this component tear
    // the instance down once it hides.
    signal closed

    anchors.fill: parent
    visible: false
    z: 2000

    function open() {
        nameInput.text = ""
        visible = true
        nameInput.forceActiveFocus()
    }

    function close() {
        visible = false
        root.closed()
    }

    Rectangle {
        anchors.fill: parent
        color: Color.scheme.surface
        opacity: 0.4

        MouseArea {
            // See ItemContextMenu.qml — must accept every button and track
            // hover so nothing underneath can still be interacted with
            // while this dialog is open.
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.AllButtons
            onClicked: root.close()
        }
    }

    Rectangle {
        id: dialog
        width: 320
        height: _column.implicitHeight + 40
        radius: Shape.extraLarge
        color: Elevation.surfaceAt(3)
        anchors.centerIn: parent

        Column {
            id: _column
            anchors.fill: parent
            anchors.margins: 20
            spacing: 16

            Text {
                text: "New file"
                color: Color.scheme.surfaceText
                font.family: Type.titleMedium.family
                font.weight: Type.titleMedium.weight
                font.pixelSize: Type.titleMedium.size
            }

            Rectangle {
                width: parent.width
                height: 44
                radius: Shape.small
                color: Color.scheme.surfaceContainerHighest
                border.width: nameInput.activeFocus ? 2 : 1
                border.color: nameInput.activeFocus ? Color.scheme.primary : Color.scheme.outline

                Behavior on border.width { NumberAnimation { duration: Motion.standard.duration } }

                TextInput {
                    id: nameInput
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    color: Color.scheme.surfaceText
                    font.family: Type.bodyLarge.family
                    font.pixelSize: Type.bodyLarge.size
                    clip: true

                    Keys.onReturnPressed: confirmButton.clicked()
                    Keys.onEscapePressed: root.close()
                }
            }

            Row {
                anchors.right: parent.right
                spacing: 8

                Button {
                    variant: "text"
                    text: "Cancel"
                    onClicked: root.close()
                }

                Button {
                    id: confirmButton
                    variant: "filled"
                    text: "Create"
                    onClicked: {
                        if (nameInput.text.length > 0) {
                            root.accepted(nameInput.text)
                            root.close()
                        }
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 2: Register it in `crates/app/build.rs`**

After `"qml/components/EmptyState.qml",` add:

```rust
                "qml/components/NewFileDialog.qml",
```

- [ ] **Step 3: Wire it into `main.qml`**

Directly after the `openNewFolderDialog()` function, add:

```qml
    function openNewFileDialog() {
        newFileDialogLoader.active = true
        newFileDialogLoader.item.open()
    }
```

In the `anyPopupOpen` expression, change `contextMenuLoader.active || newFolderDialogLoader.active ||` to:

```qml
        contextMenuLoader.active || newFolderDialogLoader.active ||
        newFileDialogLoader.active ||
```

Directly after the `Loader { id: newFolderDialogLoader ... }` block, add:

```qml
    Loader {
        id: newFileDialogLoader
        anchors.fill: parent
        active: false
        sourceComponent: NewFileDialog {
            onAccepted: (name) => fileModel.createFile(name)
            onClosed: Qt.callLater(() => newFileDialogLoader.active = false)
        }
    }
```

- [ ] **Step 4: Build**

Run: `cargo build -p fm-app`
Expected: build succeeds.

- [ ] **Step 5: Commit**

```bash
git add crates/app/qml/components/NewFileDialog.qml crates/app/build.rs crates/app/qml/main.qml
git commit -m "feat(app): NewFileDialog wired to createFile"
```

---

### Task 4: FabMenu component

**Files:**
- Create: `crates/app/qml/components/FabMenu.qml`
- Modify: `crates/app/build.rs` (after `"qml/components/NewFileDialog.qml",`)
- Modify: `crates/app/qml/main.qml` (the `Fab { ... }` instance inside `fileViewArea`; the `StandardKey.Cancel` Shortcut)

**Interfaces:**
- Consumes: `window.openNewFileDialog()` (Task 3), existing `openNewFolderDialog()`/`pasteEntry()`/`canPaste()`.
- Produces: `FabMenu { property var fileModel; property bool expanded; function dismiss(); signal newFolderRequested(); signal newFileRequested(); signal pasteRequested() }` with `id: fabMenu` in main.qml.

- [ ] **Step 1: Create `crates/app/qml/components/FabMenu.qml`**

```qml
import QtQuick
import "../shapes" as MaterialShapes
import "../shapes/material-shapes.js" as MaterialShapesFn
import com.filemanager.app 1.0

// M3 Expressive FAB menu (roadmap item 2): the FAB from Fab.qml, grown a
// toggled action stack. Closed, it renders exactly like the plain FAB;
// open, the add glyph spins 45° into a ×, the body morphs to the cookie
// shape, and labeled action pills spring up above it — farther pills
// travel farther, which reads as a bottom-up stagger. Dismissed by the ×,
// an action, a click anywhere outside (scrim MouseArea below), or Esc —
// Esc is wired in main.qml's existing Cancel Shortcut (a second Shortcut
// on the same sequence here would be ambiguous and break both).
// Deliberately NOT part of anyPopupOpen: it's a FAB, not a modal, same
// precedent as the selection toolbar.
Item {
    id: root

    property var fileModel
    signal newFolderRequested()
    signal newFileRequested()
    signal pasteRequested()

    property bool expanded: false
    // canPaste() is an invokable, not a bindable property — sampled at
    // open time, exactly like ContextMenu does.
    property var _actions: []

    width: 56
    height: 56
    // Above the outside-click scrim below, which is above everything else
    // in fileViewArea.
    z: 20

    function toggle() {
        if (!root.expanded) {
            var acts = [
                { label: "New folder", icon: "create_new_folder", action: "folder" },
                { label: "New file", icon: "note_add", action: "file" }
            ]
            if (root.fileModel && root.fileModel.canPaste()) {
                acts.push({ label: "Paste here", icon: "content_paste", action: "paste" })
            }
            root._actions = acts
        }
        root.expanded = !root.expanded
    }

    function dismiss() {
        root.expanded = false
    }

    // Outside-click scrim: fills the FAB's parent (the file view area)
    // while open. Transparent — M3's FAB menu scrim is optional and a
    // dimmed one would overstate a three-item menu. Reparented so it can
    // cover the whole view area from inside this component.
    MouseArea {
        parent: root.parent
        anchors.fill: parent
        visible: root.expanded
        z: 19
        acceptedButtons: Qt.AllButtons
        hoverEnabled: false
        onClicked: root.dismiss()
    }

    // The action stack, right-aligned above the FAB, top-to-bottom:
    // New folder, New file, Paste here.
    Column {
        id: _stack
        anchors.right: parent.right
        anchors.bottom: parent.top
        anchors.bottomMargin: 12
        spacing: 8

        Repeater {
            model: root._actions

            delegate: Item {
                id: pill
                required property var modelData
                required property int index

                // Disabled (not just transparent) while closed so the
                // exit animation can play without invisible pills
                // catching clicks.
                enabled: root.expanded
                width: _pillRow.implicitWidth + 32
                height: 48
                anchors.right: parent.right

                opacity: root.expanded ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                // Farther items start farther away — the spring makes
                // them arrive later, a stagger without per-item timers.
                transform: Translate {
                    y: root.expanded ? 0 : 24 + (root._actions.length - pill.index) * 12
                    Behavior on y {
                        SpringAnimation {
                            spring: Motion.springBouncy.spring
                            damping: Motion.springBouncy.damping
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Shape.full
                    color: Color.scheme.surfaceContainerHigh

                    Row {
                        id: _pillRow
                        anchors.centerIn: parent
                        spacing: 8

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            content: pill.modelData.icon
                            iconSize: 20
                            color: Color.scheme.primary
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: pill.modelData.label
                            color: Color.scheme.surfaceText
                            font.family: Type.labelLarge.family
                            font.weight: Type.labelLarge.weight
                            font.pixelSize: Type.labelLarge.size
                        }
                    }

                    Ripple {
                        anchors.fill: parent
                        radius: Shape.full
                        hoverColor: Qt.alpha(Color.scheme.primary, 0.08)
                        rippleColor: Qt.alpha(Color.scheme.primary, 0.2)
                        onClicked: {
                            root.dismiss()
                            if (pill.modelData.action === "folder") {
                                root.newFolderRequested()
                            } else if (pill.modelData.action === "file") {
                                root.newFileRequested()
                            } else {
                                root.pasteRequested()
                            }
                        }
                    }
                }
            }
        }
    }

    // The FAB itself — Fab.qml's exact visual (press morph included),
    // plus the expanded state: primary fill, cookie shape, glyph spun
    // into a ×.
    MaterialShapes.ShapeCanvas {
        anchors.fill: parent
        color: root.expanded ? Color.scheme.primary : Color.scheme.primaryContainer
        roundedPolygon: (_area.pressed || root.expanded)
            ? MaterialShapesFn.getCookie4Sided()
            : MaterialShapesFn.getSquare()
    }

    Icon {
        anchors.centerIn: parent
        content: "add"
        iconSize: 24
        color: root.expanded ? Color.scheme.primaryText : Color.scheme.primaryContainerText
        rotation: root.expanded ? 45 : 0
        Behavior on rotation {
            SpringAnimation {
                spring: Motion.springStandard.spring
                damping: Motion.springStandard.damping
            }
        }
    }

    MouseArea {
        id: _area
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggle()
    }
}
```

- [ ] **Step 2: Register it in `crates/app/build.rs`**

After `"qml/components/NewFileDialog.qml",` add:

```rust
                "qml/components/FabMenu.qml",
```

- [ ] **Step 3: Swap the Fab instance in `main.qml`**

Replace:

```qml
                        Fab {
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 20
                            onClicked: window.openNewFolderDialog()
                        }
```

with:

```qml
                        FabMenu {
                            id: fabMenu
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 20
                            // window.fileListModel, not the bare fileModel
                            // id — this component declares its own
                            // `property var fileModel` (see the alias
                            // comment at the top of this file).
                            fileModel: window.fileListModel
                            onNewFolderRequested: window.openNewFolderDialog()
                            onNewFileRequested: window.openNewFileDialog()
                            onPasteRequested: fileModel.pasteEntry()
                        }
```

(`Fab.qml` stays registered and untouched.)

- [ ] **Step 4: Route Esc through the existing Cancel shortcut**

Replace the existing Cancel Shortcut:

```qml
    Shortcut {
        sequences: [StandardKey.Cancel]
        onActivated: {
            if (!window.anyPopupOpen) {
                fileModel.clearSelection()
            }
        }
    }
```

with:

```qml
    Shortcut {
        sequences: [StandardKey.Cancel]
        onActivated: {
            if (window.anyPopupOpen) return
            // FabMenu can't own its own Cancel Shortcut — two enabled
            // shortcuts on one sequence are ambiguous in Qt and neither
            // fires — so the window-level one dismisses it first.
            if (fabMenu.expanded) {
                fabMenu.dismiss()
            } else {
                fileModel.clearSelection()
            }
        }
    }
```

- [ ] **Step 5: Build**

Run: `cargo build -p fm-app`
Expected: build succeeds.

- [ ] **Step 6: Commit**

```bash
git add crates/app/qml/components/FabMenu.qml crates/app/build.rs crates/app/qml/main.qml
git commit -m "feat(app): FAB menu with New folder / New file / Paste here"
```

---

### Task 5: SplitButton + TopAppBar swap

**Files:**
- Create: `crates/app/qml/components/SplitButton.qml`
- Modify: `crates/app/build.rs` (after `"qml/components/FabMenu.qml",`)
- Modify: `crates/app/qml/components/TopAppBar.qml` (properties ~line 16; the `Item { id: optionsButton ... }` and `ButtonGroup { id: viewToggle ... }` blocks)
- Modify: `crates/app/qml/main.qml` (the `TopAppBar { id: contentHeader ... }` instance)

**Interfaces:**
- Consumes: `viewOptionsMenuLoader.active` in main.qml (existing), TopAppBar's existing outward signals.
- Produces: `SplitButton { property string viewMode; property bool menuOpen; signal toggleRequested(); signal menuRequested(real x, real y) }`; TopAppBar gains `property bool viewOptionsOpen: false`.

- [ ] **Step 1: Create `crates/app/qml/components/SplitButton.qml`**

```qml
import QtQuick
import com.filemanager.app 1.0

// M3 Expressive split button (roadmap item 10), in ButtonGroup's
// connected-shape language: pill outer corners, tight inner corners, 2px
// gap. Leading segment switches to the view you'd switch TO (so its icon
// is the *other* mode's); trailing chevron opens the View options menu
// and springs its inner corners fully round while that menu is open.
Item {
    id: root

    property string viewMode: "list" // "list" | "grid"
    property bool menuOpen: false
    signal toggleRequested()
    signal menuRequested(real x, real y)

    readonly property real fullRadius: height / 2
    readonly property real innerRadius: 4

    height: 32
    implicitWidth: _lead.width + 2 + _trail.width

    Rectangle {
        id: _lead
        width: 44
        height: parent.height
        anchors.left: parent.left
        color: Color.scheme.surfaceContainerHighest
        topLeftRadius: root.fullRadius
        bottomLeftRadius: root.fullRadius
        topRightRadius: root.innerRadius
        bottomRightRadius: root.innerRadius

        Icon {
            anchors.centerIn: parent
            content: root.viewMode === "grid" ? "view_list" : "grid_view"
            iconSize: 16
            color: Color.scheme.surfaceText
        }

        Ripple {
            id: _leadRipple
            anchors.fill: parent
            topLeftRadius: root.fullRadius
            bottomLeftRadius: root.fullRadius
            topRightRadius: root.innerRadius
            bottomRightRadius: root.innerRadius
            hoverColor: Qt.alpha(Color.scheme.primary, 0.08)
            rippleColor: Qt.alpha(Color.scheme.primary, 0.25)
            onClicked: root.toggleRequested()
        }

        Tooltip {
            text: root.viewMode === "grid" ? "Switch to list view" : "Switch to grid view"
            hovered: _leadRipple.containsMouse
        }
    }

    Rectangle {
        id: _trail
        width: 28
        height: parent.height
        anchors.right: parent.right
        color: Color.scheme.surfaceContainerHighest
        topRightRadius: root.fullRadius
        bottomRightRadius: root.fullRadius
        // The M3 Expressive split-button open morph: inner corners spring
        // fully round while the menu is up.
        topLeftRadius: root.menuOpen ? root.fullRadius : root.innerRadius
        bottomLeftRadius: root.menuOpen ? root.fullRadius : root.innerRadius
        Behavior on topLeftRadius {
            SpringAnimation {
                spring: Motion.springStandard.spring
                damping: Motion.springStandard.damping
            }
        }
        Behavior on bottomLeftRadius {
            SpringAnimation {
                spring: Motion.springStandard.spring
                damping: Motion.springStandard.damping
            }
        }

        Icon {
            anchors.centerIn: parent
            content: "arrow_drop_down"
            iconSize: 18
            color: Color.scheme.surfaceText
        }

        Ripple {
            id: _trailRipple
            anchors.fill: parent
            topRightRadius: root.fullRadius
            bottomRightRadius: root.fullRadius
            topLeftRadius: root.menuOpen ? root.fullRadius : root.innerRadius
            bottomLeftRadius: root.menuOpen ? root.fullRadius : root.innerRadius
            hoverColor: Qt.alpha(Color.scheme.primary, 0.08)
            rippleColor: Qt.alpha(Color.scheme.primary, 0.25)
            onClicked: {
                var scenePos = _trail.mapToItem(null, 0, _trail.height)
                root.menuRequested(scenePos.x, scenePos.y)
            }
        }

        Tooltip {
            text: "View options"
            hovered: _trailRipple.containsMouse
        }
    }
}
```

- [ ] **Step 2: Register it in `crates/app/build.rs`**

After `"qml/components/FabMenu.qml",` add:

```rust
                "qml/components/SplitButton.qml",
```

- [ ] **Step 3: Swap TopAppBar's right-side controls**

In `crates/app/qml/components/TopAppBar.qml`, add a property under `property var fileModel`:

```qml
    property bool viewOptionsOpen: false
```

Then replace BOTH the entire `Item { id: optionsButton ... }` block AND the entire `ButtonGroup { id: viewToggle ... }` block (keep the `ShapeLoader` busy cue that sits before them) with:

```qml
        // Split button (roadmap item 10): leading side switches list/grid,
        // trailing chevron opens View options — replaces the old separate
        // segmented toggle + tune icon button.
        SplitButton {
            Layout.preferredHeight: 32
            viewMode: root.viewMode
            menuOpen: root.viewOptionsOpen
            onToggleRequested: root.viewMode === "grid" ? root.listViewRequested() : root.gridViewRequested()
            onMenuRequested: (x, y) => root.optionsRequested(x, y)
        }
```

- [ ] **Step 4: Feed the menu-open state from main.qml**

In `main.qml`'s `TopAppBar { id: contentHeader ... }` instance, directly under `fileModel: fileModel`, add:

```qml
                        viewOptionsOpen: viewOptionsMenuLoader.active
```

- [ ] **Step 5: Build**

Run: `cargo build -p fm-app`
Expected: build succeeds.

- [ ] **Step 6: Commit**

```bash
git add crates/app/qml/components/SplitButton.qml crates/app/build.rs crates/app/qml/components/TopAppBar.qml crates/app/qml/main.qml
git commit -m "feat(app): M3 Expressive split button for view mode and options"
```

---

### Task 6: Selected-tile corner morph

**Files:**
- Modify: `crates/app/qml/components/FileGridItem.qml` (the selected-backing Rectangle, ~line 83)

**Interfaces:**
- Consumes: nothing new.
- Produces: nothing consumed by other tasks.

- [ ] **Step 1: Add the radius morph**

In `FileGridItem.qml`, replace:

```qml
        Rectangle {
            anchors.fill: parent
            radius: Shape.medium
            color: Color.scheme.secondaryContainer
            opacity: root.selected ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }
```

with:

```qml
        Rectangle {
            anchors.fill: parent
            // Selection rounds the corners (roadmap item 11) — a whisper
            // of the removed selection badge, spring per the motion rule.
            radius: root.selected ? Shape.extraLarge : Shape.medium
            Behavior on radius {
                SpringAnimation {
                    spring: Motion.springStandard.spring
                    damping: Motion.springStandard.damping
                }
            }
            color: Color.scheme.secondaryContainer
            opacity: root.selected ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }
```

- [ ] **Step 2: Full verification pass**

Run: `cargo build -p fm-app && cargo test -p fm-app && cargo test -p fm-core`
Expected: all pass, including Task 1's create_file tests and Task 2's describe assertion. (GUI verification is the user's: FAB menu stack + dismissal paths + undoable New file; split button toggle/menu/open-morph; tile corner spring.)

- [ ] **Step 3: Commit**

```bash
git add crates/app/qml/components/FileGridItem.qml
git commit -m "feat(app): selected grid tiles morph their corners"
```
