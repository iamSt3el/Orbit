# Error surfacing (Snackbar)

## Context

Every fallible file operation in `FileListModel` (`crates/app/src/file_list_model.rs`)
currently handles an `Err` by doing `eprintln!(...)` and nothing else — the
failure never reaches the QML layer, so from the user's perspective a failed
rename, delete, paste, etc. just silently does nothing. This is punch-list
item #1 from the "what's left for a fully functional file manager" audit
(2026-07-04 conversation).

## Goal

Every user-triggered file operation that can fail should show the user a
short message when it does, via a single global M3-style Snackbar, without
requiring the user to check a terminal.

## Scope

**Operations wired to emit a user-facing error:**
- `create_folder`
- `rename_entry`
- `delete_entry` / `delete_selection` (batch)
- `empty_trash`
- `duplicate_entry` / `duplicate_selection` (batch)
- `paste_entry` (batch)
- `open_entry`
- `open_terminal_here`

**Explicitly out of scope:** `save_settings` and `start_theme_colors_watch`.
Both are background persistence, not a direct user action with an
expectation of feedback — surfacing them would mostly add noise. (Revisit
later if it turns out settings-save failures need visibility too.)

`eprintln!` calls at each site stay as-is (dev-facing stderr log); this adds
a second, user-facing path alongside them, it doesn't replace them.

## Architecture

**Rust side:** add one custom Qt signal to the `FileListModel` cxx-qt bridge:

```rust
#[qsignal]
fn error_occurred(self: Pin<&mut FileListModel>, message: QString);
```

(cxx-qt 0.9, already the version in use, supports `#[qsignal]` in the
`unsafe extern "RustQt"` block — the generated method is called directly on
`Pin<&mut FileListModel>`, e.g. `self.as_mut().error_occurred(msg)`.)

Each of the scoped operations' existing `Err(e) => eprintln!(...)` arm gains
a sibling call emitting `error_occurred` with a short formatted message (see
"Message format" below).

**Batch operations** (`delete_selection`, `duplicate_selection`,
`paste_entry`): instead of emitting per failed item, count failures during
the loop (`let mut failed = 0;` incremented in each per-item `Err` arm) and
emit one summary signal after the loop completes, only if `failed > 0`.

**QML side:** new component `crates/app/qml/components/Snackbar.qml`
(registered in `build.rs`), instantiated once near the top of `main.qml`'s
`Window`, wired via:

```qml
Connections {
    target: fileModel
    function onErrorOccurred(message) { snackbar.show(message) }
}
```

Snackbar exposes one function, `show(message)`, and manages its own
visibility/timer internally — callers don't touch its other properties.

## Message format

`"<Verb-ed description>: <e>"` for single-item failures, name in quotes when
there's a specific target:

- `Couldn't create folder: {e}`
- `Couldn't rename "{old_name}": {e}`
- `Couldn't delete "{name}": {e}`
- `Couldn't empty trash: {e}`
- `Couldn't duplicate "{name}": {e}`
- `Couldn't open "{name}": {e}`
- `Couldn't open terminal here: {e}`

Batch summaries (only the count, not per-item detail — that's the whole
point of summarizing):

- `Couldn't delete {n} item(s)`
- `Couldn't duplicate {n} item(s)`
- `Couldn't paste {n} item(s)`

`{e}` is `io::Error`'s `Display` output (e.g. `Permission denied (os error
13)`), which is already reasonably user-presentable — no further wrapping
needed.

## Snackbar UI

- M3-style single-line bar: `Color.scheme.inverseSurface` fill (matching
  `Tooltip.qml`'s color choice), `Color.scheme.inverseOnSurface` text,
  `Shape.extraSmall` corner radius (per M3 spec — snackbars use small
  corners, not the fully-rounded pill shape search/tooltips use elsewhere
  in this app).
- Bottom-anchored, horizontally centered, high `z` so it floats above the
  file view/sidebar/dialogs.
- Auto-dismisses after 4000ms.
- **Replace, not queue:** if a new error arrives while one is already
  showing, the message is replaced and the 4s timer restarts. No stacking
  or queueing of multiple simultaneous messages — keeps this simple, and
  matches the "one summary per batch" decision already made for the
  batch-operation case.
- No action button (no "Retry"/"Dismiss") — auto-dismiss only. Retry would
  need per-operation retry plumbing that doesn't exist yet; out of scope
  here.
- Always instantiated directly in `main.qml` (not behind a `Loader`) — it's
  tiny (Rectangle + Text + Timer, same class of component as
  `TransferStatus.qml`) and needs to be listening for the whole app
  lifetime, so lazy-loading it wouldn't save anything (consistent with the
  RAM audit conclusion earlier in this project).

## Verification

Per project convention, `cargo build -p fm-app` (qmlcachegen + cxx-qt
codegen, catches signal-signature mismatches and QML binding errors) is the
automated ceiling; no QML test harness exists. Interactive verification
(triggering an actual failure — e.g. renaming a file to a name that already
exists as a directory, or deleting something with permissions removed) is
done by the user themselves, not via the `run` skill.
