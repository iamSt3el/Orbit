# File Manager — Design Spec

Date: 2026-07-03

## 1. Overview & Goals

A Linux desktop file manager built as a three-layer system:

- **QML frontend** — presentation and interaction only, implementing a fully
  custom Material 3 design system (no Qt Quick Controls). Async list/grid
  views with M3 motion (ripples, shared-axis transitions, state layers).
- **cxx-qt bridge** — thin glue exposing Rust state/methods to QML via
  `Q_PROPERTY`, signals, and invokable methods. Contains no business logic.
- **Rust backend** — async core (Tokio) doing directory listing, file
  operations, and live filesystem watching (`notify`). Memory-safe by
  construction.

Goals, in priority order:

1. Genuine Material 3 fidelity — not a Material-2-adjacent approximation.
2. Speed: instant startup, smooth scrolling on directories with tens of
   thousands of files, low idle resource use, fluid 60fps+ animations.

Target platform: Linux desktop only (no Windows/macOS support planned).

## 2. Rust backend

- **File model**: a `QAbstractListModel`-backed struct (via cxx-qt)
  representing the current directory's entries — name, size, mtime,
  mime-type-derived icon key, is-dir. Sorting and filtering happen in Rust,
  not QML, to keep large directories fast.
- **Async I/O**: Tokio runtime handles directory reads and file operations
  (copy/move/delete/rename) off the UI thread. Directory listing streams
  results incrementally as entries are read, rather than blocking until the
  full listing completes — this is what keeps huge directories feeling
  instant.
- **File watcher**: the `notify` crate watches the active directory. Changes
  (create/delete/rename/modify) patch the model in place instead of
  triggering a full reload, so the view stays live without expensive
  re-reads.
- **Trash**: implements the freedesktop.org Trash specification
  (`~/.local/share/Trash/{files,info}`) so deletes are recoverable and
  interoperable with GNOME Files / Dolphin's trash.
- **Mime detection**: lightweight extension/magic-byte based lookup for icon
  selection — no heavyweight shared-mime-info parsing unless a future need
  demands it.

## 3. cxx-qt bridge

A thin translation layer with no business logic of its own:

- `Q_PROPERTY`s expose: current directory path, sort/filter state,
  selection, theme mode (light/dark).
- Invokable methods for QML-triggered actions: `navigate(path)`,
  `copy`/`move`/`delete`/`rename`, `createFolder`, `toggleSort`,
  `setFilterText`.
- Signals for Rust-originated events: directory changed, operation
  progress/completed/failed, watcher-driven entry added/removed/updated.

If a piece of logic doesn't need to cross the Rust/QML boundary, it does not
live in this layer.

## 4. QML frontend — Material 3 Expressive design system

Built on plain Qt Quick primitives (`Rectangle`/`Item`/`Canvas`), not Qt
Quick Controls 2 — this avoids fighting QQC2's Material-2-era control
internals and gives full control over M3-specific details (state layers,
tonal elevation, spring motion, shape morphing). Morphable shapes render via
`Canvas` (matching the vendored shape library below); non-morphing rectangular
surfaces use plain `Rectangle` with `radius`.

**Not built from scratch** — the user's existing `~/.config/quickshell/`
project (a Quickshell/QML desktop shell) already contains a partial M3
component set that this project vendors and refines rather than
reimplementing:

| Source (quickshell) | Reuse plan |
|---|---|
| `modules/customComponents/RippleEffect.qml` | Port near-as-is: correct M3 hover-tint + press-ripple with proper max-radius-to-corner math. Only its `Colors`/`Appearance` singleton references need repointing to this project's own token singletons. |
| `modules/customComponents/MaterialIconSymbol.qml` | Port as-is: renders icons via the "Material Symbols Rounded" variable font (FILL/opsz axes), the correct approach for M3 iconography. Requires that font available on the system. |
| `modules/utils/ColorProvider.qml`, `DarkTheme.qml`, `LightTheme.qml`, `modules/settings/Appearance.qml` | **Not reused.** These are shell-specific (dynamic-color template placeholders; bar/panel dimensions in the duration/radius/spacing groups). Color and motion/shape token *values* instead come straight from the Material 3 skill's reference tables (`references/color-system.md`, `references/typography-and-shape.md`) — real `md.sys.color.*` roles for the fixed light/dark palette, and the spec's actual elevation/duration/shape-scale numbers — assembled into this project's own singletons from scratch. |
| `modules/customComponents/CustomButton.qml`, `SearchBar.qml` | Refine, don't copy verbatim: both pull in `Quickshell.Wayland`/`Quickshell.Hyprland`/`Quickshell.Widgets` imports that don't exist outside the Quickshell runtime (e.g. `PopupWindow` for layer-shell popups). Strip those, keep the M3 visual/interaction logic, adapt `SearchBar` for the filter-by-name field. |
| `modules/customComponents/CustomList.qml` | Not portable as-is (built on `PopupWindow`, a Wayland-layer-shell-only window type) — use only as a visual/interaction reference when building the file list item delegate. |
| `modules/MatrialShapes/` | Vendor as-is (see Shape scale below). |

Everything else in this layer (list item delegates, top app bar, navigation
rail, FAB, dialogs, snackbar) is file-manager-specific and has no quickshell
equivalent, so those are built new — but built out of the ported
ripple/icon/token/shape primitives above, not from raw `Rectangle`s.

The app should read as current (2025+) Material, not just "rounded corners
Material 2" — so this leans into the **M3 Expressive** variant rather than
baseline M3 wherever QML can practically support it. QML is a good fit for
this: unlike web (`@material/web`, spring motion unsupported) it has a
native `SpringAnimation` type, so genuine spring physics is achievable
without a from-scratch physics implementation.

- **Tokens** (QML singletons):
  - Color roles: primary/secondary/tertiary/surface/error, each with their
    "on-" and container variants, plus the surface-container tonal scale
    (lowest/low/default/high/highest) and outline/outline-variant. One
    fixed palette generated from the Material baseline seed color `#6750A4`
    (Google's default M3 seed), with light and dark variants (no
    dynamic/wallpaper-based color in v1).
  - Type scale: display/headline/title/body/label at M3 sizes, **using the
    emphasized (bolder-weight) variants for headers and titles** —
    breadcrumb bar title, dialog titles, section headers — to give clearer
    visual hierarchy than the standard weights.
  - Shape scale: full M3 Expressive range, including the expanded tokens
    (`large-increased` 20dp, `extra-large-increased` 32dp,
    `extra-extra-large` 48dp) alongside the standard scale
    (none/extra-small 4dp/small 8dp/medium 12dp/large 16dp/extra-large
    28dp/full). Interactive elements **morph shape on state change** — e.g.
    the FAB shifts toward a squircle on press, a selected list item's
    corner radius increases — rather than staying static.
  - Shape morphing uses the vendored `MatrialShapes` library (see reuse
    table above), copied into `src/qml/shapes/` in this repo: full M3 shape
    catalog (circle, cookie-4/6/7/9/12-sided, burst, clover, pill, gem,
    etc.), a generic polygon morph engine (cubic-bezier interpolation with
    corner rounding/smoothing), and a working `MorphShape.qml` pattern for
    animated transitions between two shapes — adapted only where the file
    manager's specific components (FAB, list item selection state) need it.
  - Elevation: tonal elevation (surface tint via the surface-container
    scale), not drop shadows, matching MD3's depth model.
  - Sizing: buttons and icon buttons follow the Expressive XS–XL size range
    rather than one fixed size, so density can vary by context (e.g.
    compact toolbar icon buttons vs a larger primary action button).
- **Core components**: filled/outlined/text/tonal/elevated buttons across
  the Expressive size range, list item delegates, top app bar, navigation
  rail, FAB, dialogs, snackbar (for operation feedback) — each with proper
  M3 state layers (hover/press/focus overlays), ripple, and shape morphing
  where applicable.
- **Views**: `ListView` and `GridView` with custom delegates, bound directly
  to the Rust-exposed model (no intermediate QML-side copying), so large
  directories stay smooth.
- **Motion**: two motion systems, matching where MD3 itself uses each:
  - **Spring physics** (QML `SpringAnimation`, tuned stiffness/damping per
    interaction) for component-level state changes — button press, FAB
    press, selection state, shape morphing — giving the bouncy, natural
    Expressive feel.
  - **Easing/duration curves** (QML `Behavior`/`Transition`, emphasized
    400–500ms / standard 200–300ms per the M3 motion spec) for
    screen-level transitions — e.g. shared-axis transition when navigating
    into a folder — where a settle-and-arrive spring would feel wrong for
    a full view change.
  - Shader effects reserved for cases neither animation system handles
    cheaply (e.g. ripple).

## 5. MVP feature scope

**In scope for v1:**

- Navigate directories (breadcrumb + back/forward)
- List view and grid view, toggleable
- Open files (via `xdg-open`), open folders (navigate in)
- Copy, move, delete (→ Trash), rename, create folder
- Filter-by-name within the current folder (instant, client-side over the
  already-loaded model — not recursive, not indexed)
- Light/dark theme toggle

**Explicitly out of scope for v1** (candidates for follow-up specs):

- Tabs / split panes
- File previews
- Recursive/indexed search
- Dynamic (wallpaper-derived) color — "true Material You"
- Drag-and-drop
- Network or archive filesystems
- Undo/redo beyond Trash-based recovery

## 6. Testing

- Rust backend: unit tests for file operations, Trash-spec compliance, and
  model sorting/filtering; integration tests running against a temp
  directory fixture.
- QML/UI: verified manually (via the `verify` workflow) once features are
  built. No automated QML test harness planned for v1, given the MVP-focused
  scope — revisit if the UI layer grows complex enough to warrant it.
