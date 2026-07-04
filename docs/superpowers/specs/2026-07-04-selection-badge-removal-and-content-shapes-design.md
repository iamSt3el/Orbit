# Selection badge removal + decorative content-area shapes

## Context

`SelectionBadge.qml` (added in a recent shape-morphing session) overlays a
corner badge on file/folder icons in `FileListItem.qml` and
`FileGridItem.qml` that morphs into a filled gem shape with a checkmark when
an item is selected. The user wants this removed — selection is still shown
via the existing `secondaryContainer` background tint on the row/tile, which
is untouched by this change and remains sufficient on its own.

Separately, the user wants some M3 Expressive shape decoration added to the
file view content area, to keep some of that visual language elsewhere now
that it's leaving the icons.

## 1. Remove the selection badge

- Delete the `SelectionBadge { ... }` block (and its now-unused
  `onToggleRequested` wiring) from `FileListItem.qml` and `FileGridItem.qml`.
- Delete `crates/app/qml/components/SelectionBadge.qml` entirely — nothing
  else references it.
- No change to the row/tile selection tint logic.

## 2. Decorative background shapes behind the file list/grid

New component `crates/app/qml/components/DecorativeShapesBackground.qml`:

- Two static `ShapeCanvas` instances (from `qml/shapes/`), each ~220-280px,
  filled with `Color.scheme.primary` at ~5% opacity, no border, no morph
  animation (shape set once, not swapped).
- Different shapes for variety: e.g. `getPentagon()` and `getCookie9Sided()`
  from `material-shapes.js`.
- One positioned bleeding off the top-right corner, one off the bottom-left
  corner, of its parent.
- No `MouseArea` — must not intercept clicks/drag-select.

Wiring in `main.qml`:

- Instantiate `DecorativeShapesBackground` inside the `fileViewArea` Item,
  anchored to fill, declared *before* the `Loader` that swaps in
  `listComponent`/`gridComponent` (line ~529) so it paints behind the
  ListView/GridView delegates — sibling Items without explicit `z` stack in
  declaration order.
- Relies on `fileViewArea`'s existing `clip: true` to crop the
  off-corner bleed.
- Applies to both list and grid view modes identically, since both share the
  same `fileViewArea` parent.

## Verification

Per project convention, `cargo build -p fm-app` (runs qmlcachegen, catches
QML syntax/binding errors) is the automated ceiling; no QML test harness
exists. Interactive visual verification is done by the user themselves, not
via the `run` skill (see `feedback-verification-style` memory).
