# Multi-Select — Design Spec

Date: 2026-07-04

## 1. Overview & Goals

Add multi-item selection to the file list/grid views, with standard desktop
file-manager interactions (click, Ctrl+click, Shift+click, drag rubber-band,
Ctrl+A), and wire it into the existing bulk-capable operations: copy, cut,
delete (to Trash), and duplicate.

Goal: match the interaction conventions of Nautilus/Dolphin/Explorer closely
enough that it needs no explanation, using only this project's existing
building blocks (no Qt Quick Controls, same M3 token system).

## 2. Where selection lives

Selection state lives in `FileListModelRust` (Rust), not in QML, as
`selected: std::collections::HashSet<String>` (entry names, unique within a
single directory listing). It's exposed to QML the same way every other
per-row fact already is: a new model role (`SELECTED_ROLE`, role name
`selected`), so `FileListItem`/`FileGridItem` gain a
`required property bool selected` bound automatically like `name`/`isDir`
today.

This is the natural fit for a `QAbstractListModel`-backed view and — more
importantly — it means every bulk action (copy/cut/delete/duplicate) can be
an **argument-less invokable** that reads `self.selected` directly. No
`QStringList` marshaling across the QML/Rust boundary is needed for bulk
operations.

Selection is pruned automatically after every `refresh_entries_diff()` (the
existing model-refresh path used by create/rename/delete/paste today) — a
name that disappears from the listing (deleted elsewhere, renamed) is
dropped from the selection set at the same time, so it can never point at a
stale entry.

Selection is entirely cleared on `navigate()` (a new folder is a new
selection context, matching every reference file manager).

## 3. Backend (`fm-app`'s `FileListModelRust`) changes

**New role:**
- `SELECTED_ROLE` (role name `selected`, `bool`) — alongside the existing
  `name`/`isDir`/`size`/etc. roles.

**New invokables (all `#[qinvokable]` on `FileListModel`):**
- `setSelected(name: &QString, selected: bool)` — used by click/Ctrl-click
  and by drag-rubber-band as it sweeps over delegates. Emits `dataChanged`
  for just that row.
- `selectRange(fromName: &QString, toName: &QString)` — Shift+click; QML
  passes the last-clicked ("anchor") name and the newly-clicked name, Rust
  resolves both to row indices in the current (already-sorted/filtered)
  `entries` list and selects everything between them inclusive. Doing the
  index resolution in Rust (not QML) keeps QML from needing to know sort
  order.
- `selectAll()` — selects every currently-listed entry (respecting the
  active search-filter/hidden-file view, since `entries` already reflects
  that).
- `clearSelection()`
- `selectedCount() -> i32` — read-only getter QML uses to decide "1 item"
  vs "N items" menu wording and to gate bulk-action visibility.

**Clipboard becomes multi-item:**
- `clipboard_path: Option<PathBuf>` + `clipboard_is_cut: bool` becomes
  `clipboard_paths: Vec<PathBuf>` + `clipboard_is_cut: bool` (one shared cut
  flag — mixing a cut batch and a copy batch in one clipboard isn't a
  real-world need).
- `copyEntry(name)` / `cutEntry(name)` (single-item, used by the existing
  per-item context-menu actions) become thin wrappers that set
  `clipboard_paths` to a single-element vec — no behavior change for the
  single-item case.
- New `copySelection()` / `cutSelection()` — snapshot every currently
  selected name (resolved to full paths against `current_path`) into
  `clipboard_paths`.
- `pasteEntry()` (unchanged name/signature) now iterates `clipboard_paths`
  sequentially: computes one combined `total` (sum of `fm_core::ops::path_size`
  across all clipboard entries) up front so the existing progress bar/label
  machinery (`isBusy`, `busyLabel`, `transferDoneBytes`, `transferTotalBytes`,
  `transferSpeedLabel`) needs no QML-visible changes, resolves per-item name
  collisions with the existing `unique_paste_destination` helper, and does
  one `refresh_entries_diff()` at the end instead of per-item. A cut batch
  clears the whole clipboard after pasting once (matching today's
  single-item behavior); a copy batch can be pasted repeatedly.

**Delete/duplicate become bulk-aware:**
- `deleteEntry(name)` (existing, single-item, still used by
  `ItemContextMenu`'s per-item Delete) is unchanged.
- New `deleteSelection()` — moves every selected entry to Trash. Currently
  `deleteEntry` runs synchronously via `runtime().block_on(...)`, acceptable
  for one item; for a bulk selection this moves to the same
  background-task-plus-`qt_thread().queue()` pattern `pasteEntry` already
  uses (so deleting many items doesn't hitch the UI thread), showing
  `isBusy`/`busyLabel: "Deleting…"` without byte-progress (Trash moves are
  fast — a spinner via the existing `ShapeLoader`/`isBusy` ambient indicator
  is enough, no new progress-bar UI needed).
- `duplicateEntry(name)` (existing, single-item) is unchanged.
- New `duplicateSelection()` — same background-task pattern, looping
  `fm_core::ops::duplicate` over every selected path, one refresh at the end.

## 4. QML: selection interactions

Both `FileListItem` and `FileGridItem` gain `required property bool
selected` (a normal model-role-bound property, like `isDir`). Visual
treatment: a persistent `Color.scheme.secondaryContainer` background tint
— distinct from the transient hover tint (`Elevation.surfaceAt(1)`,
opacity-animated) both components already have, which continues to layer
on top of a selected row on hover.

**Click semantics** (both list and grid delegates):
- Plain left click, no modifier: `setSelected` this entry only —
  practically, `clearSelection()` then `setSelected(name, true)` — and
  record it as the new "anchor" for future Shift+click.
- Ctrl+click: `setSelected(name, !currentlySelected)` — toggles just this
  one, doesn't touch the rest. Updates the anchor to this entry.
- Shift+click: `selectRange(anchorName, name)` — doesn't change the anchor
  (a second Shift+click extends/contracts the same range from the same
  start, matching standard behavior).
- Double-click: unchanged (still opens/navigates), regardless of modifiers
  beyond plain-left-button (already gated by `mouse.button !== Qt.LeftButton`
  today).
- Right-click: if this entry is already part of the current (possibly
  multi-item) selection, the selection is left as-is and the context menu
  acts on all of it; if it isn't, the click first replaces the selection
  with just this entry (matching Nautilus/Dolphin/Explorer), then the menu
  opens as normal.

The "anchor" (last plain-clicked or Ctrl-clicked name, for Shift+click range
math) is small transient UI state — kept in QML (on the `ListView`/
`GridView` instance itself, e.g. a `property string selectionAnchor`), not
in Rust, since it's not part of "what's selected," just an interaction
detail.

**Drag rubber-band select:** both `listBackgroundArea`/`gridBackgroundArea`
(the existing background `MouseArea`s in `main.qml`'s `ListView`/`GridView`,
currently `acceptedButtons: Qt.RightButton` only, used for the folder
background context menu) gain left-button handling:
- On press (no modifier): `clearSelection()`, record the press position,
  begin tracking a drag rectangle.
- On press (Ctrl held): keep the existing selection, just start the drag
  rectangle on top of it (additive rubber-band, matching Nautilus).
- On move past a small threshold: show a semi-transparent
  `Color.scheme.primary`-tinted `Rectangle` (low opacity fill + a 1px
  border at full opacity) sized/positioned from the press point to the
  current point; each move, walk the view's `contentItem.children` (the
  Flickable's currently-instantiated, i.e. visible, delegate items — the
  standard QML technique for rubber-band selection over a virtualized
  view), and `setSelected(child.name, true)` for every child whose mapped
  geometry intersects the drag rectangle.
- On release: hide the rectangle. (Only currently-visible delegates can be
  swept — no auto-scroll-while-dragging-near-an-edge in this iteration;
  noted as an explicit non-goal below.)
- A plain click with no drag (press+release without crossing the movement
  threshold) on empty space clears the selection either way — on
  left-click it just deselects; on right-click it deselects *and then*
  opens the background context menu (matching every reference file
  manager: right-clicking empty space never leaves a stale selection
  behind for "Select All"/"Paste" to look inconsistent next to).

**Keyboard:** `Ctrl+A` → `selectAll()`; `Escape` → `clearSelection()` (only
takes effect when no dialog/menu currently owns focus — those already
handle their own `Escape` via `Keys.onEscapePressed`, so this is just an
additional handler at the view level, not a conflict).

## 5. QML: menu/action wiring

`ItemContextMenu` gains a `selectionCount: int` property (set from
`fileModel.selectedCount()` at popup time, alongside the existing
per-entry snapshot fields). When `selectionCount > 1`:
- Hidden: Open, Rename, Copy Path, Properties (single-item-only actions —
  no aggregate Properties view in this iteration, see non-goals).
- Kept, with a count-aware label: Cut, Copy, Duplicate, Delete → e.g.
  "Delete 3 items" instead of "Delete".
- Their handlers call `cutSelection()`/`copySelection()`/
  `duplicateSelection()`/`deleteSelection()` instead of the single-name
  `cutEntry(name)`/etc. (the existing delete-confirmation `ConfirmDialog`
  flow is reused, just with a pluralized message and calling
  `deleteSelection()` on confirm).

When `selectionCount <= 1` (right-clicking a lone selected item, or an
item that becomes the sole selection on right-click), the menu is
unchanged from today.

`ContextMenu` (the folder-background menu) gains one new item, "Select
All", calling `fileModel.selectAll()` — cheap discoverability addition
alongside the Ctrl+A shortcut.

## 6. Explicit non-goals (this iteration)

- **Drag-and-drop of selected items** (dragging files onto another folder
  row, or out to another application) — this spec is rubber-band *selection*
  only, not drag-to-move. The existing design spec already lists
  drag-and-drop as out of scope for v1.
- **Auto-scroll while rubber-band-dragging near a view edge** — selection
  during a drag only affects currently-visible (already-instantiated)
  delegates.
- **Aggregate Properties for a multi-item selection** (e.g. "12 items,
  340 MB total") — Properties stays single-item only; it's hidden from the
  context menu once more than one item is selected.
- **Cross-directory selection** — selection is scoped to the current
  folder's listing, same as today's clipboard; navigating away clears it.

## 7. Testing

- Rust: unit tests for the new selection invokables (`setSelected`,
  `selectRange` index math, `selectAll`, pruning-on-refresh) and for
  multi-item clipboard/paste (`copySelection`/`cutSelection` populating
  `clipboard_paths`, `pasteEntry` handling more than one clipboard entry
  including name collisions) — following this crate's existing
  `tempfile`-fixture pattern.
- QML/UI: manual verification via the `run` skill/workflow once built,
  per this project's existing testing convention (no automated QML test
  harness).
