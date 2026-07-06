# Async Folder Size + Storage Gauges — Design

**Date:** 2026-07-06
**Status:** Approved

Two independent features:

1. The Properties dialog opens instantly and computes folder size in the
   background with live-updating progress (Nautilus-style), instead of
   blocking the UI thread on a synchronous recursive walk.
2. A "Storage" section in the sidebar showing one circular gauge card per
   mounted volume, ported from the user's quickshell `CustomGaugeProgress`
   component.

---

## Feature 1: Live-updating folder size in Properties

### Problem

`FileListModel::folder_size()` (`crates/app/src/file_list_model.rs:2488`)
walks the whole tree synchronously on the Qt UI thread. The Properties
dialog's `_facts` binding calls it while the dialog opens, so a large
folder visibly stalls the dialog.

### fm-core: `dir_size_with_progress`

Move the recursive walk from `file_list_model.rs` (private `dir_size`
helper, line ~2883) into fm-core (`crates/core/src/ops.rs`):

```rust
/// Recursively totals a directory's bytes and item count, invoking
/// `progress(bytes_so_far, items_so_far)` as it walks. Returning
/// `false` from the callback aborts the walk early.
/// Returns the final (bytes, items); on abort, the totals so far.
pub fn dir_size_with_progress(
    path: &Path,
    progress: &mut impl FnMut(u64, u64) -> bool,
) -> (u64, u64)
```

- Items = every directory entry encountered recursively (files +
  directories), matching Nautilus's "contents" count semantics.
- Unreadable subdirectories are skipped silently (same as today's
  `dir_size`).
- The callback is invoked frequently (per entry is fine); throttling is
  the caller's job.
- Tests live in `crates/core/tests/` (external test files, per project
  convention): total correctness on a small fixture tree, item count,
  early abort.

### FileListModel: scan invokables + qproperties

New qproperties:

| Property | Type | Meaning |
|---|---|---|
| `folderScanBytes` | `i64` | Running byte total of the active scan |
| `folderScanItems` | `i32` | Running recursive item count |
| `folderScanRunning` | `bool` | True while a walk is in flight |

New invokables:

- `startFolderSizeScan(name: &QString)` — resolves `current_path/name`,
  bumps an `AtomicU64` scan-generation counter (shared via `Arc`, same
  guard pattern as `listing_generation`), resets the three properties
  (0, 0, true), and spawns the walk on the existing tokio `runtime()`.
- `cancelFolderSizeScan()` — bumps the generation; the running walker
  notices and aborts.

Walker behavior:

- The progress callback checks the shared generation against its own; a
  mismatch returns `false` (abort).
- Progress is throttled inside the callback: queue an update to the Qt
  thread via `qt_thread().queue` at most every ~100 ms (tracked with
  `Instant`). Each queued closure re-checks the generation on the Qt
  thread before writing properties (stale updates dropped).
- On completion, a final queued update writes the exact totals and sets
  `folderScanRunning = false` (also generation-checked).

Removals: the synchronous `folderSize()` and `folderItemCount()`
invokables and the private `dir_size` helper — the Properties dialog is
their only caller.

### PropertiesDialog.qml

- `open(...)` for a folder calls `root.fileModel.startFolderSizeScan(name)`
  after showing the dialog. Files are unchanged (size passed in as today).
- The Size fact for folders binds to the scan properties:
  - While `folderScanRunning` and no bytes yet: `"Calculating…"`
  - Otherwise: `Format.formatBytes(folderScanBytes) + " (" +
    Format.formatItemCount(folderScanItems) + ")"`, ticking live and
    settling on the final value. (Item count is now recursive, not
    immediate children.)
- `close()` calls `cancelFolderSizeScan()`.
- Note: `_facts` is a plain array binding; it already re-evaluates when
  any property it reads changes, so live updates flow through it.

Edge cases:

- Opening Properties for another folder while a scan runs: the new
  `startFolderSizeScan` bumps the generation, killing the old walk.
- Tab switch mid-scan: the dialog holds its own `fileModel` reference,
  and the dialog is modal — the scan simply continues on that model.

## Feature 2: Storage gauge cards in the sidebar

### GaugeProgress.qml (new component)

Port of the user's quickshell `CustomGaugeProgress.qml`
(`~/.config/quickshell/modules/customComponents/CustomGaugeProgress.qml`),
adapted to this codebase:

- Canvas-drawn 270° arc (`startAngle = π·0.75`, span `1.5π`), gap at the
  bottom, `lineCap: "round"`, animated `Behavior on progress`, and the
  signature floating gap (`gap` property, default 0.4 rad) between the
  progress tip and the remaining track.
- Wavy/"sperm" mode is dropped — the reference design uses plain arcs.
- Centered overlay: `Icon` (this project's component) + "NN%" + "Used",
  using `Type` scale text and `Color.scheme` colors.
- Defaults: track `Color.scheme.secondaryContainer`, progress
  `Color.scheme.primary`, percent text `Color.scheme.primary`, "Used"
  `Color.scheme.surfaceVariantText`.
- Repaint triggers on progress and on any color change (theme is
  hot-reloadable in this app).

### Sidebar changes

- New "Storage" section header + content placed **directly after the
  Places (folders) Repeater and before the "Devices" header**, in normal
  Column flow (NOT anchored to the sidebar bottom — the copy-progress
  busy indicator lives there).
- Content: a 2-column `Grid` of cards, one per entry in the existing
  `root.volumes` (no Rust changes; data refreshes on the existing 10 s
  poll). Each card:
  - Rounded rectangle (`Shape.*` radius, `Elevation.surfaceAt(1)`-style
    fill to read as a card on the sidebar surface).
  - `GaugeProgress` with `progress = (total - avail) / total`, icon
    `hard_drive` for `/` mount, `usb` otherwise.
  - Below the gauge: `"3.5 / 9.6 GB"` — used / total, via
    `Format.formatBytes`-style formatting (label style, variant color).
- The thin linear capacity bars inside the Devices rows are removed
  (rows keep label, icon, navigation click, and eject button).
- With more than two volumes the Grid wraps to more rows.

## Testing & verification

- `cargo test -p fm-core` — new `dir_size_with_progress` tests (fixture
  tree totals, recursive item count, abort-on-false).
- `cargo build -p fm-app` — qmlcachegen validates the QML.
- Manual verification by the user (per project convention): Properties
  on a big folder (e.g. `~`) opens instantly and ticks; gauges match
  `df -h`; copy indicator unaffected.

## Out of scope

- Mount-watcher-driven volume refresh (10 s poll stays).
- Clickable gauge cards (Devices rows remain the navigation surface).
- Per-file scan progress display (path currently being walked).
