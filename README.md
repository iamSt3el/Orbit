# Orbit

A fast, keyboard-friendly file manager for the Linux desktop, with a genuine
**Material 3 Expressive** interface — built in Rust and QML.

Orbit was built collaboratively with AI: the design, architecture, and code
were developed together with [Claude Code](https://claude.com/claude-code),
Anthropic's AI coding agent, through spec-driven, plan-by-plan sessions. Every
feature was specified, implemented, and reviewed in that workflow — the full
history is in this repository's commits and in `docs/superpowers/`.

## What makes it different

Most Qt file managers look like Qt. Orbit doesn't use Qt Quick Controls at
all — every component (buttons, ripples, menus, dialogs, progress bars, the
top app bar) is hand-built from Qt Quick primitives to get real Material 3
Expressive behavior:

- **State layers, springs, and shape morphing.** Component motion runs on
  spring animations; selected grid tiles morph their corner geometry through a
  vendored port of Google's shape-morphing math. Screen-level transitions use
  M3's emphasized easing curves.
- **Design tokens, not hardcoded styles.** Color, typography, shape,
  elevation, and motion live in token singletons. The tonal palette is
  generated from a seed color with [matugen](https://github.com/InioX/matugen),
  and the app hot-reloads `~/.config/filemanager/colors.json` at runtime — point
  your wallpaper-theming setup at it and Orbit re-themes live.
- **A Rust core that does the heavy lifting.** Directory listings stream in
  asynchronously (Tokio); sorting, filtering, and search happen in Rust, never
  in QML — huge directories stay smooth. Copies use `copy_file_range`, so
  same-filesystem copies on btrfs/XFS reflink instantly.
- **Wayland-native, Linux-only by design.** freedesktop.org Trash spec,
  freedesktop thumbnail cache, `.desktop`-entry app launching, MTP phones via
  gio — no cross-platform compromises.

## Features

**Navigation**
- Tabs (middle-click to open/close, drag onto a tab to drop files there), with
  full session restore — tabs, active tab, and window size survive restarts
- Command palette (`Ctrl+K`): actions, places, pinned folders, free-form paths
- Editable path bar (`Ctrl+L`) with tilde expansion and Tab completion,
  clickable breadcrumbs, browser-style back/forward history
- Keyboard navigation with a cursor row and type-ahead find
- List and grid views, inline tree expansion in list view, `Ctrl+scroll` icon
  sizing

**Finding things**
- Instant filter in the current folder (`Ctrl+F`), recursive search with
  relative-path results, full **content search** showing the matched line
- Filter chips: folders / images / documents / media

**File management**
- Copy/move with live progress, cancellation, conflict resolution, and undo
- Drag & drop with spring-loaded folders (hover to descend) and a themed drag
  ghost; rubber-band selection with auto-scroll
- freedesktop Trash with restore, "Open with…" chooser over installed desktop
  entries (with real app icons), zip compress / archive extract via `bsdtar`
- Auto-organize rules: glob patterns that move files as they land — undoable

**Insight**
- Disk usage treemap of the current folder with drill-down (allocated blocks,
  not sparse lengths)
- Duplicate finder (SHA-256 groups, trash-the-rest with undo)
- Preview/details pane (`F9`), properties dialog with live-ticking folder sizes
- Sidebar storage gauges for mounted volumes, one-click mount/eject, MTP
  phones with live mount updates

**Polish**
- Per-type file icons with color (braces for code, red PDF, and so on),
  freedesktop-cached thumbnails
- Humanized timestamps, item counts on folder rows, status line with selection
  totals
- Responsive layout — the sidebar collapses to an overlay drawer on narrow
  windows
- Light/dark theme, accessibility roles and names throughout

## Architecture

```
crates/
├── core/    fm-core   — all business logic, plain Rust + Tokio: listings,
│                        file ops, trash, search, archives, thumbnails,
│                        volumes, watching, settings
├── app/     fm-app    — thin cxx-qt bridge (a QAbstractListModel exposing
│                        fm-core to QML) plus the entire QML frontend
│            qml/tokens/      Color / Type / Shape / Elevation / Motion
│            qml/components/  the hand-built M3 component library
│            qml/shapes/      vendored shape-morphing library
└── xtask/   fm-xtask  — regenerates the M3 palette from a seed via matugen
```

The bridge holds no business logic; QML holds no data logic. Each layer is
replaceable on its own.

## Building

### Dependencies

Build-time:

| Dependency | Notes |
|---|---|
| Rust (stable) | via [rustup](https://rustup.rs) |
| Qt 6 | Qt Quick + QML development packages (`qt6-base`, `qt6-declarative` on Arch; `qt6-base-dev`, `qt6-declarative-dev` on Debian/Ubuntu) |
| C++ compiler | gcc or clang, for the cxx-qt bridge |

Runtime:

| Dependency | Needed for |
|---|---|
| **Material Symbols Rounded** fonts | all icons — install the static *Material Symbols Rounded* and *Material Symbols Rounded Filled* families from [Google Fonts](https://fonts.google.com/icons) (`ttf-material-symbols-variable-git` or the static TTFs into `~/.local/share/fonts`) |
| `bsdtar` (libarchive) | compress / extract |
| `gio` (glib2) | MTP phones, volume mounting |
| `udisksctl` (udisks2) | mount / eject drives |
| `xdg-open` | opening files with no matching desktop entry |
| `matugen` | optional — only to regenerate the color palette |

Everything in the runtime table except the fonts degrades gracefully if
missing; the related feature just won't work.

### Build and run

```sh
git clone <this-repo> && cd filemanager
cargo run --release -p fm-app
```

The first build compiles the cxx-qt bridge and Qt integration, so it takes a
few minutes; incremental builds are quick. If Qt lives in a non-standard
location, point `QMAKE` at your qmake6 binary.

Tests live in the core crate:

```sh
cargo test -p fm-core
```

To regenerate the color palette (edit the `SEED` constant in
`crates/xtask/src/main.rs`, then rewrite `qml/tokens/Color.qml`):

```sh
cargo run -p fm-xtask
```

### Configuration

Orbit keeps its state in `~/.config/filemanager/`:

- `settings.json` — view options, pinned folders, session (managed by the app)
- `colors.json` — optional external palette, watched and hot-reloaded

## Project history

The repository doubles as a record of how the app was built with AI:
`docs/superpowers/specs/` holds the design specs and `docs/superpowers/plans/`
the step-by-step implementation plans that produced each slice, from the first
streaming directory listing to the UI/UX roadmaps (`docs/ui-ux-roadmap*.md`).

## License

Not yet licensed — all rights reserved for now.
