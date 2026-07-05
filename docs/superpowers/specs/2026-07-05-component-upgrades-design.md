# Component upgrades slice (UI/UX roadmap items 2, 10, 11)

## Context

Third slice of `docs/ui-ux-roadmap.md`: the FAB menu (item 2), the
split button for view options (item 10), and the selected-tile shape
morph (item 11). The showcase slice for the vendored shape-morph
library and the connected-shape language `ButtonGroup` established.

Motion rule: everything here is component-level state change —
`SpringAnimation`, not bezier pairs.

## New file backend (fm-core + bridge)

"New file" in the FAB menu has no backend today; this slice adds it:

- **`fm_core::ops::create_file(parent: &Path, name: &str) ->
  io::Result<PathBuf>`** — creates an empty file, erroring if the name
  already exists (same contract as `create_folder`). Unit tests live in
  `crates/core/tests/` (the project's external-test convention): happy
  path and already-exists error.
- **Bridge `createFile(name)`** invokable on FileListModel, cloned from
  `create_folder`'s shape: block_on the op, record
  **`UndoOp::CreateFile { path }`** (new variant mirroring
  `CreateFolder` — undo trashes the created file, `describe()` returns
  "Created file"), emit `operation_completed`/`error_occurred`, then
  `refresh_entries_diff()`.
- **`NewFileDialog.qml`** — a clone of `NewFolderDialog.qml` with file
  wording ("New File", "File name"), emitting `accepted(name)`.
  A parameterized shared dialog was considered and rejected: the clone
  is smaller than the generalization and the two dialogs may diverge
  (extension hints, templates) later.

## Item 2 — FabMenu.qml (new component)

A self-contained component owning the FAB and its action stack;
`main.qml` swaps its bare `Fab { ... }` for `FabMenu { ... }` in the
same anchored position. `Fab.qml` itself is left untouched.

- **Closed:** renders exactly like today's FAB — 56px, primaryContainer
  ShapeCanvas, square→cookie press morph, add glyph.
- **Open (click):** the add glyph rotates 45° into a close ×
  (`Behavior on rotation` spring), the FAB body morphs to the cookie
  shape, and the labeled actions spring up above it, staggered
  bottom-to-top — each action a pill row (`surfaceContainerHigh`, label
  + 20px icon, Ripple, Tooltip-free — the label IS the label) entering
  via `SpringAnimation` on a per-item vertical offset and opacity
  (~40ms stagger between items).
- **Actions, top to bottom when open:** New folder (`create_new_folder`),
  New file (`note_add`), Paste here (`content_paste`). Paste here is
  only included when `fileModel.canPaste()` returns true at open time
  (evaluated on each open, like ContextMenu does).
- **Dismissal:** clicking the FAB again (now ×), choosing an action,
  clicking anywhere outside (a transparent full-window MouseArea active
  only while open), or Esc. The component exposes `property var
  fileModel` (bound as `window.fileListModel`) and signals
  `newFolderRequested()`, `newFileRequested()`, `pasteRequested()`.
- main.qml wires: newFolderRequested → `openNewFolderDialog()`,
  newFileRequested → new `openNewFileDialog()` helper + Loader
  (standard popup-Loader pattern, added to `anyPopupOpen`),
  pasteRequested → `fileModel.pasteEntry()`.
- The FabMenu itself is NOT part of `anyPopupOpen` (it's a FAB, not a
  modal; shortcuts staying live matches the selection toolbar's
  precedent). Its Esc handling uses its own `Keys`/`Shortcut` scoped to
  the open state — it must not swallow Esc when closed. Note:
  `StandardKey.Cancel`'s existing clear-selection Shortcut will also
  fire on that Esc press; acceptable — both are "dismiss" semantics.

## Item 10 — SplitButton.qml (new component)

Replaces BOTH the `ButtonGroup` list/grid toggle AND the `tune` icon
button on the right of `TopAppBar` — one M3 Expressive split button:

- **Leading segment:** shows the icon of the view you'd switch TO
  (`grid_view` while in list mode, `view_list` in grid mode) plus a
  matching tooltip ("Switch to grid view" / "Switch to list view");
  click toggles the mode (emits the existing
  `listViewRequested`/`gridViewRequested`).
- **Trailing segment:** narrow, `arrow_drop_down` chevron, tooltip
  "View options"; click emits `optionsRequested(x, y)` at the segment's
  scene position (same signature TopAppBar already forwards).
- **Visuals:** ButtonGroup's connected-shape language — pill outer
  corners, `innerRadius: 4` inner corners, 2px gap,
  `surfaceContainerHighest` fill, `Ripple` per segment. While the
  options menu is open (`menuOpen: bool` property set by main.qml's
  Loader active state via TopAppBar), the trailing segment's inner
  corners spring to fully rounded — the M3 Expressive split-button
  open morph. Springs via `Behavior on` each radius property.
- **API:** `property string viewMode`, `property bool menuOpen`,
  signals `toggleRequested()` and `menuRequested(real x, real y)`.
  TopAppBar keeps its outward signals unchanged; only its right-side
  row swaps the two old controls for `SplitButton`.

## Item 11 — selected-tile shape morph (FileGridItem.qml)

The existing selected backing (`secondaryContainer` Rectangle) morphs
its corners when selection changes: `radius: root.selected ?
Shape.extraLarge : Shape.medium`, animated with a `Behavior on radius`
`SpringAnimation` (Motion.springStandard). The existing opacity fade
stays. No layout or size change — a whisper, per the roadmap, of the
removed selection badge.

## Scope

- Rust: `create_file` op + tests, `createFile` invokable,
  `UndoOp::CreateFile` variant (record/describe/execute_undo arms).
- QML: new `FabMenu.qml`, `SplitButton.qml`, `NewFileDialog.qml`;
  `TopAppBar.qml` right-side swap; one `Behavior` in
  `FileGridItem.qml`; `main.qml` FabMenu swap + NewFileDialog Loader.
- `Fab.qml` and `ButtonGroup.qml` are left untouched (ButtonGroup keeps
  its other potential uses; nothing else consumes it today but it's a
  finished generic component).
- Items 8, 9 remain the next slice; item 7 its own spec.

## Verification

- `cargo test -p fm-core` gains create_file tests; `cargo build -p
  fm-app` + `cargo test -p fm-app` stay the ceiling.
- Interactive verification by the user:
  - FAB opens into the labeled stack (staggered springs), × closes,
    outside-click/Esc close; New folder/New file dialogs create
    entries; both are undoable via the snackbar; Paste here appears
    only with a clipboard.
  - the split button toggles list/grid from its leading side; the
    chevron opens View options and its corners morph while open.
  - selecting a grid tile visibly rounds its corners; deselecting
    returns them.
