# Navigation & States Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement UI/UX roadmap items 4, 6, 12 — directional navigation transitions, empty states, and a crossfading current-folder headline — per `docs/superpowers/specs/2026-07-05-navigation-and-states-design.md`.

**Architecture:** One new bridge bool (`searchActive`); everything else is QML. Direction is derived in `main.qml` from path prefixes and consumed by a one-shot entrance animation that fires when `isListing` flips false (content arrival, never watcher refreshes). A new `EmptyState.qml` renders three variants off `isListing`/`searchActive`/`trashPath` + the active view's `count`. A 44px headline row crossfades the folder display name.

**Tech Stack:** Rust + cxx-qt (`crates/app`), QML on plain Qt Quick primitives, token singletons `Color/Type/Shape/Elevation/Motion`, vendored `ShapeCanvas` + `material-shapes.js`.

## Global Constraints

- Motion rule: these are screen-level transitions — `easing.type: Easing.BezierSpline` + `easing.bezierCurve` pairs from `Motion.qml`, never springs.
- QML components are hand-built from primitives — never Qt Quick Controls.
- Every new `.qml` file must be registered in `crates/app/build.rs`.
- Bind model references as `window.fileListModel` on any component declaring its own `property var fileModel` — never the bare `fileModel` id.
- The empty state must not intercept clicks outside its visible content (background context menu / empty-space drops keep working).
- Verification ceiling: `cargo build -p fm-app` + `cargo test -p fm-app` + `cargo test -p fm-core`. Do NOT launch the GUI — the user verifies visually.
- Commit after every task.

---

### Task 1: `searchActive` property on FileListModel

**Files:**
- Modify: `crates/app/src/file_list_model.rs` (qproperty block ~line 58; struct field near `search_query` ~line 430; `Default` impl ~line 516; `set_search_query` ~line 932; `navigate` search-reset ~line 832)

**Interfaces:**
- Consumes: existing `set_search_query()` invokable and `navigate()`'s search reset.
- Produces: QML-bindable `fileModel.searchActive` (bool, auto change signal) — Task 3's EmptyState picks its "No matches" variant off it.

- [ ] **Step 1: Declare the qproperty**

In the `extern "RustQt"` block, directly under the `is_listing` qproperty line, add:

```rust
        // True while a non-empty search query filters the view — the
        // empty state picks its "no matches" variant off this. The query
        // string itself stays Rust-side: setSearchQuery does a model
        // reset that a generated qproperty setter couldn't, so only this
        // derived bool is exposed.
        #[qproperty(bool, search_active, cxx_name = "searchActive")]
```

- [ ] **Step 2: Add the struct field and default**

In `pub struct FileListModelRust`, directly under the `search_query: QString,` field, add:

```rust
    /// Backing for the searchActive qproperty — see set_search_query().
    search_active: bool,
```

In `impl Default for FileListModelRust`, directly under `search_query: QString::from(""),`, add:

```rust
            search_active: false,
```

- [ ] **Step 3: Set it in `set_search_query()`**

Replace the whole function:

```rust
    fn set_search_query(mut self: core::pin::Pin<&mut Self>, query: &QString) {
        self.as_mut().begin_reset_model();
        self.as_mut().rust_mut().search_query = query.clone();
        self.as_mut().rust_mut().rebuild_displayed();
        self.as_mut().end_reset_model();
        let active = !query.to_string().is_empty();
        self.as_mut().set_search_active(active);
    }
```

- [ ] **Step 4: Clear it in `navigate()`**

`navigate()` already resets `search_query` inside its reset block. Directly after the existing `self.as_mut().sync_selection_count();` line (added by the expressive-feedback slice, right after `end_reset_model()`), add:

```rust
        self.as_mut().set_search_active(false);
```

- [ ] **Step 5: Build and test**

Run: `cargo build -p fm-app && cargo test -p fm-app`
Expected: build succeeds; all existing tests pass.

- [ ] **Step 6: Commit**

```bash
git add crates/app/src/file_list_model.rs
git commit -m "feat(app): searchActive property for the no-matches empty state"
```

---

### Task 2: Directional navigation transitions + list↔grid swap animation

**Files:**
- Modify: `crates/app/qml/main.qml` (window property block ~line 25; `FileListModel { id: fileModel ... }` block ~line 51; the view `Loader` inside `fileViewArea` ~line 780)

**Interfaces:**
- Consumes: `fileModel.isListing` (already on the bridge), `fileModel.currentPath`.
- Produces: the view `Loader` gains `id: viewLoader` — Task 3's EmptyState visibility binds to `viewLoader.item.count`. Window property `window._navDirection` ("forward" | "back" | "neutral").

- [ ] **Step 1: Add direction tracking to the window**

In `main.qml`, directly under the `property bool _internalDragActive: false` declaration, add:

```qml
    // Direction of the most recent navigation — "forward" (into a child),
    // "back" (up to an ancestor), or "neutral" (sidebar jump, path edit).
    // Derived from path prefixes in fileModel.onCurrentPathChanged and
    // consumed by viewEntrance when the listing lands; Rust deliberately
    // has no direction concept.
    property string _lastPath: ""
    property string _navDirection: "neutral"
```

- [ ] **Step 2: Derive the direction on path changes**

Inside the `FileListModel { id: fileModel ... }` block, directly under the `onThemeColorsTextChanged:` line, add:

```qml
        onCurrentPathChanged: {
            var oldPath = window._lastPath
            var newPath = fileModel.currentPath
            if (oldPath.length === 0) {
                window._navDirection = "neutral"
            } else if (newPath.startsWith(oldPath === "/" ? "/" : oldPath + "/")) {
                window._navDirection = "forward"
            } else if (oldPath.startsWith(newPath === "/" ? "/" : newPath + "/")) {
                window._navDirection = "back"
            } else {
                window._navDirection = "neutral"
            }
            window._lastPath = newPath
        }
```

- [ ] **Step 3: Give the Loader an id, a translate transform, and the swap animation**

Replace the view Loader inside `fileViewArea`:

```qml
                        Loader {
                            anchors.fill: parent
                            sourceComponent: fileModel.viewMode === "grid" ? gridComponent : listComponent
                        }
```

with:

```qml
                        Loader {
                            id: viewLoader
                            anchors.fill: parent
                            sourceComponent: fileModel.viewMode === "grid" ? gridComponent : listComponent
                            transform: Translate { id: viewSlide }
                            // List↔grid toggle (and first load): the fresh
                            // view crossfades/scales in instead of snapping.
                            // At startup this can overlap viewEntrance below;
                            // both settle at opacity 1 / scale 1, so the race
                            // is harmless.
                            onLoaded: viewSwapEntrance.restart()
                        }

                        // One-shot entrance when a navigation's listing
                        // lands (isListing flips false) — content slides in
                        // from the right going deeper, from the left going
                        // up, plain fade for sidebar jumps. Screen-level
                        // motion: bezier pairs, not springs. Watcher
                        // refreshes never touch isListing, so they never
                        // move the view.
                        ParallelAnimation {
                            id: viewEntrance
                            NumberAnimation {
                                target: viewSlide
                                property: "x"
                                from: window._navDirection === "forward" ? 24
                                    : window._navDirection === "back" ? -24 : 0
                                to: 0
                                duration: Motion.emphasizedDecelerate.duration
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Motion.emphasizedDecelerate.bezier
                            }
                            NumberAnimation {
                                target: viewLoader
                                property: "opacity"
                                from: 0
                                to: 1
                                duration: Motion.emphasizedDecelerate.duration
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Motion.emphasizedDecelerate.bezier
                            }
                        }

                        ParallelAnimation {
                            id: viewSwapEntrance
                            NumberAnimation {
                                target: viewLoader
                                property: "opacity"
                                from: 0
                                to: 1
                                duration: Motion.standard.duration
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Motion.standard.bezier
                            }
                            NumberAnimation {
                                target: viewLoader
                                property: "scale"
                                from: 0.96
                                to: 1
                                duration: Motion.standard.duration
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Motion.standard.bezier
                            }
                        }
```

- [ ] **Step 4: Trigger the entrance when content arrives**

Directly after the `ParallelAnimation { id: viewSwapEntrance ... }` block added in Step 3, add:

```qml
                        Connections {
                            target: fileModel
                            function onIsListingChanged() {
                                if (!fileModel.isListing) {
                                    viewEntrance.restart()
                                }
                            }
                        }
```

- [ ] **Step 5: Build**

Run: `cargo build -p fm-app`
Expected: build succeeds.

- [ ] **Step 6: Commit**

```bash
git add crates/app/qml/main.qml
git commit -m "feat(app): directional navigation transitions and view-swap crossfade"
```

---

### Task 3: EmptyState component

**Files:**
- Create: `crates/app/qml/components/EmptyState.qml`
- Modify: `crates/app/build.rs` (qml_files list, after `"qml/components/SelectionToolbar.qml",`)
- Modify: `crates/app/qml/main.qml` (inside `fileViewArea`, after the `Timer { id: _listingSpinnerGate ... }` block, before the `Fab`)

**Interfaces:**
- Consumes: `fileModel.searchActive` (Task 1), `fileModel.isListing`, `fileModel.currentPath`/`trashPath`, `viewLoader.item.count` (Task 2's Loader id), existing `Button`/`ShapeCanvas` components, `window.openNewFolderDialog()`.
- Produces: `EmptyState { property var fileModel; signal newFolderRequested() }`.

- [ ] **Step 1: Create `crates/app/qml/components/EmptyState.qml`**

```qml
import QtQuick
import "../shapes" as MaterialShapes
import "../shapes/material-shapes.js" as MaterialShapesFn
import com.filemanager.app 1.0

// Expressive empty state for a contentless view (see docs/superpowers/
// specs/2026-07-05-navigation-and-states-design.md): a large soft
// catalog shape + one line of text, echoing DecorativeShapesBackground's
// language. Three variants, first match wins: active search ("No
// matches"), Trash ("Trash is empty"), plain empty folder — which also
// offers a tonal New folder button. Visibility is main.qml's job (it
// owns the isListing/count logic); this component only renders. The
// root Item is sized to its content and has no MouseArea, so clicks
// outside the button fall through to the background (context menu,
// empty-space drops).
Item {
    id: root

    property var fileModel
    signal newFolderRequested()

    readonly property bool searchVariant: fileModel ? fileModel.searchActive : false
    readonly property bool trashVariant: fileModel
        ? (!searchVariant && fileModel.currentPath === fileModel.trashPath)
        : false

    readonly property string title: searchVariant ? "No matches"
        : trashVariant ? "Trash is empty"
        : "This folder is empty"
    readonly property string body: searchVariant ? "Nothing here matches your search."
        : trashVariant ? "Deleted items land here before they're gone for good."
        : "Drop files here or create something."

    width: _column.width
    height: _column.height

    // Screen-level entrance (a state appearing), so bezier — not spring.
    onVisibleChanged: if (visible) _entrance.restart()

    ParallelAnimation {
        id: _entrance
        NumberAnimation {
            target: _column
            property: "opacity"
            from: 0
            to: 1
            duration: Motion.standardDecelerate.duration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.standardDecelerate.bezier
        }
        NumberAnimation {
            target: _column
            property: "scale"
            from: 0.92
            to: 1
            duration: Motion.standardDecelerate.duration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.standardDecelerate.bezier
        }
    }

    Column {
        id: _column
        spacing: 8

        MaterialShapes.ShapeCanvas {
            width: 160
            height: 160
            anchors.horizontalCenter: parent.horizontalCenter
            color: Qt.alpha(Color.scheme.primary, 0.10)
            roundedPolygon: MaterialShapesFn.getCookie12Sided()
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.title
            color: Color.scheme.surfaceText
            font.family: Type.titleLarge.family
            font.weight: Type.titleLarge.weight
            font.pixelSize: Type.titleLarge.size
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.body
            color: Qt.alpha(Color.scheme.surfaceText, 0.7)
            font.family: Type.bodyMedium.family
            font.pixelSize: Type.bodyMedium.size
        }

        // Breathing room between text and button.
        Item { width: 1; height: 8; visible: !root.searchVariant && !root.trashVariant }

        Button {
            visible: !root.searchVariant && !root.trashVariant
            anchors.horizontalCenter: parent.horizontalCenter
            variant: "tonal"
            text: "New folder"
            icon: "create_new_folder"
            onClicked: root.newFolderRequested()
        }
    }
}
```

- [ ] **Step 2: Register it in `crates/app/build.rs`**

In the `.qml_files([...])` list, after `"qml/components/SelectionToolbar.qml",` add:

```rust
                "qml/components/EmptyState.qml",
```

- [ ] **Step 3: Instantiate it in `main.qml`**

Inside `fileViewArea`, directly after the `Timer { id: _listingSpinnerGate ... }` block and before the `Fab`, add:

```qml
                        // Empty state — only after a listing has actually
                        // landed empty (never while the spinner could
                        // show), keyed off the live view's row count.
                        EmptyState {
                            anchors.centerIn: parent
                            visible: (!fileModel.isListing && viewLoader.item)
                                ? viewLoader.item.count === 0 : false
                            // window.fileListModel, not the bare fileModel
                            // id — this component declares its own
                            // `property var fileModel` (see the alias
                            // comment at the top of this file).
                            fileModel: window.fileListModel
                            onNewFolderRequested: window.openNewFolderDialog()
                        }
```

- [ ] **Step 4: Build**

Run: `cargo build -p fm-app`
Expected: build succeeds.

- [ ] **Step 5: Commit**

```bash
git add crates/app/qml/components/EmptyState.qml crates/app/build.rs crates/app/qml/main.qml
git commit -m "feat(app): expressive empty states for folder, Trash, and search"
```

---

### Task 4: Current-folder headline row

**Files:**
- Modify: `crates/app/qml/main.qml` (content `ColumnLayout`, between the `TopAppBar { id: contentHeader ... }` block and `Item { id: fileViewArea ... }`)

**Interfaces:**
- Consumes: `fileModel.currentPath`/`trashPath`; `Type.headlineSmall`; `Motion.standard`.
- Produces: nothing consumed by other tasks.

- [ ] **Step 1: Insert the headline row**

In the content `ColumnLayout` (the one holding `TopAppBar` and `fileViewArea`), directly after the closing brace of the `TopAppBar { id: contentHeader ... }` block, add:

```qml
                    // Current-folder headline (roadmap item 12) — the
                    // folder's display name at Expressive type scale,
                    // crossfading old→new on navigate. No horizontal
                    // motion here: the view host below already carries
                    // the directional slide; doubling it would be noise.
                    // The Nebula-style 56px app-bar row above stays as
                    // designed.
                    Item {
                        id: folderHeadline
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        Layout.minimumHeight: 44
                        Layout.maximumHeight: 44
                        Layout.leftMargin: 16

                        readonly property string folderName: {
                            var p = fileModel.currentPath ? fileModel.currentPath : ""
                            if (p.length === 0 || p === "/") return "Root"
                            if (p === fileModel.trashPath) return "Trash"
                            return p.substring(p.lastIndexOf("/") + 1)
                        }
                        onFolderNameChanged: {
                            _headlineOld.text = _headlineNew.text
                            _headlineNew.text = folderName
                            _headlineSwap.restart()
                        }
                        Component.onCompleted: _headlineNew.text = folderName

                        Text {
                            id: _headlineOld
                            anchors.verticalCenter: parent.verticalCenter
                            opacity: 0
                            color: Color.scheme.surfaceText
                            font.family: Type.headlineSmall.family
                            font.weight: Type.headlineSmall.weight
                            font.pixelSize: Type.headlineSmall.size
                        }

                        Text {
                            id: _headlineNew
                            anchors.verticalCenter: parent.verticalCenter
                            color: Color.scheme.surfaceText
                            font.family: Type.headlineSmall.family
                            font.weight: Type.headlineSmall.weight
                            font.pixelSize: Type.headlineSmall.size
                        }

                        ParallelAnimation {
                            id: _headlineSwap
                            NumberAnimation {
                                target: _headlineOld
                                property: "opacity"
                                from: 1
                                to: 0
                                duration: Motion.standard.duration
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Motion.standard.bezier
                            }
                            NumberAnimation {
                                target: _headlineNew
                                property: "opacity"
                                from: 0
                                to: 1
                                duration: Motion.standard.duration
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Motion.standard.bezier
                            }
                        }
                    }
```

- [ ] **Step 2: Full verification pass**

Run: `cargo build -p fm-app && cargo test -p fm-app && cargo test -p fm-core`
Expected: all pass. (GUI verification is the user's, per project convention: directional slides on navigate, spinner-then-slide on `/usr/lib`, three empty-state variants, headline crossfade reading "Root"/"Trash" at those paths, list↔grid crossfade.)

- [ ] **Step 3: Commit**

```bash
git add crates/app/qml/main.qml
git commit -m "feat(app): crossfading current-folder headline (M3 Expressive type)"
```
