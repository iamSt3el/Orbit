# Restore from trash

## Context

Punch-list item from the "what's left for a fully functional file manager"
audit: `fm-core::trash` only has `move_to_trash`/`empty_trash` — no way to
recover an individual trashed item, and `TrashContextMenu.qml` (the
sidebar's Trash shortcut menu) only exposes "Empty Trash". Browsing into
the Trash folder itself shows a completely generic file listing today: the
per-item right-click menu (`ItemContextMenu.qml`) is identical there to
anywhere else (Open/Cut/Copy/Rename/Duplicate/Copy Path/Delete/Properties),
none of which are meaningful for an already-trashed item, and "Delete"
there would incorrectly try to move an already-trashed item to trash again.

## Scope

- Restore a trashed item back to its original location (single item and
  multi-selection).
- Permanently delete a trashed item, distinct from `emptyTrash()` which
  wipes the whole trash at once (single item and multi-selection).
- Make the per-item context menu trash-aware: browsing Trash shows only
  Restore / Delete Permanently, not the generic file menu.
- **Out of scope**: the *background* right-click menu (`ContextMenu.qml`,
  New Folder/Paste/Select All/Open Terminal) is unchanged even when
  browsing Trash — only the per-item menu (`ItemContextMenu.qml`) becomes
  trash-aware. A proper copy/move conflict-resolution UI is separate,
  already-tracked future work; restore's own conflict handling (see below)
  is a stopgap consistent with how paste already handles conflicts, not a
  substitute for that future feature.

## fm-core (`crates/core/src/trash.rs`)

Two new functions, each with an `_in(path, data_home)` test-injection
variant matching the existing `move_to_trash`/`move_to_trash_in` split:

```rust
pub async fn restore(trashed_path: &Path) -> io::Result<PathBuf>
pub async fn restore_in(trashed_path: &Path, data_home: &Path) -> io::Result<PathBuf>

pub async fn delete_permanently(trashed_path: &Path) -> io::Result<()>
pub async fn delete_permanently_in(trashed_path: &Path, data_home: &Path) -> io::Result<()>
```

**`restore_in`**: looks up `{data_home}/Trash/info/{trashed file name}.trashinfo`,
parses its `Path=` line for the original absolute path (error if the info
file is missing or malformed — an item with no recoverable original
location can't be restored). Recreates the original parent directory if
it no longer exists. If something already occupies the original path,
auto-renames the same way `unique_paste_destination` already does for
paste conflicts, but with a `"(restored)"` / `"(restored 2)"` / ... suffix
instead of `"(copy)"`. Moves the trashed file to the (possibly renamed)
destination, deletes the `.trashinfo` file, returns the final path.

**`delete_permanently_in`**: removes the trashed file or directory
(`remove_dir_all` for a directory, `remove_file` for a file) and its
`.trashinfo` file. A missing `.trashinfo` doesn't fail the operation
(best-effort cleanup — the actual content is what must be removed).

Both get real `tokio::test` + `tempfile` integration tests (this project's
first tests in `fm-core` — neither `fm-core` nor `fm-app` has any today
despite being cited as the automated verification ceiling):
- `restore_in`: happy path (file lands back at its original path, info
  file gone); missing parent directory is recreated; name conflict at the
  destination auto-renames; a trashed name with no matching `.trashinfo`
  returns an `Err`.
- `delete_permanently_in`: removes a trashed file and its info; removes a
  trashed directory (recursively) and its info; succeeds even when the
  `.trashinfo` is already missing.

## `file_list_model.rs` invokables

Four new invokables, each mirroring an existing one exactly:

- `restoreEntry(name)` — synchronous (`runtime().block_on`), like
  `deleteEntry`: calls `fm_core::trash::restore`, refreshes entries,
  emits `errorOccurred(QString::from(&format!("Couldn't restore \"{name}\": {e}")))`
  on failure.
- `deletePermanentlyEntry(name)` — same shape, calling
  `fm_core::trash::delete_permanently`, message
  `"Couldn't permanently delete \"{name}\": {e}"`.
- `restoreSelection()` — async batch, like `deleteSelection`: spawns a
  task over every selected name, sets `isBusy`/`busyLabel: "Restoring…"`,
  counts failures, emits one summary `errorOccurred` via
  `pluralize_items` (`"Couldn't restore {N} items"`) if `failed > 0`.
- `deletePermanentlySelection()` — same shape, `busyLabel: "Deleting
  Permanently…"`, message `"Couldn't permanently delete {N} items"`.

All four operate on `current_path.join(name)` the same way every other
per-name invokable in this file already does (`deleteEntry`,
`duplicateEntry`, etc.) — no special-casing needed since these are only
ever invoked while already browsing the Trash folder.

## `ItemContextMenu.qml`

New property: `property bool isTrashView: false`. New signals:
`restoreRequested(string name)`, `deletePermanentlyRequested(string name)`.

`_items` gains a third branch, checked before the existing
`selectionCount > 1` one:

```
isTrashView && selectionCount > 1:
    Restore {selectionCount} items
    Delete {selectionCount} items Permanently
isTrashView (selectionCount === 1):
    Restore
    Delete Permanently
(else: existing generic menu, unchanged)
```

## `main.qml` wiring

- `openItemContextMenu(...)` gains one more argument,
  `fileModel.currentPath === fileModel.trashPath`, passed through to
  `itemContextMenuLoader.item.popup(...)` as `isTrashView`.
- `onRestoreRequested`: `selectionCount > 1 ? fileModel.restoreSelection() : fileModel.restoreEntry(name)` — no confirmation, matching Duplicate/Cut/Copy (restore isn't destructive).
- `onDeletePermanentlyRequested`: opens a new `ConfirmDialog`
  (title "Delete Permanently", confirm label "Delete Permanently"),
  copying the existing Delete-to-Trash confirm dialog's exact
  pending-state pattern (`_pendingDeletePermanentlyName`,
  `_pendingDeletePermanentlyIsSelection`, a new
  `deletePermanentlyConfirmDialogLoader`) — since even the *reversible*
  Delete-to-Trash action already confirms, the *irreversible* permanent
  delete clearly should too.
- The new `deletePermanentlyConfirmDialogLoader` is added to the
  `anyPopupOpen` guard list from the action-keyboard-shortcuts feature, so
  the Delete/Escape/etc. shortcuts stay inert while it's open, same as
  every other popup.

## Verification

`cargo test -p fm-core` now has real content (the new `restore_in`/
`delete_permanently_in` tests) in addition to the existing verification
ceiling of `cargo build -p fm-app`. No QML test harness exists; interactive
verification (trashing something, browsing into Trash, restoring it,
permanently deleting another, confirming the background menu is
unaffected) is done by the user themselves.
