# Optimization Roadmap

Candidate performance work remaining after the 2026-07-04 audit pass
(commits `9162c8b`, `94a26b7`, `ab1943b` — displayed-row cache, async
navigate/refresh, linear diff, cached sort keys, bounded mime sniff,
off-thread transfer totals, thumbnail carry-over). Ranked by impact.
Each item should go through the usual spec → plan cycle before
implementation (see `docs/superpowers/`).

## High impact

### 1. Incremental first paint on huge directories

`gather_entries` (crates/app/src/file_list_model.rs) waits for the
complete listing before the model shows anything — a 100k-entry
directory stays blank until every entry is scanned and sorted. Stream
the first batch (~1–2k entries) into the model quickly and append the
rest in chunks.

- Why it matters: the single biggest remaining perceived-speed win;
  "instant" first paint on giant folders is where Nautilus/Dolphin get
  their reputation.
- Cost/risk: the hardest item. Batched inserts must respect the active
  sort and the `displayed`/`listing_generation` invariants documented
  at the top of `FileListModelRust`. Needs its own spec.
- Pairs with items 2 and 4.

### 2. One `spawn_blocking` for the whole listing

`fm_core::listing::list_directory` uses `tokio::fs::read_dir` plus a
per-entry async `metadata()` — every `metadata()` call is its own
blocking-pool round-trip, so a 100k-file listing pays ~100k thread-pool
handoffs. Do the entire scan with `std::fs` inside a single
`spawn_blocking`, keeping the existing channel interface.

- Why it matters: typically cuts large-directory listing time several
  times over.
- Cost/risk: contained change in `crates/core/src/listing.rs`; existing
  fm-core listing tests cover behavior.

### 3. Release profile tuning

Workspace `Cargo.toml` has no `[profile.release]` section, so release
builds use defaults (16 codegen units, no LTO). Add:

```toml
[profile.release]
lto = "thin"
codegen-units = 1
opt-level = 3
```

- Why it matters: free, across-the-board performance.
- Note: any speed comparison against other file managers must use a
  release build — the dev profile only optimizes the image-decoding
  crates (see the `[profile.dev.package.*]` entries).

## Medium impact

### 4. Precompute `data()` role strings

Every `data()` call for the modified column runs ISO-8601 formatting
through the `time` crate (`format_modified`), and the thumbnail role
rebuilds a `file://` string — per role, per row, on every delegate bind
while scrolling. Format `modified` once per entry at listing time and
cache the string alongside the entry.

- Why it matters: removes the last per-frame allocation hot spot in the
  scroll path.
- Cost/risk: small; either a parallel Vec in the model or an extra
  field populated in fm-core's listing.

### 5. Async Properties dialog stats

`folderSize` still walks the whole tree synchronously on the UI thread
(the code comment admits the stall); `folderItemCount` is a smaller
sync read. Compute in the background and deliver via a
`folderSizeReady`-style signal; the dialog shows "Calculating…"
meanwhile.

- Why it matters: fixes the one remaining deliberate UI freeze.
- Cost/risk: small Rust change plus a small QML change in
  `PropertiesDialog.qml`.

### 6. Faster thumbnail decode

Two independent levels:

1. Scale the decode semaphore (currently fixed at 2 permits in
   `thumbnail_semaphore()`) with `std::thread::available_parallelism`,
   capped (e.g. at 4) to keep peak decode memory bounded.
2. Downscale-during-decode in `fm_core::thumbnails` instead of decoding
   full resolution and then shrinking — slashes both CPU and the peak
   memory that motivated the semaphore in the first place.

- Why it matters: first visit to a large photo folder.
- Cost/risk: (1) is trivial; (2) is a bigger `thumbnails.rs` change and
  needs care to keep freedesktop-spec cache output identical.

## Small / polish

### 7. Rubber-band selection chatter

Drag-select in `main.qml` calls `fileModel.setSelected(...)` per
delegate per mouse-move; each call crosses the QML↔Rust bridge and does
an O(n) `notify_row_for_name` scan. Batch to one invokable per
mouse-move carrying the names whose selection state flips.

- Why it matters: smoother rubber-banding over large visible ranges
  (mainly big grids). Profile before bothering.

### 8. Name→index map for row lookups

`notify_row_for_name`, `open_selected_entry`, and the phase-3 metadata
walk scan `entries` linearly by name. A `HashMap<String, usize>`
maintained alongside `displayed` makes selection toggles O(1).

- Why it matters: only at very large entry counts combined with heavy
  selection traffic.
- Cost/risk: adds another cache invariant to maintain (see the model
  invariants note) — do it only if profiling item 7 shows the scans
  matter.

## Suggested order

Items **2 + 3** first (an afternoon, low risk, measurable). Then item
**1** as its own spec'd feature — it touches the model invariants —
with item **4** folded into it. Items 5–8 as opportunity allows.
