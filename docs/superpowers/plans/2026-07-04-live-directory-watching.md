# Live Directory Watching Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The current directory's view refreshes automatically when any other program creates, deletes, renames, or modifies files in it.

**Architecture:** `navigate()` (re)starts a non-recursive `fm_core::watcher::DirWatcher` on each directory it enters; a drain task coalesces event bursts (250ms quiet, 1s hard cap) into calls to the existing `refresh_entries_diff()` (which already lists in the background under the `listing_generation` stale-guard). `apply_entries_diff` gains a metadata phase so externally changed sizes/mtimes update their rows, plus thumbnail carry-over so live refreshes don't flicker thumbnails.

**Tech Stack:** Rust (cxx-qt 0.9, tokio `full`, notify via existing `fm_core::watcher`). No QML changes.

## Global Constraints

- Full spec: `docs/superpowers/specs/2026-07-04-live-directory-watching-design.md` — read it if anything below is ambiguous.
- **Debounce rule:** flush after **250ms without a new event**, but no later than **1s after the first event of a burst**.
- **Watch setup failure is non-fatal**: `eprintln!` and leave `dir_watcher` as `None` — the directory then behaves exactly as before this feature.
- **Model invariants must hold** (see the `displayed` cache and `listing_generation` notes at the top of `FileListModelRust`): phase 3 mutates entry *contents* only (never names/order/count), so it must NOT rebuild `displayed` and must NOT emit insert/remove — only `dataChanged`.
- Non-recursive, current directory only. No new QML, invokables, properties, or signals.
- **Verification ceiling**: `cargo build -p fm-app` (~2 minutes per run, normal) plus `cargo test -p fm-app`. Live behavior is interactively verified by the user at the end — do not launch/screenshot the app yourself, per this project's verification style.

---

### Task 1: Pure helpers — `entry_metadata_changed`, `carry_over_thumbnails` (TDD)

**Files:**
- Modify: `crates/app/src/file_list_model.rs`

**Interfaces:**
- Produces: `fn entry_metadata_changed(old: &fm_core::FileEntry, new: &fm_core::FileEntry) -> bool` and `fn carry_over_thumbnails(old: &[fm_core::FileEntry], new: &mut [fm_core::FileEntry])` — free functions, used by Task 2.
- Consumes: nothing new.

- [ ] **Step 1: Write the failing tests**

At the end of `crates/app/src/file_list_model.rs` (after the existing `mod undo_journal_tests` block), add:

```rust

#[cfg(test)]
mod live_refresh_tests {
    use super::*;
    use std::path::PathBuf;
    use std::time::{Duration, SystemTime};

    fn entry(name: &str) -> fm_core::FileEntry {
        fm_core::FileEntry {
            name: name.to_string(),
            path: PathBuf::from(name),
            is_dir: false,
            size: 10,
            modified: SystemTime::UNIX_EPOCH,
            mime_type: "text/plain".to_string(),
            icon_key: "text".to_string(),
            permissions: "rw-r--r--".to_string(),
            thumbnail_path: None,
        }
    }

    #[test]
    fn metadata_is_unchanged_for_identical_entries() {
        assert!(!entry_metadata_changed(&entry("a"), &entry("a")));
    }

    #[test]
    fn metadata_change_detects_size_modified_permissions_and_mime() {
        let base = entry("a");

        let mut grown = entry("a");
        grown.size = 999;
        assert!(entry_metadata_changed(&base, &grown));

        let mut touched = entry("a");
        touched.modified = SystemTime::UNIX_EPOCH + Duration::from_secs(5);
        assert!(entry_metadata_changed(&base, &touched));

        let mut chmodded = entry("a");
        chmodded.permissions = "rwxr-xr-x".to_string();
        assert!(entry_metadata_changed(&base, &chmodded));

        let mut retyped = entry("a");
        retyped.mime_type = "application/pdf".to_string();
        assert!(entry_metadata_changed(&base, &retyped));
    }

    #[test]
    fn thumbnails_carry_over_when_name_kind_and_mtime_match() {
        let mut old_entry = entry("photo.jpg");
        old_entry.thumbnail_path = Some(PathBuf::from("/cache/thumb.png"));
        let old = vec![old_entry];
        let mut new = vec![entry("photo.jpg")];

        carry_over_thumbnails(&old, &mut new);
        assert_eq!(new[0].thumbnail_path, Some(PathBuf::from("/cache/thumb.png")));
    }

    #[test]
    fn thumbnails_do_not_carry_over_when_mtime_changed() {
        let mut old_entry = entry("photo.jpg");
        old_entry.thumbnail_path = Some(PathBuf::from("/cache/thumb.png"));
        let old = vec![old_entry];
        let mut fresh = entry("photo.jpg");
        fresh.modified = SystemTime::UNIX_EPOCH + Duration::from_secs(5);
        let mut new = vec![fresh];

        carry_over_thumbnails(&old, &mut new);
        assert_eq!(new[0].thumbnail_path, None);
    }

    #[test]
    fn carry_over_never_overwrites_an_already_resolved_thumbnail() {
        let mut old_entry = entry("photo.jpg");
        old_entry.thumbnail_path = Some(PathBuf::from("/cache/old.png"));
        let old = vec![old_entry];
        let mut fresh = entry("photo.jpg");
        fresh.thumbnail_path = Some(PathBuf::from("/cache/new.png"));
        let mut new = vec![fresh];

        carry_over_thumbnails(&old, &mut new);
        assert_eq!(new[0].thumbnail_path, Some(PathBuf::from("/cache/new.png")));
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cargo test -p fm-app live_refresh`
Expected: FAIL to compile — `entry_metadata_changed`/`carry_over_thumbnails` not found.

- [ ] **Step 3: Implement the helpers**

Find the `pluralize_items` function:

```rust
fn pluralize_items(count: usize) -> String {
    if count == 1 {
        "1 item".to_string()
    } else {
        format!("{count} items")
    }
}
```

Immediately after its closing `}`, add:

```rust

/// True when a re-listed entry's user-visible metadata differs from the
/// stored one. Callers already match on name+is_dir, so those aren't
/// compared here. icon_key is derived from mime_type, so comparing the
/// mime covers it.
fn entry_metadata_changed(old: &fm_core::FileEntry, new: &fm_core::FileEntry) -> bool {
    old.size != new.size
        || old.modified != new.modified
        || old.permissions != new.permissions
        || old.mime_type != new.mime_type
}

/// Carries already-resolved thumbnail paths from the previous listing onto
/// a fresh one, matched by (name, is_dir) with an unchanged mtime — a
/// fresh listing always starts with thumbnail_path: None, and dropping the
/// resolved paths on every refresh made each live refresh flicker every
/// visible thumbnail and re-probe the cache. A changed mtime means the old
/// thumbnail is stale, so it deliberately does not carry over.
fn carry_over_thumbnails(old: &[fm_core::FileEntry], new: &mut [fm_core::FileEntry]) {
    let old_thumbs: std::collections::HashMap<(&str, bool), (std::time::SystemTime, &PathBuf)> =
        old.iter()
            .filter_map(|e| {
                e.thumbnail_path
                    .as_ref()
                    .map(|t| ((e.name.as_str(), e.is_dir), (e.modified, t)))
            })
            .collect();
    for entry in new.iter_mut() {
        if entry.thumbnail_path.is_some() {
            continue;
        }
        if let Some((modified, thumb)) = old_thumbs.get(&(entry.name.as_str(), entry.is_dir)) {
            if *modified == entry.modified {
                entry.thumbnail_path = Some((*thumb).clone());
            }
        }
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cargo test -p fm-app`
Expected: all pass — the 12 pre-existing tests plus the 5 new `live_refresh_tests` (17 total). Unused-function warnings are expected until Task 2 wires the helpers in.

- [ ] **Step 5: Commit**

```bash
git add crates/app/src/file_list_model.rs
git commit -m "feat(app): add entry_metadata_changed and carry_over_thumbnails helpers"
```

---

### Task 2: Metadata-aware `apply_entries_diff`

**Files:**
- Modify: `crates/app/src/file_list_model.rs`

**Interfaces:**
- Consumes: `entry_metadata_changed`, `carry_over_thumbnails` (Task 1).
- Produces: no new names — `apply_entries_diff` behavior change only (externally changed size/mtime/permissions/mime now update their rows; thumbnails survive live refreshes).

- [ ] **Step 1: Make the parameter mutable and carry thumbnails over in the reset branch**

Find:

```rust
    fn apply_entries_diff(mut self: core::pin::Pin<&mut Self>, new_entries: Vec<fm_core::FileEntry>) {
        fn same_entry(a: &fm_core::FileEntry, b: &fm_core::FileEntry) -> bool {
            a.name == b.name && a.is_dir == b.is_dir
        }
```

Replace with:

```rust
    fn apply_entries_diff(mut self: core::pin::Pin<&mut Self>, mut new_entries: Vec<fm_core::FileEntry>) {
        fn same_entry(a: &fm_core::FileEntry, b: &fm_core::FileEntry) -> bool {
            a.name == b.name && a.is_dir == b.is_dir
        }

        // A fresh listing knows nothing about already-resolved thumbnails —
        // both update paths below would otherwise drop them all on every
        // refresh, which live watching turns from a rare annoyance into
        // visible flicker on each external change.
        carry_over_thumbnails(&self.entries, &mut new_entries);
```

- [ ] **Step 2: Add phase 3 to the row-diff path**

Find the end of the phase 2 loop (the last lines of `apply_entries_diff`):

```rust
        // Phase 2: insert rows that are new, left to right. After phase 1,
        // the model holds exactly the entries common to old and new, in the
        // same relative order as new_entries — so each new-only entry's
        // final index equals its index in new_entries.
        for (idx, new_entry) in new_entries.iter().enumerate() {
            let exists = self
                .entries
                .get(idx)
                .map(|e| same_entry(e, new_entry))
                .unwrap_or(false);
            if !exists {
                self.as_mut()
                    .begin_insert_rows(&parent, idx as i32, idx as i32);
                self.as_mut()
                    .rust_mut()
                    .entries
                    .insert(idx, new_entry.clone());
                self.as_mut().rust_mut().rebuild_displayed();
                self.as_mut().end_insert_rows();
            }
        }
    }
```

Replace with:

```rust
        // Phase 2: insert rows that are new, left to right. After phase 1,
        // the model holds exactly the entries common to old and new, in the
        // same relative order as new_entries — so each new-only entry's
        // final index equals its index in new_entries.
        for (idx, new_entry) in new_entries.iter().enumerate() {
            let exists = self
                .entries
                .get(idx)
                .map(|e| same_entry(e, new_entry))
                .unwrap_or(false);
            if !exists {
                self.as_mut()
                    .begin_insert_rows(&parent, idx as i32, idx as i32);
                self.as_mut()
                    .rust_mut()
                    .entries
                    .insert(idx, new_entry.clone());
                self.as_mut().rust_mut().rebuild_displayed();
                self.as_mut().end_insert_rows();
            }
        }

        // Phase 3: rows present in both listings — same_entry matches on
        // name+is_dir only, so an externally growing file (a download in
        // progress) never updated its size/modified columns before this.
        // Contents-only mutation: names, order, and count are untouched,
        // so `displayed` stays valid and only dataChanged is emitted.
        // carry_over_thumbnails above already re-attached still-valid
        // thumbnails to new_entries; an entry whose mtime changed keeps
        // thumbnail_path: None so its delegate re-requests a fresh one.
        for (idx, new_entry) in new_entries.iter().enumerate() {
            let Some(old_entry) = self.entries.get(idx) else {
                continue;
            };
            if !entry_metadata_changed(old_entry, new_entry) {
                continue;
            }
            let Some(row) = self.displayed.iter().position(|&i| i == idx) else {
                self.as_mut().rust_mut().entries[idx] = new_entry.clone();
                continue;
            };
            self.as_mut().rust_mut().entries[idx] = new_entry.clone();
            let model_index = self.model_index(row as i32, 0, &parent);
            self.as_mut().data_changed(
                &model_index,
                &model_index,
                &cxx_qt_lib::QList::<i32>::default(),
            );
        }
    }
```

- [ ] **Step 3: Build and test**

Run: `cargo build -p fm-app && cargo test -p fm-app`
Expected: build `Finished` with no errors; all 17 tests pass; Task 1's unused-function warnings are gone.

- [ ] **Step 4: Commit**

```bash
git add crates/app/src/file_list_model.rs
git commit -m "feat(app): metadata-aware diff with thumbnail carry-over"
```

---

### Task 3: Watcher lifecycle — `dir_watcher` field, drain task, `navigate()` hook, handoff

**Files:**
- Modify: `crates/app/src/file_list_model.rs`

**Interfaces:**
- Consumes: `fm_core::watcher::DirWatcher::new(&Path, tokio::sync::mpsc::UnboundedSender<WatchEvent>)` (exists), `refresh_entries_diff()` (exists), `runtime()` (exists).
- Produces: private `fn start_dir_watch(self: Pin<&mut Self>)`, called from `navigate()`.

- [ ] **Step 1: Add the `dir_watcher` field**

Find:

```rust
    /// Kept alive only for its Drop impl (stops the OS-level watch when
    /// the model is destroyed) — never read otherwise.
    theme_colors_watcher: Option<fm_core::watcher::DirWatcher>,
```

Replace with:

```rust
    /// Kept alive only for its Drop impl (stops the OS-level watch when
    /// the model is destroyed) — never read otherwise.
    theme_colors_watcher: Option<fm_core::watcher::DirWatcher>,
    /// Live watch on the current directory (see start_dir_watch). Replaced
    /// on every navigate(); kept for its Drop impl like the field above —
    /// dropping it also closes its event channel, which ends the drain
    /// task watching that directory.
    dir_watcher: Option<fm_core::watcher::DirWatcher>,
```

Then find (in `impl Default for FileListModelRust`):

```rust
            theme_colors_text: QString::from(""),
            theme_colors_watcher: None,
```

Replace with:

```rust
            theme_colors_text: QString::from(""),
            theme_colors_watcher: None,
            dir_watcher: None,
```

- [ ] **Step 2: Implement `start_dir_watch` and hook it into `navigate()`**

Find the end of `navigate()`:

```rust
        self.as_mut()
            .set_current_path(QString::from(&path_buf.display().to_string()));
        self.save_settings();

        let generation = {
```

Replace with:

```rust
        self.as_mut()
            .set_current_path(QString::from(&path_buf.display().to_string()));
        self.save_settings();
        self.as_mut().start_dir_watch();

        let generation = {
```

Then, immediately after `navigate()`'s closing `}` (the line after the `});` + `}` that end its spawn and the method), add:

```rust

    /// (Re)starts the live watch on the directory just navigated to.
    /// External creates/deletes/renames/modifications are debounced —
    /// flush after 250ms of quiet, but no later than 1s after a burst
    /// began, so a continuous writer can't starve refreshes — into
    /// refresh_entries_diff() calls, which already list in the background
    /// under the listing_generation stale-guard. Assigning the new watcher
    /// drops the previous one: its OS watch stops and its channel closes,
    /// which ends the previous drain task. Setup failure is non-fatal —
    /// the directory just doesn't live-update, exactly as before this
    /// feature existed.
    fn start_dir_watch(mut self: core::pin::Pin<&mut Self>) {
        let dir = PathBuf::from(self.current_path.to_string());

        let (tx, mut rx) = tokio::sync::mpsc::unbounded_channel();
        let watcher = match fm_core::watcher::DirWatcher::new(&dir, tx) {
            Ok(w) => w,
            Err(e) => {
                eprintln!("start_dir_watch failed for {}: {e}", dir.display());
                self.as_mut().rust_mut().dir_watcher = None;
                return;
            }
        };
        self.as_mut().rust_mut().dir_watcher = Some(watcher);

        let qt_thread = self.qt_thread();
        runtime().spawn(async move {
            loop {
                // First event of a burst; None means the watcher was
                // dropped (a navigate() replaced it) — exit.
                if rx.recv().await.is_none() {
                    return;
                }
                // Coalesce the rest of the burst per the debounce rule.
                let deadline =
                    tokio::time::Instant::now() + std::time::Duration::from_secs(1);
                loop {
                    let remaining =
                        deadline.saturating_duration_since(tokio::time::Instant::now());
                    let wait = std::time::Duration::from_millis(250).min(remaining);
                    if wait.is_zero() {
                        break; // 1s cap hit mid-burst: flush now
                    }
                    match tokio::time::timeout(wait, rx.recv()).await {
                        Err(_) => break,         // quiet period reached
                        Ok(Some(_)) => continue, // still bursting
                        Ok(None) => break,       // dropped mid-burst: flush once, exit next loop
                    }
                }
                let watched = dir.clone();
                let _ = qt_thread.queue(move |mut model| {
                    // A late burst from a directory the user already left
                    // is dropped here, before refresh_entries_diff's own
                    // generation guard even comes into play.
                    if PathBuf::from(model.current_path.to_string()) == watched {
                        model.as_mut().refresh_entries_diff();
                    }
                });
            }
        });
    }
```

- [ ] **Step 3: Build and test**

Run: `cargo build -p fm-app && cargo test -p fm-app`
Expected: build `Finished` with no errors; all 17 tests pass.

- [ ] **Step 4: Run the fm-core suite too (nothing should have changed)**

Run: `cargo test -p fm-core`
Expected: all suites `ok`, same counts as before this plan.

- [ ] **Step 5: Commit**

```bash
git add crates/app/src/file_list_model.rs
git commit -m "feat(app): live directory watching with debounced refresh"
```

- [ ] **Step 6: Hand off for manual verification**

Tell the user this is ready for interactive testing (do not launch the app yourself). Suggest concretely checking, with the app showing a test folder and a terminal beside it:

- `touch newfile` — the row appears within ~a quarter second.
- `rm newfile` — the row vanishes.
- `mkdir sub && mv sub sub2` — folder appears, then renames.
- `truncate -s 5M somefile` — its size column updates in place (no row flicker, scroll position untouched).
- `for i in $(seq 1 500); do touch f$i; done` — rows arrive in a few batched waves, not 500 individual updates, and the app stays responsive.
- Start a slow download (or `while true; do date >> log.txt; sleep 0.1; done`) — the folder keeps updating roughly once a second, not never.
- Navigate to another folder, then `touch` in the old one — nothing happens in the new view.
- A folder of photos: `touch` an unrelated file there — existing thumbnails do not flicker or reload.
- Delete the folder you're viewing from the terminal (`rm -rf`) — the view empties; navigating up still works; no crash.
