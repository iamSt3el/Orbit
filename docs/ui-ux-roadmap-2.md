# UI/UX Roadmap 2 — Round 3

> **Status (2026-07-07): items 1 + 4 + 5 (the "power navigation" slice)
> in progress, implemented directly without a spec/plan pair by request.**

Successor to `docs/ui-ux-roadmap.md` (all 26 items shipped). Same ground
rules: genuine M3 Expressive fidelity first, then speed; motion follows
the original design spec's split (`SpringAnimation` for component state
changes, `Easing.BezierCurve` pairs from `Motion.qml` for screen-level
transitions).

## Desktop-UX fundamentals

### 1. Editable path bar (Ctrl+L)

The PathBar's TextInput is wired only to search; there's no way to type
or paste a path and jump there. A third pill mode — edit — entered via
Ctrl+L or clicking empty space between the crumbs: current path
pre-filled and selected, Enter navigates, Tab completes directory
names, Esc cancels.

- Touches: `PathBar.qml`, `TopAppBar.qml`, `main.qml`, completion +
  validation invokables in the bridge, helpers in fm-core `paths`.

### 2. Archive support

No compress/extract anywhere. Right-click → "Compress to …", plus
"Extract here / Extract to…" on archive files, reusing the existing
transfer indicator and cancellation plumbing for progress. The biggest
remaining functional gap for a daily driver — fm-core feature first,
own spec.

### 3. Batch rename

RenameDialog is single-item. Pattern-based renamer over the selection
(find/replace, numbering, live old → new preview list), reachable from
the selection toolbar and context menu.

### 4. Tab ergonomics batch

Middle-click a folder opens it in a background tab; middle-click a tab
chip closes it; a file dragged onto a chip drops into that tab's
directory (chip as DropArea, same pattern as spring-loaded folders);
"Open in New Tab" in the folder context menu.

- Touches: `main.qml` tab strip, `FileListItem.qml`,
  `FileGridItem.qml`, `ItemContextMenu.qml`.

### 5. Session restore

Reopen last session's tabs, active tab, and window size on launch,
behind the existing resume-last-location setting. Extends
settings.json; listings stay async so instant startup is preserved.

- Touches: fm-core `settings`, bridge save/restore invokables,
  `main.qml` startup and close paths.

## Expressive / M3 polish

### 6. Search filter chips

Recursive search is name-only. A row of M3 filter chips under the
active search field — type (folders / images / documents), modified
(today / this week), size — with the filtering itself staying in Rust
per the design rule.

### 7. Richer drag ghost

Give main.qml's dragProxy a real M3 presentation: a small stack of the
top 2–3 item thumbnails with a count badge, springing to scale on lift.
All drags already route through the proxy, so this is one component's
visuals.

### 8. Container-transform preview

Opening the preview pane or Properties as an M3 container transform —
the tile visually expands into the pane/dialog. The flagship Expressive
transition the app doesn't have yet; the vendored shape-morphing
library is the tool for it.

## Accessibility

### 9. Accessible roles and names

Everything is hand-built from primitives, so screen readers currently
see almost nothing. Add `Accessible.role` / `Accessible.name` /
`Accessible.onPressAction` to Button, FileListItem, FileGridItem,
Sidebar entries, and the dialogs; check that Tab can reach the sidebar
and toolbar at all.

## Suggested order

**1 + 4 + 5** as the "power navigation" slice (in progress). **2** and
**3** each as their own spec'd feature (both fm-core-first). **6 + 7**
as an expressive-polish batch. **9** as a standalone pass. **8** as
opportunity allows.
