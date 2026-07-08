# Orbit

A fast Material 3 file manager for Linux, built in Rust and QML — made with the help of AI ([Claude Code](https://claude.com/claude-code)).

![Orbit screenshot](docs/screenshots/main.png)
![Orbit grid view](docs/screenshots/grid.png)

## Features

- Tabs with session restore
- List and grid views, inline tree expansion
- Command palette (`Ctrl+K`)
- Recursive and content search, filter chips
- Editable path bar, breadcrumbs, back/forward history
- Copy/move with progress, cancellation, conflicts, and undo
- Drag & drop with spring-loaded folders
- Trash, archives (compress/extract), Open with…
- Auto-organize rules (glob → move, undoable)
- Disk usage treemap, duplicate finder
- Preview pane (`F9`), live folder sizes
- Volume mounting, storage gauges, MTP phones
- Thumbnails, colored per-type file icons
- Light/dark theme with live palette reload (`~/.config/orbit/colors.json`)

## Dependencies

Build: Rust (stable), Qt 6 (Quick/QML), a C++ compiler.

Runtime:

- Material Symbols Rounded fonts (regular + filled) — required for icons
- `bsdtar` — archives
- `gio` — MTP phones, volume mounting
- `udisksctl` — mount/eject
- `xdg-open` — opening files

Everything except the fonts is optional; the related feature just won't work without it.

## Build & run

```sh
cargo run --release -p fm-app
```

Tests:

```sh
cargo test -p fm-core
```
