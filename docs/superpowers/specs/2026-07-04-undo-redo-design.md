# Undo/redo

## Context

Last remaining "deferred from v1" item with real day-to-day value (per
`2026-07-03-filemanager-design.md` §5, "Undo/redo beyond Trash-based
recovery"). Now that drag-and-drop landed, an accidental move is one
slipped mouse-press away and currently irreversible except by manually
reversing it. This spec adds Ctrl+Z / Ctrl+Shift+Z undo/redo over the
app's own file operations, with an M3 snackbar "Undo" affordance after
each undoable operation (the Nautilus pattern).

## Scope

**Undoable** (the full reversible set, per the user's explicit choice):

| Operation (call-sites in `file_list_model.rs`) | Undo |
|---|---|
| Move — cut-paste, internal drag-drop, external drop with `isMove` | move each item back |
| Rename (`renameEntry`) | rename back |
| Delete to Trash (`deleteEntry`, `deleteSelection`) | restore from Trash |
| Copy-in — copy-paste, external drop-copy, `duplicateEntry`/`duplicateSelection` | move the created copies **to Trash** (never permanent delete) |
| Create folder (`createFolder`) | move the created folder to Trash |
| Restore from Trash (`restoreEntry`, `restoreSelection`) | move back to Trash |

**Not undoable / never recorded**: permanent delete, empty trash,
drag-out to an external app (this app doesn't perform that copy), and
anything an external program does to the filesystem.

**History**: undo and redo stacks, session-only, capped at 100
operations (oldest dropped). Recording a new operation clears the redo
stack. One batch operation (e.g. a 5-item paste) is one undo step.

## Architecture: journal in `FileListModel` (Rust)

All journal state and logic live in `crates/app/src/file_list_model.rs`
alongside every operation call-site — consistent with the project rule
that business logic lives in Rust, never QML. No new fm-core API is
needed: `move_entry`, `copy`, `duplicate`, `move_to_trash`, `restore`
already exist and already return the concrete result paths the journal
needs.

```rust
enum UndoOp {
    Move        { pairs: Vec<(PathBuf, PathBuf)> }, // (orig, new)
    Rename      { from: PathBuf, to: PathBuf },
    TrashDelete { pairs: Vec<(PathBuf, PathBuf)> }, // (orig, trashed files/ path)
    CopyIn      { pairs: Vec<(PathBuf, PathBuf)> }, // (src, created)
    CreateFolder{ path: PathBuf },
    Restore     { pairs: Vec<(PathBuf, PathBuf)> }, // (trashed, restored)
}
```

The stack mechanics (push with cap, clear-redo-on-push, pop/replace
during undo/redo, human-readable description of an op) are a plain
`struct UndoJournal` with no Qt types, so `cargo test -p fm-app` can
cover them directly.

### Recording

Every record stores the **actual resulting paths**, not the requested
ones — e.g. after `unique_paste_destination` uniquifies a collision,
the journal holds the uniquified destination. For the async batch path
(`transfer_batch`), the spawned task collects the per-item
`(src, dest)` pairs that **succeeded** and queues them back to the
model thread on completion, where the journal push happens (same
`qt_thread.queue` callback that already clears `isBusy`). Single-item
async ops (rename, create folder, trash, restore, duplicate) push from
their own completion callbacks the same way. Nothing is recorded for
an operation whose every item failed.

### Undo/redo execution

`undo()` pops the top record, executes the inverse asynchronously,
then pushes the record onto the redo stack; `redo()` mirrors it.
Both are ignored while `isBusy` (no concurrent operations); with an
empty stack they emit a "Nothing to undo"/"Nothing to redo" snackbar
message and do nothing else.

Inverse execution reuses existing fm-core ops directly (no byte-level
progress plumbing — undo work is dominated by same-filesystem renames;
the existing `isBusy` + `busyLabel` "Undoing…"/"Redoing…" indeterminate
state covers the rare slow case):

- `Move`: `move_entry(new, orig)` per pair.
- `Rename`: `rename` back.
- `TrashDelete`: `trash::restore(trashed)` per pair.
- `CopyIn`: `move_to_trash(created)` per pair.
- `CreateFolder`: `move_to_trash(path)`.
- `Restore`: `move_to_trash(restored)` per pair.

Redo re-executes the operation forward. Redo of `TrashDelete`,
`Restore`, `CopyIn`, and `CreateFolder` produces **new** result paths
(a fresh trash entry, a fresh copy), so the record pushed onto the
opposite stack is rebuilt from what actually happened this time, never
reused verbatim.

`refresh_entries_diff()` runs after every undo/redo completes.

### Conflict policy: fail safe + report

Never overwrite, never uniquify during undo/redo. Per entry:

- Source of the inverse action missing (file was renamed/moved/deleted
  externally, Trash was emptied) → that entry fails.
- Exact destination already occupied by something else → that entry
  fails. (`move_to_trash` never conflicts — the Trash spec already
  uniquifies.)

Failed entries are counted and reported through the existing
`errorOccurred` snackbar path ("Couldn't undo 2 items", via
`pluralize_items`); surviving entries are undone/redone. The popped
record moves to the opposite stack containing **only the entries that
succeeded**; if none succeeded, it is discarded entirely (popped, not
retained — no retry semantics). Stale records never wedge the stack:
they fail safe, report, and drain.

## UI surface

**New invokables**: `undo()`, `redo()`.

**New signal**: `operationCompleted(description: QString, canUndo: bool)`

- Emitted after each successful undoable operation with a short
  description ("Moved 3 items", "Renamed 'a.txt'", "Moved 2 items to
  Trash", "Created folder 'x'") and `canUndo: true`.
- Emitted after undo/redo with "Undid: …"/"Redid: …" and
  `canUndo: false` (no undo button on the confirmation of an undo —
  redo is the shortcut's job).

**Snackbar action button** (`Snackbar.qml`): `show(message)` keeps its
existing signature and stays the sole entry point; it gains an optional
second parameter `show(message, actionLabel)`. When `actionLabel` is
non-empty, an M3 text button renders inside the snackbar (label styled
with `Color.scheme.inversePrimary` per M3 snackbar spec) and clicking
it emits a new `actionClicked()` signal and dismisses the snackbar.

**Wiring in `main.qml`**: `onOperationCompleted` shows the snackbar —
with "Undo" as the action when `canUndo`, plain otherwise;
`onActionClicked` calls `fileModel.undo()`. Errors keep flowing through
the existing `onErrorOccurred` handler unchanged.

**Shortcuts** (next to the existing ones in `main.qml`, same
`anyPopupOpen` guard, using the `sequences: [...]` form per commit
`2d1bc63`): `StandardKey.Undo` → `fileModel.undo()`,
`StandardKey.Redo` → `fileModel.redo()` (covers Ctrl+Shift+Z and
Ctrl+Y per platform).

## Verification

- `cargo test -p fm-app`: new unit tests for `UndoJournal` mechanics —
  push cap at 100, redo stack cleared on push, pop/replace flow,
  partial-success record rebuilding, description strings.
- `cargo test -p fm-core`: unchanged (no new core API).
- `cargo build -p fm-app` as the automated ceiling for the QML side.
- Interactive verification is done entirely by the user themselves (no
  QML test harness; per project convention the agent does not launch
  the app): undo/redo each operation type, the snackbar Undo button,
  fail-safe behavior after externally deleting a just-moved file,
  "Nothing to undo" on an empty stack, shortcut suppression while a
  popup is open.
