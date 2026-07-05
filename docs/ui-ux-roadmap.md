# UI/UX Roadmap — M3 Expressive

> **Status (2026-07-05):** items 1–14 and 16–21 shipped (items 1–6 and
> 10–12 via specs/plans under `docs/superpowers/`; the rest straight to
> implementation by request — one commit per feature in git history).
> Remaining: **15** (conflict dialog) and **22–26** — each is a
> session-sized build (async UI round-trip, preview pane, tabs, volume
> listing, recursive search, desktop-entry parsing) best taken one at a
> time.

Candidate UI/UX work, keeping genuine M3 Expressive fidelity (the
project's #1 goal) front and center. Grounded in the existing component
set: shape-morphing `Fab`, `ShapeLoader`, wavy progress bars,
`DecorativeShapesBackground`, the vendored shape-morphing library under
`qml/shapes/`, and the `Color/Type/Shape/Elevation/Motion` token
singletons. Companion to `docs/optimization-roadmap.md`; each item goes
through the usual spec → plan cycle (see `docs/superpowers/`) before
implementation.

Motion rule reminder (from the original design spec): spatial/component
state changes use `SpringAnimation`; screen-level transitions use
`Easing.BezierCurve` duration/easing pairs from `Motion.qml`. Don't mix
them.

## Signature M3 Expressive moments

### 1. Contextual floating toolbar on selection

When 2+ items are selected, a pill-shaped floating toolbar (M3
Expressive's floating toolbar component) springs up from the bottom
edge — Copy / Cut / Delete / Rename / selection count — and sinks away
when the selection clears. Spatial spring entrance, not a fade.

- Why: bulk actions currently live only behind right-click and
  shortcuts; this is the single most visible Expressive statement the
  app could add.
- Touches: new component, `main.qml` wiring, existing selection state.

### 2. FAB menu

Morph the existing single-action FAB into M3 Expressive's FAB menu: the
FAB opens into a stack of labeled actions (New folder, New file, Paste
here) using the vendored shape-morphing library — the component
shape-morphing was designed for.

- Touches: `Fab.qml`, `main.qml`; Paste-here reuses `pasteEntry()`.

### 3. Animated row/tile add & remove

`ListView`/`GridView` add/remove/displaced transitions with spring
scale+fade. Now that live directory watching ships external changes
into the view, files popping in/out instantly reads as glitchy;
animated entrances/exits make it feel narrated.

- Touches: the two view components in `main.qml` only.
- Note: keep transitions short enough not to fight a 500-file burst
  (the watcher already batches; transitions must tolerate waves).

### 4. Navigation transitions

Entering a folder reads as moving forward (content slides/scales in,
emphasized curve), navigating up as moving back — screen-level
`Easing.BezierCurve` pairs from `Motion.qml`. Same treatment for the
list↔grid toggle (crossfade + slight scale) instead of the instant
Loader swap.

- Touches: `main.qml` view host; needs a direction hint from
  navigation (into vs. up).

## Expressive states that are currently blank

### 5. Loading state

Async navigation (2026-07-04 perf pass) empties the view while a big
directory lists. Center the existing `ShapeLoader` after ~150ms of
waiting — M3 Expressive treats the loading indicator as a hero
component, and it disambiguates "empty folder" from "still loading".

- Touches: `main.qml`; needs a small `isListing`-style model property
  (set on navigate, cleared when the listing applies).

### 6. Empty states

Empty folder, empty Trash, and zero search results are blank space
today. A large soft shape from the shapes library + one line of text +
an action ("This folder is empty — drop files here or create
something"). Reuses `DecorativeShapesBackground`'s visual language.

- Touches: `main.qml` (or a small `EmptyState.qml` component).

## Desktop UX gaps

### 7. Arrow-key navigation + type-ahead find

No keyboard focus concept exists in the views: arrows don't move a
cursor row, typing doesn't jump to a matching file. Add a cursor row
(Up/Down/Home/End, Enter opens, Shift+arrows extends selection) with an
M3 Expressive focus ring, plus type-ahead (typing "do" jumps to
"Documents").

- Why: every desktop file manager has both; highest pure-UX value on
  this list, and an accessibility win.
- Touches: selection semantics in Rust (cursor concept in
  `FileListModel`) + view key handling — spec it as its own feature.

### 8. Spring-loaded folders during drag

Hovering a drag over a folder row for ~800ms navigates into it, so one
drag can reach a nested destination. Folder-row `DropArea`s and their
`containsDrag` highlights already exist — this is a `Timer` on
`containsDrag` plus a navigate call.

### 9. Pinned folders in the sidebar

Drag a folder onto the sidebar to pin it; pins persist in
settings.json. The sidebar was deliberately excluded as a DnD *file*
target (drag-and-drop spec), but as a *pin* target it's a different,
natural gesture.

- Touches: `Sidebar.qml`, settings persistence in Rust.

## Smaller Expressive touches

### 10. Split button for view options

M3 Expressive split button: primary side toggles list/grid, chevron
side opens the existing `ViewOptionsMenu`.

### 11. Selected-tile shape morph

Subtle corner-radius morph on selected grid tiles (radius grows via
spring) — a whisper of the removed selection badge
(2026-07-04-selection-badge-removal spec) without its clutter.

### 12. Current-folder headline

Expressive type-scale folder title in the content header, crossfading
on navigate — leaning into M3 Expressive's larger typography.

## Suggested order

Items **1 + 3 + 5** as one coherent "expressive feedback" slice
(selection toolbar, animated changes, loading state). Item **7** as its
own spec'd feature (it adds a cursor concept to selection semantics in
Rust). The rest as opportunity allows.

## Round 2 candidates (added 2026-07-05)

### Desktop-UX fundamentals

### 13. Clickable breadcrumbs

The PathBar shows the path as plain text; each segment should be a
clickable chip navigating to that ancestor, keeping the existing
pill-to-search morph.

- Why: turns every ancestor into a one-click target; cheap relative to
  daily value.
- Touches: `PathBar.qml`.

### 14. Back/forward history

Backspace/Alt+Left mean "up" today; there's no history stack, so a
sidebar jump can't be undone with "back". A real history (Rust-side
stack) plus mouse buttons 4/5.

- Touches: `FileListModel` (history stack + canGoBack/canGoForward),
  `TopAppBar.qml`, shortcuts in `main.qml`.

### 15. Copy-conflict resolution

Collisions currently fail into the snackbar. A "Replace / Skip / Keep
both" dialog with an apply-to-all checkbox for bulk transfers.

- Touches: fm-core copy/move paths (conflict signal instead of error),
  new dialog component, transfer plumbing — spec it as its own feature.

### 16. Status line

A quiet "142 items · 3.2 GB · 3 selected" (footer or under the
headline). `selectionCount` already exists; needs an item-count/total
size property.

### Expressive polish

### 17. Collapsing headline on scroll

The 44px folder headline shrinks/fades as the view scrolls — M3
large-top-app-bar behavior.

### 18. Skeleton loading rows

Shimmering placeholder rows for list-view loading instead of (or ahead
of) the centered ShapeLoader; spinner stays for grid.

### 19. Ctrl+scroll icon zoom

Ctrl+wheel steps through the four `iconSizeLevel`s, persisted via the
existing `saveSettings()`.

### 20. Humanized dates

"Yesterday 14:32", "2 h ago" in the modified column; exact date in a
tooltip.

### 21. Drag auto-scroll

Rubber-band selection and drags near the view edge should scroll the
view (deferred in the multi-select plan; more visible now that
spring-loaded folders exist).

### Bigger swings (each its own spec)

### 22. Preview/details pane

Toggleable right-side panel: large thumbnail, full metadata, text-file
preview. Pairs with item 7's cursor.

### 23. Tabs

Multiple open directories. Touches the model's single-current-path
assumption everywhere — the most architectural item here.

### 24. Mounted volumes in the sidebar

USB drives/partitions with a capacity bar (`LinearWavyProgressBar`)
and eject.

### 25. Recursive search

Background directory walk with streamed results instead of filtering
only the current listing.

### 26. Open with…

A chooser over installed desktop entries instead of always `xdg-open`.

### Round-2 suggested order

Item **7**, then **13 + 14** as a "navigate like a desktop app" slice;
**16 + 19 + 20** as a small-polish batch; the rest as opportunity
allows.
