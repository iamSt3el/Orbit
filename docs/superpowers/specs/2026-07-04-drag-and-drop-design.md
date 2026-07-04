# Drag-and-drop

## Context

Punch-list item from the "what's left for a fully functional file manager"
audit: no drag-and-drop exists anywhere in this app today — only internal
mouse-drag *rubber-band selection*. This spec covers internal drag-to-move,
external drag-in (accepting drops from other apps), and external drag-out
(dragging files to other apps), all in one pass per the user's explicit
choice to do the full scope now rather than defer external interop.

This overlaps conceptually with the separately-tracked "system clipboard
integration" punch-list item (both need `text/uri-list`-style file
interop), but is scoped independently here — clipboard copy/paste through
`QClipboard` is not part of this spec.

## Scope

- **Drop targets: folder rows only** (in the current `FileListItem`/
  `FileGridItem` view) plus the background of the file view (for
  external-only drops). Sidebar shortcuts are explicitly **not** drop
  targets in this pass.
- **Drag-out is copy-only.** The source file is never deleted here based
  on trusting another app's reported drop outcome. A true cross-app move
  (deleting the source once an external target confirms an accepted Move)
  is deferred, not part of this spec.
- **Internal drag is always a move.** No modifier-key (Ctrl-to-copy)
  nuance in this pass.
- Out of scope: dragging files onto the Sidebar, drag-reordering within a
  view, any drag between two instances of this app treated specially
  (a second instance is just "external" as far as this app is concerned).

## MIME data

Every drag — whether it starts inside this app or arrives from outside —
carries real `text/uri-list` data (`file://` + absolute path, entries
joined by `\r\n` per the freedesktop convention). Using the real interop
format instead of a private one is what lets internal and external drops
share one drop-handling path on the QML side.

Our own drag sources additionally set `Drag.keys: ["text/uri-list",
"application/x-filemanager-internal"]`. `Drag.keys` is a QML-only routing
mechanism (it is not exported to other applications over XDND/Wayland —
only `Drag.mimeData` is) used purely so this app's own `DropArea`s can
tell "this drag started inside this app" apart from a genuinely external
one.

## Drag source (`FileListItem.qml`, `FileGridItem.qml`)

Same press-then-threshold pattern already used for rubber-band
drag-select in `main.qml` (6px movement while pressed, before treating it
as a drag rather than a click):

- On press, record the position; on position-changed past the threshold,
  mark this gesture as a drag (so the eventual `onClicked` no-ops, exactly
  like the existing rubber-band code guards `onClicked` with its own
  `dragging` flag) and start the drag.
- **What gets dragged**: if the pressed row (`root.selected`) is already
  part of the current multi-selection, the whole selection is dragged;
  otherwise, just that single row — mirrors the existing right-click rule
  ("right-clicking a selected item keeps the whole selection; right-
  clicking an unselected one acts on just that item").
- `Drag.dragType: Drag.Automatic`, `Drag.proposedAction: Qt.MoveAction`,
  `Drag.supportedActions: Qt.CopyAction | Qt.MoveAction`.
- `Drag.mimeData` is built from `fileModel.entryAbsolutePath(name)` for
  each dragged name (single row, or `fileModel.selectedNamesJoined()`
  split on `\n` for a multi-selection), each turned into a `file://` URI.

## Drop targets

**Folder rows** (`FileListItem`/`FileGridItem`, only where `root.isDir`):
a `DropArea` with `keys: ["text/uri-list"]` — accepts both our own
internal drags and an external file dropped precisely on that row (a
photo dragged straight from a browser onto a specific subfolder works,
not just onto the current folder's background). On drop:
`isMove = (drop.proposedAction === Qt.MoveAction)`,
`drop.acceptProposedAction()`, destination is
`fileModel.currentPath + "/" + root.name`. One rule serves both cases:
our own drag always proposes Move; an external source's proposed action
reflects whatever *it* intended (e.g. a Shift-drag in another file
manager proposing Move instead of the default Copy).

**Background of the file view** (next to the existing
`listBackgroundArea`/`gridBackgroundArea` in `main.qml`): a `DropArea`,
same `proposedAction` rule, destination is `fileModel.currentPath` — but
rejects (sets `drop.accepted = false`) any drop whose `drop.keys` include
`"application/x-filemanager-internal"`, since dropping one of our own
items into empty space of the very folder it's already in is a
meaningless no-op, not an import.

## `file_list_model.rs` changes

**New invokables:**
- `selectedNamesJoined() -> QString` — every currently-selected name,
  joined by `\n`. Needed so QML can build multi-item drag `mimeData`
  (there's currently no way to read back the full selection as a list,
  only `selectedCount()` and, for exactly one, `singleSelectedName()`).
- `dropPaths(paths: QString, destDir: QString, isMove: bool)` — `paths`
  is `\n`-joined absolute filesystem paths (QML strips each `file://`
  prefix itself before joining, so Rust never has to parse URIs).

**Refactor**: `paste_entry`'s batch body (computing total size up front,
setting `isBusy`/`busyLabel`/transfer-progress properties, the progress-
relay task, the per-item copy-or-move loop with failure counting, the
final `error_occurred` batch summary) becomes a private method,
`transfer_batch(self, sources: Vec<PathBuf>, dest_dir: PathBuf, is_move:
bool)`. `paste_entry` calls it with `self.clipboard_paths` (after
optionally clearing them, unchanged from today) and `self.clipboard_is_cut`
as `is_move`. `drop_paths` calls it with the paths/dest parsed from its
arguments. This is the same machinery paste already has (progress
tracking, batch error summary via `pluralize_items`) — reusing it instead
of duplicating avoids a second copy of that logic drifting out of sync.

## Verification

`cargo build -p fm-app` (qmlcachegen + cxx-qt codegen) is the automated
ceiling. Drag-and-drop cannot be exercised by any automated test in this
project — no QML test harness exists, and simulating real OS-level XDND/
Wayland drag events isn't practical in this stack. Interactive
verification (dragging a file onto a folder row, dragging a file in from
a file browser or the desktop, dragging a file out to another app's
window) is done entirely by the user themselves.
