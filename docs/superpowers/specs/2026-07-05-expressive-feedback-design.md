# Expressive feedback slice (UI/UX roadmap items 1, 3, 5)

## Context

First slice of `docs/ui-ux-roadmap.md`, per its suggested order: the
contextual floating selection toolbar (item 1), animated row/tile
add & remove (item 3), and the loading state (item 5). One coherent
theme: the app visibly reacting to what just happened — selection,
external file changes, an in-flight listing.

Motion rule (from the original design spec) applies throughout:
component/spatial state changes use `SpringAnimation`; screen-level
transitions use `Easing.BezierCurve` pairs from `Motion.qml`.

## New bridge state (`file_list_model.rs`)

Two new qproperties on `FileListModel`, both following the existing
`isBusy` pattern (plain qproperty, cxx-qt auto-generates the change
signal QML binds to):

- **`selectionCount: i32`** (`selection_count`) — reactive mirror of
  `selected.len()`. The existing `selectedCount()` invokable stays (it
  is called imperatively in many places); the property exists so QML
  can *bind* to selection size. Updated via a small
  `sync_selection_count()` helper called at every point `selected`
  mutates:
  - `set_selected()`
  - `select_all()`
  - `clear_selection()`
  - `navigate()` (clears selection)
  - `apply_entries_diff()` (prunes selected names that vanished)

  If any other mutation point exists or is added, the helper is the
  single thing to call — it reads `selected.len()` rather than
  incrementally counting, so it cannot drift.

- **`isListing: bool`** (`is_listing`) — true while an async `navigate()`
  listing is in flight and the view is (possibly) empty. Set true in
  `navigate()` right after entries are cleared; set false in the
  generation-guarded apply callback — on both the success and error
  paths, but only when the callback's generation is still current
  (a stale callback must not clear a newer navigation's flag).
  `refresh_entries_diff()` (watcher refreshes) does NOT touch it —
  the view isn't empty during a refresh, so no loading state is shown.

## Item 1 — SelectionToolbar.qml (new component)

A pill-shaped M3 Expressive floating toolbar, horizontally centered near
the bottom of `fileViewArea` (placed in `main.qml` as a sibling of the
view Loader, like the Fab, and above it in z; the Fab keeps its corner).

- **Container:** `Color.scheme.surfaceContainerHigh` fill, full-pill
  radius (height/2), elevation shadow per `Elevation` tokens, small
  internal padding — matching the app's hand-built component style
  (plain Rectangle/Item, no Quick Controls).
- **Contents (normal folders):** "N selected" label (Type tokens) —
  then Copy, Cut, Delete icon buttons with tooltips — divider — Close.
  - Copy → `fileModel.copySelection()`
  - Cut → `fileModel.cutSelection()`
  - Delete → `window.openDeleteSelectionConfirmDialog(count)` (the
    confirming path, matching the context menu, not the Delete key's
    immediate trash)
  - Close → `fileModel.clearSelection()` (which hides the toolbar)
- **Contents (in Trash, `currentPath === trashPath`):** Copy/Cut/Delete
  swap for Restore (`restoreSelection()`) and Delete Permanently
  (`openDeletePermanentlySelectionConfirmDialog(count)`); count label,
  divider, and Close stay.
- **Visibility:** shown while `fileModel.selectionCount >= 2`. Single
  selection keeps today's flows (context menu, shortcuts) — no toolbar.
- **Motion:** spatial spring, not a fade. The toolbar rests below the
  bottom edge (translated down by its height + margin) and springs up
  into place on show (`SpringAnimation` on the vertical offset), sinks
  back down on hide; opacity rides along secondarily. While the count
  changes but stays ≥ 2, only the label text updates — no re-entrance.
- **Shortcut interplay:** the toolbar is not a popup — it must NOT be
  added to `anyPopupOpen` (shortcuts stay live while it shows; it
  merely mirrors the same selection those shortcuts act on).

## Item 3 — animated add/remove (main.qml only)

`add`, `remove`, and `displaced` transitions on BOTH the ListView and
the GridView components:

- **add:** scale 0.8 → 1.0 + opacity 0 → 1, spring-flavored
  (`SpringAnimation`), settling in roughly ≤ 250ms.
- **remove:** opacity → 0 + slight scale-down, short screen-exit feel
  (~150ms, emphasized-accelerate `Easing.BezierCurve` from `Motion`).
  `ViewTransition` remove runs while the delegate is being destroyed —
  animate only opacity/scale, never bindings that touch model roles.
- **displaced:** neighbours glide to their new slot (spring on x/y).
- **populate deliberately unset:** navigation and initial listings must
  not animate hundreds of rows into place. Only watcher-driven diff
  inserts/removals (and the app's own single-item operations) animate.
  The watcher already batches bursts; transitions stay ≤ 250ms so a
  500-file wave reads as one settled batch, not a cascade.

## Item 5 — loading state (main.qml + the isListing property)

A centered `ShapeLoader` (size ~48, primary color) in `fileViewArea`,
shown only when a listing has been in flight for 150ms+:

- A `Timer` (interval 150, started when `fileModel.isListing` becomes
  true, stopped/reset when false) gates visibility so fast local
  listings never flash the spinner.
- Disambiguates "still listing" (spinner) from "empty folder" (blank
  for now — roadmap item 6, empty states, later builds on this same
  spot and can distinguish the two via `isListing`).
- Sits above `DecorativeShapesBackground`, below the popups.

## Scope

- Rust changes are bridge-only (`file_list_model.rs`): two qproperties
  plus their update points. No fm-core changes.
- No changes to selection *semantics* (anchor math, sweep, Ctrl/Shift
  behavior) — the toolbar is a pure consumer of existing state.
- Item 7's cursor/keyboard work is explicitly out of scope (own spec).

## Verification

- `cargo build -p fm-app` — automated ceiling for QML + bridge wiring.
- `cargo test -p fm-app` / `cargo test -p fm-core` — existing tests
  keep passing; no new testable pure functions are introduced.
- Interactive verification by the user (per project convention):
  - select 2+ items → toolbar springs up; actions behave as the
    context-menu equivalents; Esc/Close clears and it sinks away;
    in Trash it shows Restore/Delete Permanently instead.
  - `touch`/`rm` files in a terminal while watching the folder → rows
    animate in/out instead of popping.
  - navigate into a huge directory (e.g. `/usr/lib`) → spinner appears
    after a beat, replaced by content; navigating between small local
    folders never flashes it.
