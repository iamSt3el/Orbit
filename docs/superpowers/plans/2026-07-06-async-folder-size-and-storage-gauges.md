# Async Folder Size + Storage Gauges Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Properties dialog opens instantly with a live-ticking folder size computed in the background; the sidebar gains a "Storage" section of circular gauge cards (one per mounted volume) ported from the user's quickshell `CustomGaugeProgress`.

**Architecture:** A cancellable recursive walk in fm-core reports running totals through a callback; `FileListModel` drives it from a tokio `spawn_blocking`, throttling progress back to the Qt thread via `qt_thread().queue` behind an `Arc<AtomicU64>` generation guard (same idea as `listing_generation`). The gauges are pure QML — a Canvas-drawn 270° arc fed by the existing `volumesText` qproperty.

**Tech Stack:** Rust (fm-core, cxx-qt FileListModel), QML (Canvas, Column/Grid), tokio.

**Spec:** `docs/superpowers/specs/2026-07-06-async-folder-size-and-storage-gauges-design.md`

## Global Constraints

- fm-core tests live in `crates/core/tests/` (external files), never inline `#[cfg(test)]` in src/.
- QML is compiled into the binary — every `.qml`/`.js` change needs `cargo build -p fm-app` to take effect, and new QML files must be registered in `crates/app/build.rs`.
- Never write bare `fileModel: fileModel` in main.qml; qualify as `window.fileModel`/`window.fileListModel` (shadowing trap). Not needed here — no main.qml changes — but applies if any task drifts there.
- Bool qproperties/QML bools: never bind bare `a && b` chains where `a` can be undefined; use ternaries.
- Do NOT launch the app to verify — the user verifies visually themselves.
- Commit after every task with the `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>` trailer.

---

### Task 1: fm-core `dir_size_with_progress`

**Files:**
- Modify: `crates/core/src/ops.rs` (add function after `path_size`, ~line 113)
- Test: `crates/core/tests/ops.rs` (append)

**Interfaces:**
- Consumes: nothing new.
- Produces: `pub fn dir_size_with_progress(path: &Path, progress: &mut impl FnMut(u64, u64) -> bool) -> (u64, u64)` — returns `(bytes, items)`; callback gets running `(bytes_so_far, items_so_far)` per entry and returns `false` to abort (function then returns totals-so-far). Task 2 calls it as `fm_core::ops::dir_size_with_progress(...)`.

- [ ] **Step 1: Write the failing tests**

Append to `crates/core/tests/ops.rs`:

```rust
#[test]
fn dir_size_with_progress_totals_bytes_and_items_recursively() {
    let dir = tempdir().unwrap();
    fs::write(dir.path().join("a.txt"), vec![0u8; 100]).unwrap();
    fs::create_dir(dir.path().join("sub")).unwrap();
    fs::write(dir.path().join("sub/b.txt"), vec![0u8; 50]).unwrap();
    fs::write(dir.path().join("sub/c.txt"), vec![0u8; 25]).unwrap();

    let (bytes, items) = ops::dir_size_with_progress(dir.path(), &mut |_, _| true);

    assert_eq!(bytes, 175);
    // a.txt + sub + sub/b.txt + sub/c.txt — directories count as items.
    assert_eq!(items, 4);
}

#[test]
fn dir_size_with_progress_reports_running_totals_to_the_callback() {
    let dir = tempdir().unwrap();
    fs::write(dir.path().join("a.txt"), vec![0u8; 10]).unwrap();
    fs::write(dir.path().join("b.txt"), vec![0u8; 20]).unwrap();

    let mut calls: Vec<(u64, u64)> = Vec::new();
    let (bytes, items) = ops::dir_size_with_progress(dir.path(), &mut |b, i| {
        calls.push((b, i));
        true
    });

    assert_eq!(bytes, 30);
    assert_eq!(items, 2);
    assert_eq!(calls.len(), 2);
    // The last callback carries the final totals.
    assert_eq!(*calls.last().unwrap(), (30, 2));
}

#[test]
fn dir_size_with_progress_aborts_when_the_callback_returns_false() {
    let dir = tempdir().unwrap();
    for n in 0..10 {
        fs::write(dir.path().join(format!("f{n}.txt")), vec![0u8; 10]).unwrap();
    }

    let mut calls = 0u64;
    let (_, items) = ops::dir_size_with_progress(dir.path(), &mut |_, _| {
        calls += 1;
        calls < 3
    });

    assert_eq!(calls, 3);
    assert!(items < 10, "walk kept going after the callback said stop");
}

#[test]
fn dir_size_with_progress_returns_zero_for_an_unreadable_path() {
    let (bytes, items) =
        ops::dir_size_with_progress(std::path::Path::new("/nonexistent/nope"), &mut |_, _| true);

    assert_eq!(bytes, 0);
    assert_eq!(items, 0);
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cargo test -p fm-core --test ops dir_size_with_progress`
Expected: compile error — `dir_size_with_progress` not found in `ops`.

- [ ] **Step 3: Implement**

In `crates/core/src/ops.rs`, after `path_size`:

```rust
/// Recursively totals a directory's bytes and entry count, invoking
/// `progress(bytes_so_far, items_so_far)` once per entry encountered.
/// Items count every entry recursively — files AND directories — matching
/// Nautilus's Properties "contents" semantics. Returning `false` from the
/// callback aborts the walk early; the totals accumulated so far are
/// returned either way. Unreadable directories are skipped silently.
pub fn dir_size_with_progress(
    path: &Path,
    progress: &mut impl FnMut(u64, u64) -> bool,
) -> (u64, u64) {
    let mut bytes = 0u64;
    let mut items = 0u64;
    dir_size_walk(path, &mut bytes, &mut items, progress);
    (bytes, items)
}

/// Returns false if the callback asked to abort (propagates up the
/// recursion so the whole walk unwinds immediately).
fn dir_size_walk(
    path: &Path,
    bytes: &mut u64,
    items: &mut u64,
    progress: &mut impl FnMut(u64, u64) -> bool,
) -> bool {
    let Ok(entries) = std::fs::read_dir(path) else {
        return true;
    };
    for entry in entries.flatten() {
        // metadata() on a DirEntry uses lstat on Unix (doesn't follow
        // symlinks), so a symlink counts its own small size, never the
        // target's — avoiding both double-counting and symlink-cycle
        // infinite recursion.
        match entry.metadata() {
            Ok(metadata) if metadata.is_dir() => {
                *items += 1;
                if !progress(*bytes, *items) {
                    return false;
                }
                if !dir_size_walk(&entry.path(), bytes, items, progress) {
                    return false;
                }
            }
            Ok(metadata) => {
                *items += 1;
                *bytes += metadata.len();
                if !progress(*bytes, *items) {
                    return false;
                }
            }
            Err(_) => {}
        }
    }
    true
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cargo test -p fm-core --test ops dir_size_with_progress`
Expected: 4 passed.

- [ ] **Step 5: Commit**

```bash
git add crates/core/src/ops.rs crates/core/tests/ops.rs
git commit -m "feat(core): cancellable dir_size_with_progress walk"
```

---

### Task 2: FileListModel scan qproperties + invokables

**Files:**
- Modify: `crates/app/src/file_list_model.rs`

**Interfaces:**
- Consumes: `fm_core::ops::dir_size_with_progress` (Task 1).
- Produces (QML-visible): qproperties `folderScanBytes` (i64), `folderScanItems` (i32), `folderScanRunning` (bool); invokables `startFolderSizeScan(name: string)`, `cancelFolderSizeScan()`. Removes `folderSize(name)` and `folderItemCount(name)` — Task 3 must land before the next app run, since PropertiesDialog.qml still calls them until then.

- [ ] **Step 1: Add qproperty declarations**

In the `#[qproperty(...)]` block (after the `volumes_text` qproperty, ~line 94):

```rust
        // Live folder-size scan for the Properties dialog (round-3): the
        // dialog opens instantly and a background walk ticks these until
        // folderScanRunning drops back to false — see
        // start_folder_size_scan().
        #[qproperty(i64, folder_scan_bytes, cxx_name = "folderScanBytes")]
        #[qproperty(i32, folder_scan_items, cxx_name = "folderScanItems")]
        #[qproperty(bool, folder_scan_running, cxx_name = "folderScanRunning")]
```

- [ ] **Step 2: Replace the folderSize/folderItemCount invokable declarations**

In the `unsafe extern "RustQt"` block (~line 445), delete:

```rust
        #[qinvokable]
        #[cxx_name = "folderItemCount"]
        fn folder_item_count(self: &FileListModel, name: &QString) -> i32;

        #[qinvokable]
        #[cxx_name = "folderSize"]
        fn folder_size(self: &FileListModel, name: &QString) -> i64;
```

and add in their place:

```rust
        /// Kicks off (or restarts) the background folder-size walk whose
        /// progress lands in the folderScan* qproperties.
        #[qinvokable]
        #[cxx_name = "startFolderSizeScan"]
        fn start_folder_size_scan(self: Pin<&mut FileListModel>, name: &QString);

        /// Aborts any in-flight walk (generation bump — the walker's
        /// callback notices and unwinds).
        #[qinvokable]
        #[cxx_name = "cancelFolderSizeScan"]
        fn cancel_folder_size_scan(self: Pin<&mut FileListModel>);
```

- [ ] **Step 3: Add struct fields and Default entries**

In `FileListModelRust` (after `pending_transfer: Option<PendingTransfer>,`):

```rust
    /// Backings for the folderScan* qproperties — see
    /// start_folder_size_scan().
    folder_scan_bytes: i64,
    folder_scan_items: i32,
    folder_scan_running: bool,
    /// Stale-guard for the background folder-size walk. Arc'd (unlike
    /// listing_generation) because the walker thread must observe a
    /// cancel MID-WALK to stop burning I/O, not merely have its result
    /// dropped on arrival.
    folder_scan_generation: std::sync::Arc<std::sync::atomic::AtomicU64>,
```

In `impl Default for FileListModelRust` (after `pending_transfer: None,`):

```rust
            folder_scan_bytes: 0,
            folder_scan_items: 0,
            folder_scan_running: false,
            folder_scan_generation: std::sync::Arc::new(std::sync::atomic::AtomicU64::new(0)),
```

- [ ] **Step 4: Replace the implementations**

Delete the `folder_item_count` and `folder_size` methods (~lines 2474–2492) and the now-unused private `fn dir_size` helper (~line 2883, including its doc comments). Add in the methods' place:

```rust
    /// Spawns a cancellable background walk of current_path/name, ticking
    /// the folderScan* qproperties at most every ~100ms. Guarded by
    /// folder_scan_generation on BOTH sides: the walker aborts mid-walk
    /// when superseded/cancelled, and queued updates are dropped on the
    /// Qt thread if stale by the time they run.
    fn start_folder_size_scan(mut self: core::pin::Pin<&mut Self>, name: &QString) {
        use std::sync::atomic::Ordering;

        let target = PathBuf::from(self.current_path.to_string()).join(name.to_string());
        let shared = self.folder_scan_generation.clone();
        let generation = shared.fetch_add(1, Ordering::SeqCst) + 1;
        self.as_mut().set_folder_scan_bytes(0);
        self.as_mut().set_folder_scan_items(0);
        self.as_mut().set_folder_scan_running(true);

        let qt_thread = self.qt_thread();
        runtime().spawn_blocking(move || {
            let mut last_tick = std::time::Instant::now();
            let (bytes, items) =
                fm_core::ops::dir_size_with_progress(&target, &mut |bytes, items| {
                    if shared.load(Ordering::SeqCst) != generation {
                        return false;
                    }
                    if last_tick.elapsed() >= std::time::Duration::from_millis(100) {
                        last_tick = std::time::Instant::now();
                        let _ = qt_thread.queue(move |mut model| {
                            if model.folder_scan_generation.load(Ordering::SeqCst) != generation {
                                return;
                            }
                            model.as_mut().set_folder_scan_bytes(bytes as i64);
                            model.as_mut().set_folder_scan_items(items as i32);
                        });
                    }
                    true
                });
            if shared.load(Ordering::SeqCst) != generation {
                return;
            }
            let _ = qt_thread.queue(move |mut model| {
                if model.folder_scan_generation.load(Ordering::SeqCst) != generation {
                    return;
                }
                model.as_mut().set_folder_scan_bytes(bytes as i64);
                model.as_mut().set_folder_scan_items(items as i32);
                model.as_mut().set_folder_scan_running(false);
            });
        });
    }

    fn cancel_folder_size_scan(mut self: core::pin::Pin<&mut Self>) {
        self.folder_scan_generation
            .fetch_add(1, std::sync::atomic::Ordering::SeqCst);
        self.as_mut().set_folder_scan_running(false);
    }
```

- [ ] **Step 5: Build**

Run: `cargo build -p fm-app 2>&1 | tail -5`
Expected: `Finished` with no errors (a pre-existing `unused_mut` warning elsewhere is fine). If `runtime().spawn_blocking` doesn't resolve, use `runtime().spawn(async move { ... })` wrapping the same closure body via `tokio::task::spawn_blocking` (the pattern at `file_list_model.rs:2266`).

- [ ] **Step 6: Commit**

```bash
git add crates/app/src/file_list_model.rs
git commit -m "feat(app): background folder-size scan with live progress qproperties"
```

---

### Task 3: PropertiesDialog live-updating Size row

**Files:**
- Modify: `crates/app/qml/components/PropertiesDialog.qml`

**Interfaces:**
- Consumes: `folderScanBytes`/`folderScanItems`/`folderScanRunning` qproperties, `startFolderSizeScan(name)`, `cancelFolderSizeScan()` (Task 2).
- Produces: nothing new outward — same `open()`/`close()` API.

- [ ] **Step 1: Start the scan on open, cancel on close**

In `function open(...)` (line 35), after `root.entryPermissions = permissions` and before `visible = true`, add:

```qml
        // Folder sizes are computed by a background walk (Nautilus-style)
        // so the dialog opens instantly — the Size fact live-ticks from
        // the folderScan* properties until the walk lands.
        if (isDir && root.fileModel) {
            root.fileModel.startFolderSizeScan(name)
        }
```

In `function close()` (line 46), before `visible = false`, add:

```qml
        if (root.entryIsDir && root.fileModel) {
            root.fileModel.cancelFolderSizeScan()
        }
```

- [ ] **Step 2: Rebind the Size fact**

Replace the Size entry in `_facts` (lines 61–69):

```qml
        {
            icon: "storage",
            label: "Size",
            value: root.entryIsDir
                ? (root.fileModel
                    ? (root.fileModel.folderScanRunning && root.fileModel.folderScanBytes === 0
                        ? "Calculating…"
                        : Format.formatBytes(root.fileModel.folderScanBytes)
                            + " (" + Format.formatItemCount(root.fileModel.folderScanItems) + ")")
                    : "—")
                : Format.formatBytes(root.entrySize)
        },
```

Note the update to the comment above `property real entrySize` is NOT needed — file sizes still flow through `entrySize`; only folders changed. Item count is now recursive (whole tree), not immediate children — intentional, matches Nautilus.

- [ ] **Step 3: Build (qmlcachegen validates the QML)**

Run: `cargo build -p fm-app 2>&1 | tail -3`
Expected: `Finished`, no QML errors.

- [ ] **Step 4: Commit**

```bash
git add crates/app/qml/components/PropertiesDialog.qml
git commit -m "feat(app): Properties opens instantly, folder size live-ticks"
```

---

### Task 4: GaugeProgress component

**Files:**
- Create: `crates/app/qml/components/GaugeProgress.qml`
- Modify: `crates/app/build.rs` (register the new file in the `qml_files` list, next to `"qml/components/WavyProgressBar.qml"`)

**Interfaces:**
- Consumes: `Icon` (props: `content`, `iconSize`, `color`), `Color.scheme`, `Type` singletons from `com.filemanager.app`.
- Produces: `GaugeProgress` with properties `progress` (real 0–1), `thickness` (real), `trackColor`/`progressColor` (color), `icon` (string glyph name), `iconSize` (real), `gap` (real, radians). Task 5 instantiates it.

- [ ] **Step 1: Create the component**

`crates/app/qml/components/GaugeProgress.qml`:

```qml
import QtQuick
import com.filemanager.app 1.0

// Circular 270° gauge — gap at the bottom, rounded caps, and a floating
// gap between the progress tip and the remaining track. Ported from the
// user's quickshell "Nebula" CustomGaugeProgress (minus its wavy mode);
// icon + percent + "Used" stack in the center, like the Nebula dashboard
// storage cards this is modeled on.
Item {
    id: root

    property real progress: 0
    property real thickness: 4
    property real gaugeRadius: Math.min(width, height) / 2 - thickness
    property color trackColor: Color.scheme.secondaryContainer
    property color progressColor: Color.scheme.primary
    property string icon: ""
    property real iconSize: 16
    // Radians of breathing room between the progress tip and the track.
    property real gap: 0.4

    Behavior on progress {
        NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true

        readonly property real cx: width / 2
        readonly property real cy: height / 2
        // 270° arc, gap at bottom — starts bottom-left, ends bottom-right.
        readonly property real startAngle: Math.PI * 0.75
        readonly property real totalSpan: Math.PI * 1.5
        readonly property real trackEnd: startAngle + totalSpan
        readonly property real progressEnd:
            startAngle + totalSpan * Math.max(0, Math.min(1, root.progress))

        onProgressEndChanged: requestPaint()

        // Colors are dependencies too — colors.json is hot-reloadable,
        // and a Canvas only repaints when asked.
        readonly property color _track: root.trackColor
        readonly property color _fill: root.progressColor
        on_TrackChanged: requestPaint()
        on_FillChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.lineWidth = root.thickness
            ctx.lineCap = "round"
            const r = root.gaugeRadius

            // The track starts a gap past the progress tip (never more
            // than half the filled span, so tiny fills don't eat it).
            const arcSpan = progressEnd - startAngle
            const effectiveGap = root.progress > 0 ? Math.min(root.gap, arcSpan * 0.5) : 0
            const bgStart = progressEnd + effectiveGap
            if (bgStart < trackEnd) {
                ctx.beginPath()
                ctx.arc(cx, cy, r, bgStart, trackEnd, false)
                ctx.strokeStyle = root.trackColor
                ctx.stroke()
            }

            if (root.progress > 0) {
                ctx.beginPath()
                ctx.arc(cx, cy, r, startAngle, progressEnd - effectiveGap, false)
                ctx.strokeStyle = root.progressColor
                ctx.stroke()
            }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 0

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.icon.length > 0
            content: root.icon
            iconSize: root.iconSize
            color: root.progressColor
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Math.round(root.progress * 100) + "%"
            color: Color.scheme.primary
            font.family: Type.titleMedium.family
            font.weight: Type.titleMedium.weight
            font.pixelSize: Type.titleMedium.size
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Used"
            color: Color.scheme.surfaceVariantText
            font.family: Type.labelMedium.family
            font.pixelSize: Type.labelMedium.size
        }
    }
}
```

- [ ] **Step 2: Register in build.rs**

In `crates/app/build.rs`, add to the `qml_files` array (after `"qml/components/WavyProgressBar.qml",`):

```rust
                "qml/components/GaugeProgress.qml",
```

- [ ] **Step 3: Build**

Run: `cargo build -p fm-app 2>&1 | tail -3`
Expected: `Finished`, no QML errors. (build.rs changed, so the QML module recompiles.)

- [ ] **Step 4: Commit**

```bash
git add crates/app/qml/components/GaugeProgress.qml crates/app/build.rs
git commit -m "feat(app): GaugeProgress — 270° gauge ported from quickshell Nebula"
```

---

### Task 5: Sidebar Storage section

**Files:**
- Modify: `crates/app/qml/components/Sidebar.qml`
- Modify: `crates/app/qml/util/format.js`

**Interfaces:**
- Consumes: `GaugeProgress` (Task 4), existing `root.volumes` (label/mount/total/avail/device), `Format.formatBytesPair` (added here).
- Produces: `Format.formatBytesPair(used, total)` in format.js (usable elsewhere later).

- [ ] **Step 1: Add the pair formatter to format.js**

In `crates/app/qml/util/format.js`, after `formatItemCount`:

```js
// "3.5 / 9.6 GB" — used and total share the total's unit so the pair
// reads as one fraction (the storage gauge cards' caption).
function formatBytesPair(used, total) {
    if (total < 1024) {
        return used + " / " + total + " B"
    }
    var units = ["KB", "MB", "GB", "TB", "PB"]
    var div = 1024
    var unitIndex = 0
    while (total / div >= 1024 && unitIndex < units.length - 1) {
        div *= 1024
        unitIndex++
    }
    return (used / div).toFixed(1) + " / " + (total / div).toFixed(1) + " " + units[unitIndex]
}
```

- [ ] **Step 2: Import format.js in Sidebar**

At the top of `crates/app/qml/components/Sidebar.qml` (after `import com.filemanager.app 1.0`):

```qml
import "../util/format.js" as Format
```

- [ ] **Step 3: Insert the Storage section**

In the sidebar's content `Column`, directly after the Places `Repeater`'s closing brace (the repeater over `_shortcuts`+pinned at ~line 146–221) and BEFORE the `Text { text: "Devices" ... }` header (~line 223) — NOT at the bottom of the sidebar, which belongs to the TransferStatus copy indicator — insert:

```qml
        Text {
            visible: root.volumes.length > 0
            text: "Storage"
            leftPadding: 10
            topPadding: 14
            bottomPadding: 10
            color: Color.scheme.surfaceVariantText
            font.family: Type.labelMedium.family
            font.weight: Type.labelMedium.weight
            font.pixelSize: Type.labelMedium.size
        }

        // One gauge card per mounted volume, 2-up like the Nebula
        // dashboard cards these are modeled on; wraps when a third
        // volume mounts.
        Grid {
            visible: root.volumes.length > 0
            width: parent.width
            columns: 2
            columnSpacing: 8
            rowSpacing: 8

            Repeater {
                model: root.volumes

                delegate: Rectangle {
                    id: gaugeCard
                    required property var modelData
                    readonly property real usedBytes: modelData.total - modelData.avail

                    width: (parent.width - 8) / 2
                    height: gaugeCardContent.implicitHeight + 20
                    radius: Shape.large
                    color: Elevation.surfaceAt(2)

                    Column {
                        id: gaugeCardContent
                        anchors.centerIn: parent
                        width: parent.width - 16
                        spacing: 6

                        GaugeProgress {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 62
                            height: 62
                            progress: gaugeCard.modelData.total > 0
                                ? gaugeCard.usedBytes / gaugeCard.modelData.total : 0
                            icon: gaugeCard.modelData.mount === "/" ? "hard_drive" : "usb"
                            iconSize: 14
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Format.formatBytesPair(gaugeCard.usedBytes, gaugeCard.modelData.total)
                            color: Color.scheme.surfaceVariantText
                            font.family: Type.labelMedium.family
                            font.pixelSize: Type.labelMedium.size
                        }
                    }
                }
            }
        }
```

- [ ] **Step 4: Remove the Devices rows' linear capacity bars**

In the Devices delegate, delete the `// Capacity bar: filled fraction = used space.` comment and the whole `Rectangle { ... }` it labels (~lines 285–300 — the 3px-tall bar with the nested fill Rectangle). The `usedFrac` property on `volItem` (~line 243) becomes unused — delete it too. The label `Text` stays; the surrounding `Column`'s `spacing: 4` is harmless with one child.

- [ ] **Step 5: Build**

Run: `cargo build -p fm-app 2>&1 | tail -3`
Expected: `Finished`, no QML errors.

- [ ] **Step 6: Commit**

```bash
git add crates/app/qml/components/Sidebar.qml crates/app/qml/util/format.js
git commit -m "feat(app): sidebar Storage section — per-volume gauge cards"
```

---

### Task 6: Full verification

- [ ] **Step 1: Run the test suites**

Run: `cargo test -p fm-core && cargo build -p fm-app 2>&1 | tail -3`
Expected: all fm-core tests pass; app builds clean.

- [ ] **Step 2: Hand off to the user for visual verification**

Do NOT launch the app. Ask the user to run `target/debug/fm-app` and check:
- Properties on a large folder (e.g. `~`) opens instantly; Size shows "Calculating…" then ticks up live and settles.
- Properties on a file is unchanged.
- Sidebar shows the Storage section after Places with a gauge card per volume; percentages match `df -h`.
- Devices rows have no thin bars anymore; navigation and eject still work.
- Copy something big: the bottom-of-sidebar transfer indicator still renders without overlap.
