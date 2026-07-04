# Live directory watching

## Context

The view only refreshes after this app's *own* operations — a file
created, deleted, or renamed by any other program (a terminal, a
download, another file manager) is invisible until the user triggers an
operation or re-navigates. `fm_core::watcher::DirWatcher` (notify-based,
non-recursive, unit-tested) already exists but is wired only to
theme-colors reloading. This spec wires it to the current directory.

## Approach: debounced re-list

Watch events never patch the model directly. Any event on the current
directory schedules the existing `refresh_entries_diff()` after a quiet
period — reusing the smooth row-level diff, the background listing, and
the `listing_generation` stale-guard (see
`project-filemanager-model-invariants`). A re-list is self-healing:
notify events on Linux can be dropped or coalesced, so granular
per-event model surgery drifts; a full re-list cannot.

**Debounce rule:** flush after **250ms without a new event**, but no
later than **1s after the first event of a burst** — a continuous
writer (an active download) must not starve refreshes forever. An untar
of 10k files causes a handful of refreshes, not 10k.

## Watcher lifecycle (`file_list_model.rs`)

- New field `dir_watcher: Option<fm_core::watcher::DirWatcher>` on
  `FileListModelRust` (same keep-alive-for-Drop pattern as
  `theme_colors_watcher`), plus a private `start_dir_watch()` method
  called at the end of `navigate()` after `current_path` is set.
- `start_dir_watch()` replaces the previous watcher. Dropping the old
  `DirWatcher` stops its OS watch and drops its channel sender, which
  ends the old drain task (its `rx.recv()` returns `None`).
- Setup failure (permissions, inotify limit, directory vanished) is
  non-fatal: `eprintln!` and leave `dir_watcher` as `None` — that
  directory simply behaves as today (refresh only after own
  operations).
- Startup: the initial `navigate()` from QML `Component.onCompleted`
  goes through the same path — no separate startup hook.

## Drain task

One task per watch, spawned on the shared runtime:

```text
loop {
    first = rx.recv()            // None => watcher dropped => exit
    deadline = now + 1s
    loop {
        remaining_quiet = 250ms
        match timeout(min(remaining_quiet, deadline - now), rx.recv()):
            timed out            => break   // quiet, or 1s cap hit
            Some(_)              => continue // still bursting
            None                 => flush then exit
    }
    qt_thread.queue(|model| {
        if model.current_path == watched_dir { model.refresh_entries_diff() }
    })
}
```

The `current_path` check makes a late event from an already-left
directory harmless even before `refresh_entries_diff`'s own generation
guard kicks in. Our own operations produce both their explicit refresh
and a watcher-driven one ~250ms later; the second is a visual no-op
because the diff finds nothing to change.

## Metadata-aware diff (`apply_entries_diff`)

Two gaps matter once refreshes happen behind the user's back:

1. **Row-diff path — phase 3.** `same_entry` matches on name+is_dir
   only, so an externally growing file never updates its size/modified
   columns. After the existing remove/insert phases, walk rows present
   in both listings: where size, modified, permissions, or mime_type
   differ, overwrite the stored entry with the new one and emit
   `dataChanged` for that displayed row. When `modified` changed, the
   new entry's `thumbnail_path` stays `None` (the old thumbnail is
   stale); the delegate re-requests it. When `modified` is unchanged,
   carry the old `thumbnail_path` over.
2. **Reset fallback path** (the default — hidden files are filtered).
   Every refresh currently wipes all `thumbnail_path`s, so live
   refreshes would flicker thumbnails and re-probe the cache. Before
   the reset, carry over the old entry's `thumbnail_path` onto the new
   entry when name, is_dir, and modified are all unchanged.

The pure pieces — `entry_metadata_changed(a, b) -> bool` and
`carry_over_thumbnails(old, new)` — are free functions with unit tests
in the existing in-file test-module style of `file_list_model.rs`.

## Scope

- Non-recursive: the current directory only. No sidebar badge, no
  watching of subfolders, no recursive invalidation.
- No new QML, invokables, properties, or signals — entirely Rust-side.
- Trash view is watched like any other directory (it is one).

## Verification

- `cargo test -p fm-app`: new unit tests for `entry_metadata_changed`
  and `carry_over_thumbnails`.
- `cargo test -p fm-core`: unchanged (DirWatcher already tested).
- `cargo build -p fm-app` as the automated ceiling for the wiring.
- Interactive verification by the user (per project convention):
  `touch`/`mkdir`/`rm`/`mv` in a terminal while the app displays that
  folder — rows appear/vanish within ~a quarter second; `truncate -s`
  on a visible file updates its size column; a `wget` into the folder
  updates periodically rather than never; navigating away stops
  updates from the old folder.
