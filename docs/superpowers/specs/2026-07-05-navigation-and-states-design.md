# Navigation & states slice (UI/UX roadmap items 4, 6, 12)

## Context

Second slice of `docs/ui-ux-roadmap.md`, after the expressive-feedback
slice (2026-07-05-expressive-feedback-design.md) landed: navigation
transitions (item 4), empty states (item 6), and the current-folder
headline (item 12). One theme: navigating reads as movement through a
hierarchy, and a contentless view always says why it's contentless.

Motion rule applies: these are screen-level transitions —
`Easing.BezierSpline` + `easing.bezierCurve` pairs from `Motion.qml`,
not springs. (The expressive-feedback slice's toolbar/row springs are
component-level; this slice is the other half of the rule.)

## New bridge state (`file_list_model.rs`)

One qproperty, following the `isBusy`/`isListing` pattern:

- **`searchActive: bool`** (`search_active`) — true while a non-empty
  search query filters the view. Set inside the existing
  `set_search_query()` invokable (`!query.is_empty()`), cleared in
  `navigate()` where `search_query` is already reset. The query string
  itself stays Rust-side — QML only needs the boolean to pick the
  "no matches" empty-state variant. (It can't be a plain qproperty on
  the query itself: `setSearchQuery` does a model reset the generated
  setter couldn't.)

## Item 4 — navigation transitions (`main.qml` only)

**Direction is derived in QML, not Rust.** `main.qml` watches
`currentPathChanged` and compares the new path against the previous
one (kept in a plain window property):

- new path is inside the old one (`newPath.startsWith(oldPath + "/")`,
  or old is "/") → **forward**
- old path is inside the new one → **back**
- anything else (sidebar jump, path-bar edit) → **neutral**

**The animation runs when content arrives, not when the path changes.**
Navigation empties the view instantly (async listing); animating at
path-change time would animate a blank pane and let the real rows pop
in with no motion. Instead the captured direction waits until
`isListing` flips false, then plays a one-shot entrance on the view
host (the `Item` wrapping the view `Loader`):

- forward: translateX from +24 → 0, opacity 0 → 1
- back: translateX from −24 → 0, opacity 0 → 1
- neutral: opacity 0 → 1 only
- pair: `Motion.emphasizedDecelerate` (400ms) for both properties

Watcher refreshes never trigger it (they don't touch `isListing`).
A navigation that resolves before the previous animation finishes
restarts it — last direction wins; no queue.

**List↔grid toggle:** in the view `Loader`'s `onLoaded`, the fresh view
animates in with opacity 0 → 1 and scale 0.96 → 1 on the
`Motion.standard` pair (300ms) — a crossfade-feeling swap instead of
the instant flip. This also runs at startup (first load) and after a
navigation reload of the Loader — both harmless, both read as content
arriving.

## Item 6 — empty states (new `EmptyState.qml` + `main.qml`)

Shown centered in `fileViewArea` when `!fileModel.isListing` and the
active view has zero rows (the Loader gets an id; views already expose
a notifying `count`). Variant priority, first match wins:

1. **`searchActive`** → "No matches" / "Nothing here matches your
   search." — text only.
2. **In Trash** (`currentPath === trashPath`) → "Trash is empty" /
   "Deleted items land here before they're gone for good." — text only.
3. **Otherwise** → "This folder is empty" / "Drop files here or create
   something." — plus a tonal **New folder** button (existing `Button`
   component) that calls `window.openNewFolderDialog()`.

Visual: one large soft catalog shape (`ShapeCanvas`, ~160px, filled
with `Qt.alpha(Color.scheme.primary, 0.10)`) behind/above a title
(`Type.titleLarge`)
and a body line (`Type.bodyMedium`, muted on-surface tone), echoing
`DecorativeShapesBackground`'s language. Entrance: opacity + slight
scale on `Motion.standardDecelerate` — screen-level, bezier.

The component takes `fileModel` (as `window.fileListModel` — see the
Loader-shadowing note in main.qml) and emits `newFolderRequested()`;
main.qml wires that to `openNewFolderDialog()`. It must not intercept
clicks outside its visible content (background context menu and
empty-space drops keep working; the shape/text region itself may eat
its own clicks).

## Item 12 — current-folder headline (`main.qml` header column)

A ~44px row inserted in the content `ColumnLayout` between the
`TopAppBar` and `fileViewArea`, left-aligned with the content:

- Text: the folder's display name — last path segment; `/` shows as
  "Root"; the trash path shows as "Trash".
- Style: `Type.headlineSmall`, `Color.scheme.surfaceText`.
- On navigate, old and new name crossfade: two stacked `Text` items —
  the retiring name fades out while the incoming one fades in —
  `Motion.standard` pair. No horizontal movement (the view host below
  already carries the directional motion; doubling it here would be
  noise).
- The Nebula-style 56px app-bar row itself is untouched.

## Scope

- Rust: only the `searchActive` qproperty. No fm-core changes.
- No changes to the expressive-feedback slice's behavior; item 6
  deliberately keys off the same `isListing` the spinner uses — spinner
  while listing, empty state only after the listing lands empty.
- Items 2, 8, 9, 10, 11 stay future slices; item 7 its own spec.

## Verification

- `cargo build -p fm-app`, `cargo test -p fm-app`, `cargo test -p
  fm-core` — the automated ceiling.
- Interactive verification by the user:
  - navigate into a folder → content slides in from the right; up/back
    → from the left; sidebar jump → plain fade. `/usr/lib` still shows
    the spinner first, then slides in.
  - empty folder → shape + "This folder is empty" + New folder button
    (opens the dialog); empty Trash and a no-hit search show their
    text-only variants; the states never flash during loading.
  - headline shows the folder name, crossfades on navigate, reads
    "Root" at `/` and "Trash" in Trash.
  - list↔grid toggle crossfades instead of snapping.
