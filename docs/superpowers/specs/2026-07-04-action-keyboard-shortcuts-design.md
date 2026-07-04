# Action keyboard shortcuts

## Context

Punch-list item from the "what's left for a fully functional file manager"
audit. Today only Ctrl+A (`main.qml`'s `Shortcut { sequence:
StandardKey.SelectAll }`) exists. This spec covers the remaining
single-action shortcuts: Delete, F2, Ctrl+C/X/V, Enter, Backspace/Alt+Left,
Escape. Arrow-key navigation between items is explicitly out of scope —
tracked separately, since it requires a new keyboard-focus-cursor concept
neither ListView nor GridView has today (selection is currently
mouse-only), which is a materially different subsystem than binding single
keys to existing selection-based actions.

## Discovered gap this spec also fixes

Of the app's 10 popups/dialogs/menus, only `NewFolderDialog` and
`RenameDialog` currently close on Escape — and only because their text
field has focus and defines `Keys.onEscapePressed` on itself. The other 7
(`ConfirmDialog`, `PropertiesDialog`, `SettingsDialog`, `ItemContextMenu`,
`ContextMenu`, `TrashContextMenu`, `ViewOptionsMenu`) hold no keyboard focus
at all and don't close on Escape (one, `ContextMenu.qml`, has a stale
comment claiming it does). Since the new shortcuts in this spec are
window-level and fire regardless of what's visually "in front," leaving
this gap unfixed would mean e.g. pressing Delete while `PropertiesDialog` is
open for file A silently deletes whatever's currently selected underneath
it. This spec fixes it as directly load-bearing prep work, not scope creep.

## Guard: `anyPopupOpen`

`main.qml` gets one new computed property:

```qml
readonly property bool anyPopupOpen:
    contextMenuLoader.active || newFolderDialogLoader.active ||
    viewOptionsMenuLoader.active || itemContextMenuLoader.active ||
    renameDialogLoader.active || propertiesDialogLoader.active ||
    deleteConfirmDialogLoader.active || trashContextMenuLoader.active ||
    emptyTrashConfirmDialogLoader.active || settingsDialogLoader.active
```

Every new `Shortcut` below checks `!window.anyPopupOpen` before acting
(Escape is the one exception with its own dual behavior, see below).

## Popup Escape fix

Each of the 7 focus-less popups gets:
- `Keys.onEscapePressed: root.close()` added to its root `Item`.
- Its `popup(...)`/`open(...)` function calls `root.forceActiveFocus()` right
  after setting `visible = true`, so the root `Item` actually receives the
  key event (a plain `Item` can hold active focus once
  `forceActiveFocus()` is called on it — it doesn't need to be a
  `FocusScope`).

This exactly mirrors the pattern `NewFolderDialog`/`RenameDialog` already
use on their text field, generalized to the popup's root since these 7
don't have a text field to hang it on.

## New Rust invokables (`crates/app/src/file_list_model.rs`)

Two additions, both reusing existing internal methods rather than
duplicating logic:

- **`openSelectedEntry()`** — if exactly one entry is selected, navigates
  into it (folder) or opens it (file), by looking the name up in
  `self.entries` and calling the existing `navigate`/`open_entry` methods
  internally. No-ops otherwise (0 or 2+ selected). This keeps the
  is-it-a-folder branching in Rust rather than exposing raw entry data to
  QML, matching this project's existing "logic lives in fm-core/the model,
  not QML" principle.
- **`singleSelectedName() -> QString`** — returns the one selected entry's
  name, or an empty string if the selection count isn't exactly 1. Needed
  because F2 opens the QML `RenameDialog`, which can only happen from QML,
  so QML needs the name to pass to `window.openRenameDialog(name)`.

## New `Shortcut` items in `main.qml`

All guarded by `!window.anyPopupOpen` unless noted:

| Shortcut | Sequence | Action |
|---|---|---|
| Delete | `StandardKey.Delete` | `fileModel.deleteSelection()`, only if `fileModel.selectedCount() > 0` |
| F2 | `"F2"` | if `fileModel.selectedCount() === 1`: `window.openRenameDialog(fileModel.singleSelectedName())` |
| Copy | `StandardKey.Copy` | `fileModel.copySelection()` |
| Cut | `StandardKey.Cut` | `fileModel.cutSelection()` |
| Paste | `StandardKey.Paste` | `fileModel.pasteEntry()` (already a safe no-op on an empty clipboard) |
| Open | `"Return"` and `"Enter"` (both — main keyboard and numpad) | `fileModel.openSelectedEntry()` |
| Up/Back | `"Backspace"` and `"Alt+Left"` | `fileModel.navigate(window.parentPath(fileModel.currentPath))`, only if `fileModel.currentPath !== "/"` |
| Clear selection | `StandardKey.Cancel` (Escape) | if `window.anyPopupOpen`: do nothing (a popup's own new Escape handler already consumed the key first); otherwise `fileModel.clearSelection()` |

Using `StandardKey.*` where Qt defines one (Delete/Copy/Cut/Paste/Cancel)
rather than hardcoded key strings, matching the existing Ctrl+A
(`StandardKey.SelectAll`) precedent and picking up whatever the host
platform's actual binding is instead of assuming Ctrl+C/X/V literally.

Focused text fields (rename/new-folder text input, the PathBar search
field) are expected to consume Delete/Copy/Cut/Paste/Return/Escape
themselves for ordinary text editing before these window-level shortcuts
ever see the key — this is the same assumption the existing Ctrl+A
shortcut's own comment already documents and relies on, not a new one.

## Verification

`cargo build -p fm-app` (qmlcachegen + cxx-qt codegen) is the automated
ceiling; no QML test harness exists. Interactive verification (pressing
each shortcut, confirming popups close on Escape, confirming shortcuts are
inert while a popup is open) is done by the user themselves.
