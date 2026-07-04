# Shape-Expressive UI — Design Spec

Date: 2026-07-04

## 1. Overview & Goals

Add two genuinely shape-morphing M3 Expressive surfaces, building on the
vendored `MatrialShapes` polygon-morph library (`crates/app/qml/shapes/`),
which today is wired into exactly one place — `ShapeLoader.qml`'s busy
spinner. The original M3 Expressive plan for this project explicitly
flagged an "extend-on-hover FAB" as the natural next use of this library;
this spec delivers that FAB, plus a second shape-morphing surface: a
selection-state badge on file/folder tiles.

Explicitly out of scope for this pass (confirmed with the user): no new
`GroupCard`-style grouped-card surfaces beyond the existing Properties and
Settings dialogs — this spec is shape-morphing only.

## 2. Shared primitive: `ShapeCanvas`

Both new components render through the *existing*, unmodified
`crates/app/qml/shapes/ShapeCanvas.qml` — no new Canvas/Morph plumbing is
needed. `ShapeCanvas` already does the whole job: set its
`roundedPolygon` property to a different shape-function result (from
`material-shapes.js`, e.g. `MaterialShapesFn.getCircle()`) and it morphs
between the old and new polygon automatically via its own internal
`Behavior on progress`, using the M3 Expressive "fast spatial" spring
curve already defined on the component. Neither new component reimplements
morphing — they just drive `ShapeCanvas.roundedPolygon` off a boolean
state, exactly like `ShapeLoader.qml` already does off its animation
timer.

## 3. `Fab.qml` — floating action button

**Location:** floats bottom-right inside the file view area
(`fileViewArea` in `main.qml`), as a sibling of the ListView/GridView
`Loader` (not inside it) so it stays fixed on screen regardless of scroll
position — anchored `right`/`bottom` with a 20px margin.

**Action:** a single action, "New folder" — calls the same
`window.openNewFolderDialog()` the background context menu's "New folder"
item already calls. No FAB menu, no second action (Paste stays
context-menu-only) — this keeps the FAB a standard (non-extended) M3 FAB,
the simplest correct shape for "the one most common creation action."

**Shape morph:** idle state renders `MaterialShapesFn.getSquare()` (a
softly rounded square — the closest catalog match to M3's baseline
"large" FAB shape token, not a plain circle) at `Color.scheme.primaryContainer`.
On press, it morphs to `MaterialShapesFn.getCookie4Sided()` — the classic
square-to-cookie press flourish associated with M3 Expressive FABs — and
springs back to the square on release. A centered `add` icon (via the
existing `Icon.qml`) sits on top, unaffected by the shape morph
underneath it.

**Size:** 56×56 (M3's standard FAB size), `ShapeCanvas` filling that
bound with `stretchToFill: false` (uniform scale, so the square/cookie
shapes don't skew).

## 4. `SelectionBadge.qml` — shape-morphing multi-select indicator

**Location:** a small (20×20) badge layered in the bottom-right corner of
each file/folder's icon or thumbnail — in `FileListItem.qml`'s icon
container, and in `FileGridItem.qml`'s icon container. This is *in
addition to* the existing flat `secondaryContainer` tint the whole row/tile
already gets when selected (from the multi-select feature) — the badge is
a corner affordance layered on top of that tint, the same two-part
treatment Google Photos uses for its own multi-select thumbnails (tint +
corner checkmark).

**Visibility:** always present at low opacity when the row is hovered (so
users discover the affordance), fully opaque when the entry is actually
selected; invisible otherwise (matching the row's own existing hover/
selected reactive properties — `containsMouse`, `selected`).

**Shape morph:** unselected state renders `MaterialShapesFn.getCircle()`
as an outline only (transparent fill, `Color.scheme.outline` border) — a
plain "tap to select" affordance. Selected state morphs to a *filled*
`MaterialShapesFn.getGem()` (a small diamond-like silhouette, chosen over
a lobed cookie shape because it stays legible at 20px — a many-point
cookie/burst shape's lobes blur together at that size) in
`Color.scheme.primary`, with a small `check` `Icon.qml` glyph centered on
top, faded in only once selected (the icon itself doesn't morph — only the
badge shape underneath it does).

**Interaction:** clicking the badge toggles selection the same way
Ctrl+click on the row does (`fileModel.setSelected(name, !selected)`) —
convenient for touch/precise clicking without needing a modifier key.
Clicking elsewhere on the row keeps its existing plain/Ctrl/Shift
semantics, unchanged by this spec.

**Component interface:** `SelectionBadge` takes two inputs and emits one
signal — `property bool selected`, `property bool hovered`, and
`signal toggleRequested`. It does not read the model or the row's own
`containsMouse` directly; the containing delegate wires both:

```qml
SelectionBadge {
    selected: root.selected
    hovered: rowArea.containsMouse   // cellArea.containsMouse in the grid delegate
    onToggleRequested: root.fileModel.setSelected(root.name, !root.selected)
}
```

The badge's own `MouseArea` (covering just its 20×20 bounds) naturally
takes the click before it reaches the row's underlying `MouseArea` — QML
doesn't forward an already-accepted press to a sibling beneath it — so a
badge click and a plain row click are already mutually exclusive with no
extra guard needed.

## 5. File structure

- Create: `crates/app/qml/components/Fab.qml`
- Create: `crates/app/qml/components/SelectionBadge.qml`
- Modify: `crates/app/qml/main.qml` — add one `Fab` instance to
  `fileViewArea`
- Modify: `crates/app/qml/components/FileListItem.qml` — add one
  `SelectionBadge` instance in the icon container
- Modify: `crates/app/qml/components/FileGridItem.qml` — add one
  `SelectionBadge` instance in the icon container
- Modify: `crates/app/build.rs` — register the two new QML files

No Rust/backend changes — both features are purely QML/visual, driven
entirely by state (`selected`, `containsMouse`, `pressed`) that already
exists on the model or the delegates.

## 6. Non-goals

- No FAB menu / second action (Paste stays where it is).
- No new `GroupCard` surfaces (Sidebar, ViewOptionsMenu, and the
  right-click menus keep their current styling — confirmed with the user).
- No aggregate/bulk visual treatment beyond the existing per-row tint +
  the new per-row badge — this spec doesn't touch the multi-select
  *logic* at all, only adds a visual affordance on top of it.

## 7. Testing

Per this project's established convention (no automated QML test
harness): verified via `cargo build -p fm-app` (qmlcachegen catches QML
syntax/binding errors) and, where a real display is available, a manual
run confirming the FAB morphs on press/release and the selection badge
morphs when toggling selection via click, Ctrl+click, and the badge
itself.
