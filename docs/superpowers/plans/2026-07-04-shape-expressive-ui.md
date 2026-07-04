# Shape-Expressive UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add two genuinely shape-morphing M3 Expressive surfaces — a floating action button for "New folder" and a per-tile multi-select badge — both driven by the existing vendored `MatrialShapes` polygon-morph engine.

**Architecture:** Both new components render through the *unmodified* `crates/app/qml/shapes/ShapeCanvas.qml`, which already morphs automatically between whatever two polygons its `roundedPolygon` property is set to (the same primitive `ShapeLoader.qml` already uses for the busy spinner). Neither new component touches the morph engine itself — they just drive `ShapeCanvas.roundedPolygon` off a boolean (`pressed` for the FAB, `selected` for the badge).

**Tech Stack:** QML/Qt Quick, the vendored `qml/shapes/` MatrialShapes library (already present, unmodified by this plan). No Rust/backend changes.

## Global Constraints

- No new `GroupCard`-style grouped-card surfaces beyond the existing Properties/Settings dialogs — this plan is shape-morphing only (confirmed with the user during brainstorming).
- The FAB has exactly one action (New folder) — no FAB menu, no second action.
- The selection badge is layered *on top of* the existing flat `secondaryContainer` selection tint (added by the multi-select feature) — it does not replace that tint.
- This project has no automated QML test harness — verification is `cargo build -p fm-app` succeeding (qmlcachegen catches QML syntax/binding errors), plus a manual run where a real display is available.

---

### Task 1: `Fab.qml` — floating "New folder" action button

**Files:**
- Create: `crates/app/qml/components/Fab.qml`
- Modify: `crates/app/build.rs`
- Modify: `crates/app/qml/main.qml`

**Interfaces:**
- Consumes: `MaterialShapes.ShapeCanvas` (`qml/shapes/ShapeCanvas.qml`, unmodified), `MaterialShapesFn.getSquare()`/`getCookie4Sided()` (`qml/shapes/material-shapes.js`, unmodified), `Icon` (existing component), `Color.scheme.primaryContainer`/`primaryContainerText` (existing token singleton), `window.openNewFolderDialog()` (existing function in `main.qml`, unchanged).
- Produces: `Fab { signal clicked }` — a 56×56 component with no other public API. Not consumed by any other task in this plan (Task 2 is independent).

- [ ] **Step 1: Write the component**

`crates/app/qml/components/Fab.qml`:

```qml
import QtQuick
import "../shapes" as MaterialShapes
import "../shapes/material-shapes.js" as MaterialShapesFn
import com.filemanager.app 1.0

// A standard (non-extended) M3 FAB for the single most common creation
// action — "New folder". Floats over the file view, fixed on screen
// regardless of scroll position (main.qml places it as a sibling of the
// ListView/GridView Loader, not inside it). Its press/release shape morph
// uses the vendored MatrialShapes polygon-morph engine via ShapeCanvas —
// the same primitive ShapeLoader.qml already uses for the busy spinner —
// a genuine catalog-shape morph, not just a corner-radius spring like
// Button.qml's press state.
Item {
    id: root

    signal clicked

    width: 56
    height: 56

    MaterialShapes.ShapeCanvas {
        anchors.fill: parent
        color: Color.scheme.primaryContainer
        // Idle: a softly rounded square — the closest MatrialShapes
        // catalog match to M3's baseline "large" FAB shape token (not a
        // plain circle). Pressed: the classic square-to-cookie flourish
        // associated with M3 Expressive FABs.
        roundedPolygon: _area.pressed ? MaterialShapesFn.getCookie4Sided() : MaterialShapesFn.getSquare()
    }

    Icon {
        anchors.centerIn: parent
        content: "add"
        iconSize: 24
        color: Color.scheme.primaryContainerText
    }

    MouseArea {
        id: _area
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
```

- [ ] **Step 2: Register the file in the build**

In `crates/app/build.rs`, add `"qml/components/Fab.qml"` to the `qml_files` list — right after `"qml/components/ButtonGroup.qml",`:

```rust
                "qml/components/ButtonGroup.qml",
                "qml/components/Fab.qml",
                "qml/components/ShapeLoader.qml",
```

- [ ] **Step 3: Wire it into `main.qml`**

In `crates/app/qml/main.qml`, the `fileViewArea` `Item` currently ends like this (the `Loader` that switches between list/grid, immediately followed by `fileViewArea`'s own closing brace):

```qml
                        Loader {
                            anchors.fill: parent
                            sourceComponent: fileModel.viewMode === "grid" ? gridComponent : listComponent
                        }
                    }
```

Add a `Fab` instance as a new sibling of that `Loader`, right after it (still inside `fileViewArea`, so it sits on top in paint order and stays fixed on screen since it isn't inside the scrolling view):

```qml
                        Loader {
                            anchors.fill: parent
                            sourceComponent: fileModel.viewMode === "grid" ? gridComponent : listComponent
                        }

                        Fab {
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 20
                            onClicked: window.openNewFolderDialog()
                        }
                    }
```

- [ ] **Step 4: Build**

Run: `cargo build -p fm-app`
Expected: builds successfully.

- [ ] **Step 5: Commit**

```bash
git add crates/app/qml/components/Fab.qml crates/app/build.rs crates/app/qml/main.qml
git commit -m "feat(app): add shape-morphing FAB for New folder"
```

---

### Task 2: `SelectionBadge.qml` — shape-morphing multi-select indicator

**Files:**
- Create: `crates/app/qml/components/SelectionBadge.qml`
- Modify: `crates/app/build.rs`
- Modify: `crates/app/qml/components/FileListItem.qml`
- Modify: `crates/app/qml/components/FileGridItem.qml`

**Interfaces:**
- Consumes: `MaterialShapes.ShapeCanvas`, `MaterialShapesFn.getCircle()`/`getGem()` (both unmodified), `Icon`, `Color.scheme.primary`/`primaryText`/`outline` (existing tokens), `fileModel.setSelected(name, selected)` (existing invokable, unchanged, from the multi-select feature), the delegates' existing `required property bool selected` and `rowArea`/`cellArea` `MouseArea` ids (both already present from the multi-select feature).
- Produces: `SelectionBadge { property bool selected; property bool hovered; signal toggleRequested }`. Not consumed by any other task in this plan (Task 1 is independent) — this is the last task.

- [ ] **Step 1: Write the component**

`crates/app/qml/components/SelectionBadge.qml`:

```qml
import QtQuick
import "../shapes" as MaterialShapes
import "../shapes/material-shapes.js" as MaterialShapesFn
import com.filemanager.app 1.0

// A small corner badge on a file/folder's icon, layered on top of the
// row/tile's existing flat selection tint (added by the multi-select
// feature — see FileListItem.qml/FileGridItem.qml's `selected`-bound
// Rectangle). Unselected, it's a faint circle outline that only shows on
// hover — a "tap to select" affordance; selected, it morphs (via the same
// ShapeCanvas/MatrialShapes primitive ShapeLoader.qml uses) into a
// filled gem shape with a checkmark on top. A gem (not a many-lobed
// cookie/burst shape) was chosen because a busier polygon's lobes blur
// together at this badge's small (20x20 typical) size.
Item {
    id: root

    property bool selected: false
    property bool hovered: false

    signal toggleRequested

    opacity: root.selected ? 1 : (root.hovered ? 0.5 : 0)
    Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

    MaterialShapes.ShapeCanvas {
        anchors.fill: parent
        color: root.selected ? Color.scheme.primary : "transparent"
        borderWidth: root.selected ? 0 : 1.5
        borderColor: Color.scheme.outline
        roundedPolygon: root.selected ? MaterialShapesFn.getGem() : MaterialShapesFn.getCircle()
    }

    Icon {
        anchors.centerIn: parent
        content: "check"
        iconSize: 12
        color: Color.scheme.primaryText
        opacity: root.selected ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggleRequested()
    }
}
```

- [ ] **Step 2: Register the file in the build**

In `crates/app/build.rs`, add `"qml/components/SelectionBadge.qml"` to the `qml_files` list — right after the `"qml/components/Fab.qml",` line added in Task 1:

```rust
                "qml/components/Fab.qml",
                "qml/components/SelectionBadge.qml",
                "qml/components/ShapeLoader.qml",
```

- [ ] **Step 3: Add the badge to `FileListItem.qml`**

In `crates/app/qml/components/FileListItem.qml`, the icon container `Item` currently looks like this (inside the `Row`, holding the hover-tint `Rectangle`, the `Icon`, and the thumbnail `Image`):

```qml
        Item {
            width: root.iconContainerSize
            height: root.iconContainerSize
            anchors.verticalCenter: parent.verticalCenter

            // The tonal container behind a folder icon is a hover-only
            // affordance, not a permanent decoration — a constant tinted
            // box behind every folder row reads as visual noise at list
            // scale.
            Rectangle {
                anchors.fill: parent
                radius: Shape.medium
                color: Qt.alpha(Color.scheme.primary, 0.12)
                opacity: (root.isDir && rowArea.containsMouse) ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            }

            Icon {
                anchors.centerIn: parent
                content: Format.iconForKey(root.iconKey, root.isDir)
                iconSize: root.iconSize
                color: root.isDir ? Color.scheme.primary : Color.scheme.surfaceVariantText
                visible: opacity > 0
                opacity: thumbnail.status === Image.Ready ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: 120 } }
            }

            Image {
                id: thumbnail
                anchors.fill: parent
                visible: opacity > 0
                opacity: status === Image.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 120 } }
                source: root.thumbnailPath.length > 0 ? root.thumbnailPath : ""
                sourceSize: Qt.size(root.iconContainerSize, root.iconContainerSize)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }
        }
```

Add a `SelectionBadge` as a new child of this same `Item`, right after the `Image`:

```qml
            Image {
                id: thumbnail
                anchors.fill: parent
                visible: opacity > 0
                opacity: status === Image.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 120 } }
                source: root.thumbnailPath.length > 0 ? root.thumbnailPath : ""
                sourceSize: Qt.size(root.iconContainerSize, root.iconContainerSize)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }

            SelectionBadge {
                width: 20
                height: 20
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: -4
                anchors.bottomMargin: -4
                selected: root.selected
                hovered: rowArea.containsMouse
                onToggleRequested: root.fileModel.setSelected(root.name, !root.selected)
            }
        }
```

- [ ] **Step 4: Add the badge to `FileGridItem.qml`**

In `crates/app/qml/components/FileGridItem.qml`, the icon container `Item` (inside the centered `Column`) currently ends with its thumbnail `Image`:

```qml
            Item {
                width: root.iconContainerSize
                height: root.iconContainerSize
                anchors.horizontalCenter: parent.horizontalCenter

                // Hover-only tonal container, matching FileListItem — see
                // its comment for why this isn't a permanent background.
                Rectangle {
                    anchors.fill: parent
                    radius: Shape.medium
                    color: Qt.alpha(Color.scheme.primary, 0.12)
                    opacity: (root.isDir && cellArea.containsMouse) ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                }

                Icon {
                    anchors.centerIn: parent
                    content: Format.iconForKey(root.iconKey, root.isDir)
                    iconSize: root.iconSize
                    color: root.isDir ? Color.scheme.primary : Color.scheme.surfaceVariantText
                    visible: opacity > 0
                    opacity: thumbnail.status === Image.Ready ? 0 : 1
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                }

                Image {
                    id: thumbnail
                    anchors.fill: parent
                    visible: opacity > 0
                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                    source: root.thumbnailPath.length > 0 ? root.thumbnailPath : ""
                    sourceSize: Qt.size(root.iconContainerSize, root.iconContainerSize)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }
            }
```

Add a `SelectionBadge` as a new child of this same `Item`, right after the `Image`:

```qml
                Image {
                    id: thumbnail
                    anchors.fill: parent
                    visible: opacity > 0
                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                    source: root.thumbnailPath.length > 0 ? root.thumbnailPath : ""
                    sourceSize: Qt.size(root.iconContainerSize, root.iconContainerSize)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }

                SelectionBadge {
                    width: 20
                    height: 20
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.rightMargin: -4
                    anchors.bottomMargin: -4
                    selected: root.selected
                    hovered: cellArea.containsMouse
                    onToggleRequested: root.fileModel.setSelected(root.name, !root.selected)
                }
            }
```

- [ ] **Step 5: Build**

Run: `cargo build -p fm-app`
Expected: builds successfully.

- [ ] **Step 6: Manual verification**

Per this project's established convention (no automated QML test harness), verify interactively if a real desktop session is available: `cargo run -p fm-app -- $HOME`, then check:
- A circular-ish FAB with a "+" icon floats bottom-right over the file list/grid, staying in place while scrolling.
- Pressing (mouse-down on) the FAB morphs its shape from the rounded square to the cookie shape, springing back on release; clicking it opens the New Folder dialog.
- Hovering a file/folder row (not selected) shows a faint circle-outline badge in the icon's bottom-right corner.
- Ctrl+clicking a row to select it morphs that badge into a filled gem shape with a checkmark, on top of the row's existing selection tint.
- Clicking directly on the badge toggles that item's selection the same way Ctrl+click does, without needing to hold Ctrl.
- Same behavior in grid view (tiles instead of rows).

If this sandboxed environment can't drive a real display (see this project's documented `QT_QPA_PLATFORM=offscreen` hang), `cargo build -p fm-app` succeeding is the verification ceiling — say so rather than claiming an interactive pass.

- [ ] **Step 7: Commit**

```bash
git add crates/app/qml/components/SelectionBadge.qml crates/app/build.rs crates/app/qml/components/FileListItem.qml crates/app/qml/components/FileGridItem.qml
git commit -m "feat(app): add shape-morphing selection badge to file/folder tiles"
```

---

## Plan Complete

Both new shape-morphing surfaces are built on the same, already-proven `ShapeCanvas` primitive `ShapeLoader.qml`'s busy spinner already uses — no new morph-engine code was needed, only two small components driving it off existing state (`pressed` for the FAB, `selected`/`hovered` for the badge). No Rust/backend changes were required; both features are purely visual. Not covered here, per the design spec's explicit non-goals: a FAB menu or second FAB action, and any new `GroupCard`-style grouped-card surfaces beyond the existing Properties/Settings dialogs.
