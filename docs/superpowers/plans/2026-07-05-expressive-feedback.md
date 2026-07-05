# Expressive Feedback Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement UI/UX roadmap items 1, 3, 5 — a floating selection toolbar, animated row/tile add & remove, and a listing loading state — per `docs/superpowers/specs/2026-07-05-expressive-feedback-design.md`.

**Architecture:** Two new reactive qproperties on the cxx-qt bridge (`selectionCount`, `isListing`) feed three QML changes: a new `SelectionToolbar.qml` component, `ViewTransition`s on the existing ListView/GridView, and a gated `ShapeLoader` in `main.qml`. No fm-core changes; no selection-semantics changes.

**Tech Stack:** Rust + cxx-qt (`crates/app`), QML on plain Qt Quick primitives (no Quick Controls), token singletons `Color/Type/Shape/Elevation/Motion`.

## Global Constraints

- Motion rule: component/spatial state changes use `SpringAnimation`; screen-level transitions use `Easing.BezierSpline` + `easing.bezierCurve` pairs from `Motion.qml`. Don't mix them.
- QML components are hand-built from primitives (Rectangle/Item/Text/MouseArea) — never Qt Quick Controls.
- Every new `.qml` file must be registered in `crates/app/build.rs` or it silently won't resolve.
- The toolbar must NOT be added to `main.qml`'s `anyPopupOpen` — shortcuts stay live while it shows.
- In QML, bind model references as `window.fileListModel`, never the bare `fileModel` id, on any component declaring its own `property var fileModel` (see the alias comment at the top of `main.qml`).
- Verification ceiling: `cargo build -p fm-app` + `cargo test -p fm-app` + `cargo test -p fm-core`. Do NOT launch the GUI — the user verifies visually themselves.
- Commit after every task.

---

### Task 1: Reactive `selectionCount` property on FileListModel

**Files:**
- Modify: `crates/app/src/file_list_model.rs` (qproperty block ~line 49; struct `FileListModelRust` ~line 453; `Default` impl ~line 524; selection methods ~lines 682–746; `navigate` ~line 801; `apply_entries_diff` ~line 1093)

**Interfaces:**
- Consumes: existing `selected: HashSet<String>` field and its mutation points.
- Produces: QML-bindable `fileModel.selectionCount` (int, auto change signal) — Task 3's toolbar binds to it. Rust-side helper `fn sync_selection_count(self: Pin<&mut Self>)` that any future selection mutation must call.

- [ ] **Step 1: Declare the qproperty**

In the `extern "RustQt"` block, directly under the `transfer_speed_label` qproperty line, add:

```rust
        // Reactive mirror of selected.len(). selectedCount() (the
        // invokable below) serves imperative callers; this property is
        // what QML *binds* to — the floating selection toolbar shows and
        // hides itself off it. Kept in sync by sync_selection_count(),
        // which every mutation of `selected` must call.
        #[qproperty(i32, selection_count, cxx_name = "selectionCount")]
```

- [ ] **Step 2: Add the struct field and default**

In `pub struct FileListModelRust`, directly under the `selected` field, add:

```rust
    /// Reactive mirror of `selected.len()` for the selectionCount
    /// qproperty — see sync_selection_count().
    selection_count: i32,
```

In `impl Default for FileListModelRust`, under `selected: std::collections::HashSet::new(),`, add:

```rust
            selection_count: 0,
```

- [ ] **Step 3: Add the sync helper**

In the `impl file_list_model::FileListModel` block, directly above `fn set_selected`, add:

```rust
    /// Re-derives the reactive `selectionCount` property from
    /// `selected.len()`. Every mutation of `selected` must call this —
    /// it reads the final length rather than counting incrementally, so
    /// it can't drift. Guarded so an unchanged count emits no signal.
    fn sync_selection_count(mut self: core::pin::Pin<&mut Self>) {
        let count = self.selected.len() as i32;
        if self.selection_count != count {
            self.as_mut().set_selection_count(count);
        }
    }
```

- [ ] **Step 4: Call it at every mutation point (6 sites)**

1. `set_selected` — inside the `if changed` block, after `notify_row_for_name`:

```rust
        if changed {
            self.as_mut().notify_row_for_name(&name);
            self.as_mut().sync_selection_count();
        }
```

2. `select_range` — directly after `self.as_mut().rust_mut().selected = names.into_iter().collect();`:

```rust
        self.as_mut().sync_selection_count();
```

3. `select_all` — directly after `self.as_mut().rust_mut().selected = names;`:

```rust
        self.as_mut().sync_selection_count();
```

4. `clear_selection` — directly after `self.as_mut().rust_mut().selected.clear();`:

```rust
        self.as_mut().sync_selection_count();
```

5. `navigate` — directly after `self.as_mut().end_reset_model();` (the reset cleared `selected` a few lines up):

```rust
        self.as_mut().sync_selection_count();
```

6. `apply_entries_diff` — directly after the `.retain(|name| new_names.contains(name));` statement:

```rust
        self.as_mut().sync_selection_count();
```

- [ ] **Step 5: Build and test**

Run: `cargo build -p fm-app && cargo test -p fm-app`
Expected: build succeeds; existing tests pass.

- [ ] **Step 6: Commit**

```bash
git add crates/app/src/file_list_model.rs
git commit -m "feat(app): reactive selectionCount property on FileListModel"
```

---

### Task 2: `isListing` property for async navigation listings

**Files:**
- Modify: `crates/app/src/file_list_model.rs` (qproperty block; struct + `Default`; `navigate` ~lines 787–828)

**Interfaces:**
- Consumes: `navigate()`'s generation-guarded background listing.
- Produces: QML-bindable `fileModel.isListing` (bool) — Task 5 gates the loading spinner on it. `refresh_entries_diff()` (watcher path) deliberately never touches it.

- [ ] **Step 1: Declare the qproperty**

Directly under the `selection_count` qproperty added in Task 1:

```rust
        // True while an async navigate() listing is in flight and the
        // view is therefore empty — drives the loading state in
        // main.qml. Watcher-driven refreshes (refresh_entries_diff)
        // never set it: the view isn't empty during a refresh, so no
        // loading indicator belongs there.
        #[qproperty(bool, is_listing, cxx_name = "isListing")]
```

- [ ] **Step 2: Add the struct field and default**

In `pub struct FileListModelRust`, directly under the `listing_generation` field:

```rust
    /// Backing for the isListing qproperty — see navigate().
    is_listing: bool,
```

In `impl Default`, under `listing_generation: 0,`:

```rust
            is_listing: false,
```

- [ ] **Step 3: Set it in `navigate()`**

Directly after `self.as_mut().start_dir_watch();` (before the generation bump), add:

```rust
        self.as_mut().set_is_listing(true);
```

In the `qt_thread.queue` callback, after `model.as_mut().end_reset_model();`, add:

```rust
                model.as_mut().set_is_listing(false);
```

The clear sits *after* the `listing_generation != generation` early-return on purpose: a stale listing's callback must not clear a newer navigation's flag. Every non-stale listing — success, empty directory, or unreadable directory (gather_entries yields an empty Vec) — reaches this line, so the flag can't stick.

- [ ] **Step 4: Build and test**

Run: `cargo build -p fm-app && cargo test -p fm-app`
Expected: build succeeds; existing tests pass.

- [ ] **Step 5: Commit**

```bash
git add crates/app/src/file_list_model.rs
git commit -m "feat(app): isListing property for async navigation listings"
```

---

### Task 3: SelectionToolbar component + main.qml wiring

**Files:**
- Create: `crates/app/qml/components/SelectionToolbar.qml`
- Modify: `crates/app/build.rs` (qml_files list, ~line 53)
- Modify: `crates/app/qml/main.qml` (inside `fileViewArea`, after the `Fab`, ~line 758)

**Interfaces:**
- Consumes: `fileModel.selectionCount` (Task 1), existing invokables `copySelection()`, `cutSelection()`, `restoreSelection()`, `clearSelection()`, properties `currentPath`/`trashPath`; `window.openDeleteSelectionConfirmDialog(count)` and `window.openDeletePermanentlySelectionConfirmDialog(count)` in main.qml.
- Produces: `SelectionToolbar { property var fileModel; signal deleteRequested(int count); signal deletePermanentlyRequested(int count) }`.

- [ ] **Step 1: Create `crates/app/qml/components/SelectionToolbar.qml`**

```qml
import QtQuick
import com.filemanager.app 1.0

// M3 Expressive contextual floating toolbar — springs up from the bottom
// edge of the file view while 2+ items are selected, and sinks away when
// the selection drops below that (see docs/superpowers/specs/
// 2026-07-05-expressive-feedback-design.md). A pure consumer of the
// model's selection state: it never changes selection semantics, and it
// is deliberately NOT part of main.qml's anyPopupOpen — shortcuts stay
// live and act on the same selection this toolbar mirrors. Delete goes
// through the confirming dialog path (the signals below), matching the
// context menu rather than the Delete key's immediate trash.
Item {
    id: root

    property var fileModel
    signal deleteRequested(int count)
    signal deletePermanentlyRequested(int count)

    // In Trash, Copy/Cut/Delete make no sense on trashed entries —
    // Restore / Delete Permanently replace them.
    readonly property bool inTrash: fileModel ? fileModel.currentPath === fileModel.trashPath : false
    readonly property bool shown: fileModel ? fileModel.selectionCount >= 2 : false
    readonly property int liveCount: fileModel ? fileModel.selectionCount : 0
    // The label keeps its last >=2 value while the toolbar sinks away,
    // so the exit never flashes "0 selected".
    property int shownCount: 2
    onLiveCountChanged: if (liveCount >= 2) shownCount = liveCount

    width: _row.width + 12
    height: 56
    // Fully hidden = actually gone: opacity alone would leave the
    // MouseAreas hover/click-active in an invisible strip.
    visible: shown || opacity > 0
    opacity: shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    // Spatial spring entrance/exit per the motion rule — the toolbar
    // rests below the view's clipped bottom edge and springs up into
    // place, rather than fading in situ.
    transform: Translate {
        y: root.shown ? 0 : root.height + 24
        Behavior on y {
            SpringAnimation {
                spring: Motion.springStandard.spring
                damping: Motion.springStandard.damping
            }
        }
    }

    // Same hover-circle icon-button pattern as TopAppBar's buttons: the
    // Icon is a sibling of the highlight, not its child, so it doesn't
    // fade with the highlight's opacity.
    component ToolbarButton: Item {
        id: btn
        property string icon: ""
        property string tip: ""
        signal activated()
        width: 44
        height: 44
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
            anchors.fill: parent
            radius: Shape.full
            color: Elevation.surfaceAt(3)
            opacity: _btnArea.containsMouse ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }

        Icon {
            anchors.centerIn: parent
            content: btn.icon
            iconSize: 20
            color: Color.scheme.surfaceText
        }

        MouseArea {
            id: _btnArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.activated()
        }

        Tooltip {
            text: btn.tip
            hovered: _btnArea.containsMouse
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Shape.full
        color: Color.scheme.surfaceContainerHigh
    }

    Row {
        id: _row
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
            anchors.verticalCenter: parent.verticalCenter
            leftPadding: 16
            rightPadding: 10
            text: root.shownCount + " selected"
            color: Color.scheme.surfaceText
            font.family: Type.labelLarge.family
            font.pixelSize: Type.labelLarge.size
            font.weight: Font.Medium
        }

        ToolbarButton { icon: "content_copy"; tip: "Copy"; visible: !root.inTrash; onActivated: root.fileModel.copySelection() }
        ToolbarButton { icon: "content_cut"; tip: "Cut"; visible: !root.inTrash; onActivated: root.fileModel.cutSelection() }
        ToolbarButton { icon: "delete"; tip: "Move to Trash"; visible: !root.inTrash; onActivated: root.deleteRequested(root.liveCount) }
        ToolbarButton { icon: "restore_from_trash"; tip: "Restore"; visible: root.inTrash; onActivated: root.fileModel.restoreSelection() }
        ToolbarButton { icon: "delete_forever"; tip: "Delete permanently"; visible: root.inTrash; onActivated: root.deletePermanentlyRequested(root.liveCount) }

        Rectangle {
            width: 1
            height: 24
            anchors.verticalCenter: parent.verticalCenter
            color: Qt.alpha(Color.scheme.surfaceText, 0.25)
        }

        ToolbarButton { icon: "close"; tip: "Clear selection"; onActivated: root.fileModel.clearSelection() }
    }
}
```

- [ ] **Step 2: Register it in `crates/app/build.rs`**

In the `.qml_files([...])` list, after `"qml/components/TransferStatus.qml",` add:

```rust
                "qml/components/SelectionToolbar.qml",
```

- [ ] **Step 3: Instantiate it in `main.qml`**

Inside `fileViewArea` (`Item { id: fileViewArea ... }`), directly after the `Fab { ... }` block, add:

```qml
                        // Contextual floating toolbar for bulk actions —
                        // springs up while 2+ items are selected. Not a
                        // popup: deliberately absent from anyPopupOpen.
                        SelectionToolbar {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 16
                            // window.fileListModel, not the bare fileModel
                            // id — this component declares its own
                            // `property var fileModel` (see the alias
                            // comment at the top of this file).
                            fileModel: window.fileListModel
                            onDeleteRequested: (count) => window.openDeleteSelectionConfirmDialog(count)
                            onDeletePermanentlyRequested: (count) => window.openDeletePermanentlySelectionConfirmDialog(count)
                        }
```

- [ ] **Step 4: Build**

Run: `cargo build -p fm-app`
Expected: build succeeds (QML is compiled/registered at build time; a typo in the new file fails here).

- [ ] **Step 5: Commit**

```bash
git add crates/app/qml/components/SelectionToolbar.qml crates/app/build.rs crates/app/qml/main.qml
git commit -m "feat(app): contextual floating selection toolbar (M3 Expressive)"
```

---

### Task 4: Animated add/remove/displaced transitions in both views

**Files:**
- Modify: `crates/app/qml/main.qml` (ListView `id: listView` ~line 378 and GridView `id: gridView` ~line 577)

**Interfaces:**
- Consumes: nothing new — watcher-driven `begin/endInsertRows`/`begin/endRemoveRows` diffs already flow from `apply_entries_diff`.
- Produces: nothing consumed by other tasks.

- [ ] **Step 1: Add transitions to the ListView**

In the `ListView { id: listView ... }` component, directly after the `property string selectionAnchor: ""` declaration, add:

```qml
                                // Watcher-driven diff inserts/removes (and
                                // this app's own single-item operations)
                                // animate; `populate` is deliberately unset so
                                // navigating into a directory never animates
                                // hundreds of rows at once. The remove
                                // transition runs while the delegate is being
                                // destroyed — it touches only opacity/scale,
                                // never model roles.
                                add: Transition {
                                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 150; easing.type: Easing.OutCubic }
                                    SpringAnimation { property: "scale"; from: 0.8; to: 1; spring: Motion.springStandard.spring; damping: Motion.springStandard.damping }
                                }
                                remove: Transition {
                                    NumberAnimation { property: "opacity"; to: 0; duration: Motion.emphasizedAccelerate.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.emphasizedAccelerate.bezier }
                                    NumberAnimation { property: "scale"; to: 0.9; duration: Motion.emphasizedAccelerate.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.emphasizedAccelerate.bezier }
                                }
                                displaced: Transition {
                                    SpringAnimation { properties: "x,y"; spring: Motion.springStandard.spring; damping: Motion.springStandard.damping }
                                    // An interrupted add must not strand a
                                    // row half-faded/half-scaled.
                                    NumberAnimation { property: "opacity"; to: 1; duration: 100 }
                                    NumberAnimation { property: "scale"; to: 1; duration: 100 }
                                }
```

- [ ] **Step 2: Add the identical transitions to the GridView**

In the `GridView { id: gridView ... }` component, directly after its `property string selectionAnchor: ""` declaration, add the exact same three-transition block as Step 1 (same code, no changes — GridView cells scale/fade identically).

- [ ] **Step 3: Build**

Run: `cargo build -p fm-app`
Expected: build succeeds.

- [ ] **Step 4: Commit**

```bash
git add crates/app/qml/main.qml
git commit -m "feat(app): animated add/remove/displaced transitions in file views"
```

---

### Task 5: Loading state — gated ShapeLoader

**Files:**
- Modify: `crates/app/qml/main.qml` (inside `fileViewArea`, between the view `Loader` and the `Fab`, ~line 752)

**Interfaces:**
- Consumes: `fileModel.isListing` (Task 2); existing `ShapeLoader` component.
- Produces: nothing consumed by other tasks (roadmap item 6, empty states, will later hang off the same `isListing`).

- [ ] **Step 1: Add the spinner and its gate**

Inside `fileViewArea`, directly after the view `Loader { anchors.fill: parent; sourceComponent: ... }` block and before the `Fab`, add:

```qml
                        // Loading state — a navigation listing that's
                        // actually taking a while shows the shape-morph
                        // loader centered in the otherwise-empty view,
                        // disambiguating "still listing" from "empty
                        // folder". The 150ms gate keeps fast local listings
                        // from flashing it. isListing is only ever true for
                        // navigate() listings, never watcher refreshes, so
                        // this can't appear over existing rows.
                        ShapeLoader {
                            anchors.centerIn: parent
                            size: 48
                            color: Color.scheme.primary
                            visible: fileModel.isListing && _listingSpinnerGate.elapsed
                            running: visible
                        }

                        Timer {
                            id: _listingSpinnerGate
                            property bool elapsed: false
                            interval: 150
                            running: fileModel.isListing
                            onRunningChanged: if (running) elapsed = false
                            onTriggered: elapsed = true
                        }
```

- [ ] **Step 2: Build**

Run: `cargo build -p fm-app`
Expected: build succeeds.

- [ ] **Step 3: Full verification pass**

Run: `cargo build -p fm-app && cargo test -p fm-app && cargo test -p fm-core`
Expected: all pass. (GUI verification is the user's, per project convention: toolbar springs up at 2+ selection with Trash-aware actions; terminal `touch`/`rm` animates rows; huge-directory navigation shows the spinner after a beat.)

- [ ] **Step 4: Commit**

```bash
git add crates/app/qml/main.qml
git commit -m "feat(app): loading state with centered ShapeLoader"
```
