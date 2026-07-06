# Phone (MTP) Volumes + Live Mount Updates — Design

**Date:** 2026-07-06
**Status:** Approved

Three related changes to the sidebar's Storage section:

1. Phones (MTP over gvfs) appear as storage cards, mount on click, and
   open for browsing — like Nautilus.
2. Mount/unmount changes show up immediately via kernel/gvfs
   notifications instead of only the 10 s poll.
3. The volume list becomes a stable QML ListModel synced in place, so
   cards stop being destroyed/recreated on every refresh or tab switch
   (which replayed the gauge entrance animation).

## fm-core (`volumes.rs`)

- `Volume` gains `kind: VolumeKind` (`Disk` | `Phone`) and
  `mounted: bool`. For phones, `device` holds the `mtp://` activation
  URI and `mount_point` the gvfs FUSE path; `total_bytes`/`avail_bytes`
  stay 0 (MTP reports no meaningful statvfs).
- `parse_gio_volumes(text) -> Vec<(String, String)>`: pure parser over
  `gio mount -li` output; returns (name, activation_root) for volumes
  whose Type mentions `GProxyVolumeMonitorMTP`. Tested.
- `mtp_fuse_path(uri, uid) -> PathBuf`: `mtp://HOST/` →
  `/run/user/<uid>/gvfs/mtp:host=HOST`. Tested.
- `current_gvfs_dir() -> PathBuf`: `/run/user/<getuid>/gvfs` (libc is a
  fm-core dep only).
- `list_phone_volumes() -> Vec<Volume>` (async): runs `gio mount -li`,
  maps parsed volumes; `mounted` = FUSE path is a dir.
- `mount_uri(uri)` (async): `gio mount <uri>`, stderr as the error.
- `eject(device)`: routes `mtp://` devices to `gio mount -u <uri>`,
  block devices to `udisksctl unmount -b` as today.
- `spawn_mounts_watcher(on_change)`: background thread, `poll()` on
  `/proc/self/mounts` with `POLLPRI` (procfs is not inotify-watchable;
  POLLPRI is the kernel's mount-table change signal), re-reads the file
  each event, calls `on_change` after each change. Not unit-testable;
  covered by the parser/path tests plus manual verification.

## FileListModel

- `refresh_volumes` becomes async: disks via `spawn_blocking`, phones
  via `list_phone_volumes().await`, result queued to the Qt thread.
  `volumesText` grows from 5 to 7 `` fields:
  label, mount, total, avail, device, kind ("disk"/"phone"),
  mounted ("1"/"0").
- First `refresh_volumes` call per model lazily starts (guarded by a
  bool field): the mounts watcher (queues `refresh_volumes`) and a
  `DirWatcher` on the gvfs dir (drains bursts, queues
  `refresh_volumes`). Watcher handle stored on the struct.
- New invokable `mountVolume(uri, mountPath)`: `mount_uri`, then wait up
  to 3 s (100 ms steps) for the FUSE dir, then queue refresh + navigate
  into it. Failure emits `error_occurred` ("Couldn't open <label>: …").

## Sidebar QML

- `readonly property var volumes` (array rebuilt every change) is
  replaced by a `ListModel` synced in place from `volumesText`: rows
  matched by `mount`, updated via `set`, appended when new, removed when
  gone. Delegates persist; the entrance sweep plays only for genuinely
  new volumes. Sync runs on `volumesText` change (covers tab switches
  via a string property bound to the active model).
- Delegate switches from `modelData` to per-role required properties
  (label, mount, total, avail, device, kind, mounted).
- Phone cards: a `smartphone` icon fills the 64px slot instead of a
  gauge; caption is "Connected" when mounted, "Click to open" when not.
- Click: unmounted phone → `mountVolume(device, mount)`; otherwise
  `navigate(mount)`. Eject button shows for non-root disks and mounted
  phones.
- The 10 s Timer stays (capacity numbers only; mount changes arrive via
  the watchers).

## Out of scope

- Per-storage MTP capacity (gvfs doesn't expose it via statvfs).
- Watching for phone *attachment* before gvfs sees it (gio's volume
  monitor handles that; the gvfs watcher + poll catch the rest).

## Verification

`cargo test -p fm-core`; `cargo build -p fm-app`; user verifies
visually: phone card appears, click mounts + opens, eject disconnects,
mount/unmount of a USB stick appears within a second, gauges no longer
re-animate on refresh or tab switch.
