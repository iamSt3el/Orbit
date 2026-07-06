# Phone Volumes + Live Mounts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** MTP phones show as mountable/browsable storage cards; mount changes appear instantly; gauge cards stop re-animating on refresh.

**Architecture:** Pure parsers + async gio wrappers in fm-core; FileListModel refreshes volumes off-thread and lazily starts a POLLPRI mounts watcher plus a gvfs DirWatcher; the sidebar syncs a stable ListModel in place.

**Tech Stack:** Rust (libc poll, tokio process), QML ListModel.

**Spec:** `docs/superpowers/specs/2026-07-06-phone-volumes-and-live-mounts-design.md`

## Global Constraints

- No code comments in new/edited code (user instruction, 2026-07-06).
- fm-core tests in `crates/core/tests/`, never inline.
- QML compiles into the binary: `cargo build -p fm-app` after QML edits.
- Never launch the app; the user verifies visually.
- Commits end with the Claude Fable 5 trailer.

---

### Task 1: fm-core — parsers, phone listing, mount/eject, mounts watcher (TDD)

**Files:** Modify `crates/core/src/volumes.rs`; Test `crates/core/tests/volumes.rs`.

**Produces:** `VolumeKind`, `Volume{kind,mounted}`, `parse_gio_volumes`, `mtp_fuse_path`, `current_gvfs_dir`, `list_phone_volumes` (async), `mount_uri` (async), mtp-aware `eject`, `spawn_mounts_watcher`.

Steps: failing tests for `parse_gio_volumes` (real `gio mount -li` sample: skips UDisks2 volume, finds MTP name+root) and `mtp_fuse_path`; run (fail); implement; run (pass); `cargo build -p fm-app` still compiles (list_volumes construction sites updated); commit.

### Task 2: FileListModel — async refresh, watchers, mountVolume

**Files:** Modify `crates/app/src/file_list_model.rs`.

Steps: rewrite `refresh_volumes` (spawn: disks via `spawn_blocking(list_volumes)` + `list_phone_volumes().await`, join 7-field lines, queue set if changed); add fields `volumes_watch_started: bool`, `gvfs_watcher: Option<DirWatcher>` (+ Default); lazy `start_volume_watches()` on first refresh (spawn_mounts_watcher → queue refresh; DirWatcher on `current_gvfs_dir()` with burst drain → queue refresh); add `mountVolume(uri, mountPath)` invokable per spec; update volumesText qproperty doc format note; `cargo build -p fm-app`; commit.

### Task 3: Sidebar — stable ListModel + phone cards

**Files:** Modify `crates/app/qml/components/Sidebar.qml`.

Steps: replace `volumes` array property with `ListModel` + `syncVolumes()` (match by mount, set/append/remove) driven by a bound `_volumesText` string; delegate switches to required role properties; phone slot (Icon `smartphone` when kind==="phone", gauge otherwise); caption ternary (phone → mounted ? "Connected" : "Click to open"); click routes to `mountVolume` for unmounted phones; eject visibility per spec; section `visible` uses `volumesModel.count`; `cargo build -p fm-app`; commit.

### Task 4: Verification

`cargo test -p fm-core` all green; `cargo build -p fm-app` clean; hand off for visual check (phone mount/open/eject, instant USB mount updates, no gauge re-animation).
