#[cxx_qt::bridge]
pub mod qobject {
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
        include!("cxx-qt-lib/qvariant.h");
        type QVariant = cxx_qt_lib::QVariant;
        include!("cxx-qt-lib/qmodelindex.h");
        type QModelIndex = cxx_qt_lib::QModelIndex;
        include!("cxx-qt-lib/qhash.h");
        type QHash_i32_QByteArray = cxx_qt_lib::QHash<cxx_qt_lib::QHashPair_i32_QByteArray>;
        include!("cxx-qt-lib/qbytearray.h");
        type QByteArray = cxx_qt_lib::QByteArray;
        include!("cxx-qt-lib/core/qlist/qlist_i32.h");
        type QList_i32 = cxx_qt_lib::QList<i32>;
    }

    unsafe extern "C++" {
        include!(<QtCore/QAbstractListModel>);
        type QAbstractListModel;
    }

    extern "RustQt" {
        #[qobject]
        #[qml_element]
        #[base = QAbstractListModel]
        #[qproperty(QString, current_path, cxx_name = "currentPath")]
        #[qproperty(QString, home_path, cxx_name = "homePath")]
        #[qproperty(QString, downloads_path, cxx_name = "downloadsPath")]
        #[qproperty(QString, documents_path, cxx_name = "documentsPath")]
        #[qproperty(QString, trash_path, cxx_name = "trashPath")]
        #[qproperty(QString, theme_colors_path, cxx_name = "themeColorsPath")]
        // Live contents of themeColorsPath's file, kept current by a
        // background watcher (see start_theme_colors_watch()) — QML binds
        // Color.applyCustomColors to this reactively instead of only
        // reading it once at startup, so editing colors.json on disk
        // reapplies the theme without needing the "Reload theme colors"
        // Settings action.
        #[qproperty(QString, theme_colors_text, cxx_name = "themeColorsText")]
        #[qproperty(QString, view_mode, cxx_name = "viewMode")]
        #[qproperty(QString, icon_size_level, cxx_name = "iconSizeLevel")]
        #[qproperty(QString, saved_last_path, cxx_name = "savedLastPath")]
        #[qproperty(bool, resume_last_path, cxx_name = "resumeLastPath")]
        #[qproperty(QString, app_config_dir, cxx_name = "appConfigDir")]
        #[qproperty(bool, is_busy, cxx_name = "isBusy")]
        #[qproperty(QString, busy_label, cxx_name = "busyLabel")]
        #[qproperty(i64, transfer_done_bytes, cxx_name = "transferDoneBytes")]
        #[qproperty(i64, transfer_total_bytes, cxx_name = "transferTotalBytes")]
        #[qproperty(QString, transfer_speed_label, cxx_name = "transferSpeedLabel")]
        type FileListModel = super::FileListModelRust;
    }

    // Lets background threads (spawned for copy/move so they don't block
    // the UI) safely queue updates back onto the Qt thread when done — see
    // paste_entry().
    impl cxx_qt::Threading for FileListModel {}

    unsafe extern "RustQt" {
        #[qinvokable]
        #[cxx_override]
        #[cxx_name = "rowCount"]
        fn row_count(self: &FileListModel, _parent: &QModelIndex) -> i32;

        #[qinvokable]
        #[cxx_override]
        fn data(self: &FileListModel, index: &QModelIndex, role: i32) -> QVariant;

        #[qinvokable]
        #[cxx_override]
        #[cxx_name = "roleNames"]
        fn role_names(self: &FileListModel) -> QHash_i32_QByteArray;
    }

    unsafe extern "RustQt" {
        #[inherit]
        #[cxx_name = "beginResetModel"]
        fn begin_reset_model(self: Pin<&mut FileListModel>);

        #[inherit]
        #[cxx_name = "endResetModel"]
        fn end_reset_model(self: Pin<&mut FileListModel>);

        #[inherit]
        #[cxx_name = "beginInsertRows"]
        fn begin_insert_rows(self: Pin<&mut FileListModel>, parent: &QModelIndex, first: i32, last: i32);

        #[inherit]
        #[cxx_name = "endInsertRows"]
        fn end_insert_rows(self: Pin<&mut FileListModel>);

        #[inherit]
        #[cxx_name = "beginRemoveRows"]
        fn begin_remove_rows(self: Pin<&mut FileListModel>, parent: &QModelIndex, first: i32, last: i32);

        #[inherit]
        #[cxx_name = "endRemoveRows"]
        fn end_remove_rows(self: Pin<&mut FileListModel>);

        #[inherit]
        #[cxx_name = "index"]
        fn model_index(
            self: &FileListModel,
            row: i32,
            column: i32,
            parent: &QModelIndex,
        ) -> QModelIndex;

        #[inherit]
        #[cxx_name = "dataChanged"]
        fn data_changed(
            self: Pin<&mut FileListModel>,
            top_left: &QModelIndex,
            bottom_right: &QModelIndex,
            roles: &QList_i32,
        );
    }

    unsafe extern "RustQt" {
        #[qinvokable]
        fn navigate(self: Pin<&mut FileListModel>, path: &QString);
    }

    unsafe extern "RustQt" {
        #[qinvokable]
        #[cxx_name = "setSelected"]
        fn set_selected(self: Pin<&mut FileListModel>, name: &QString, selected: bool);

        #[qinvokable]
        #[cxx_name = "selectRange"]
        fn select_range(self: Pin<&mut FileListModel>, from_name: &QString, to_name: &QString);

        #[qinvokable]
        #[cxx_name = "selectAll"]
        fn select_all(self: Pin<&mut FileListModel>);

        #[qinvokable]
        #[cxx_name = "clearSelection"]
        fn clear_selection(self: Pin<&mut FileListModel>);

        #[qinvokable]
        #[cxx_name = "selectedCount"]
        fn selected_count(self: &FileListModel) -> i32;

        #[qinvokable]
        #[cxx_name = "singleSelectedName"]
        fn single_selected_name(self: &FileListModel) -> QString;

        #[qinvokable]
        #[cxx_name = "selectedNamesJoined"]
        fn selected_names_joined(self: &FileListModel) -> QString;

        #[qinvokable]
        #[cxx_name = "openSelectedEntry"]
        fn open_selected_entry(self: Pin<&mut FileListModel>);
    }

    unsafe extern "RustQt" {
        #[qinvokable]
        #[cxx_name = "createFolder"]
        fn create_folder(self: Pin<&mut FileListModel>, name: &QString);

        #[qinvokable]
        #[cxx_name = "renameEntry"]
        fn rename_entry(self: Pin<&mut FileListModel>, old_name: &QString, new_name: &QString);

        #[qinvokable]
        #[cxx_name = "deleteEntry"]
        fn delete_entry(self: Pin<&mut FileListModel>, name: &QString);

        /// Moves every currently-selected entry to Trash. Unlike
        /// deleteEntry (synchronous — fine for one item), this runs as a
        /// background task so trashing a large selection doesn't hitch the
        /// UI thread, using the same isBusy/busyLabel indicator pasteEntry
        /// already exposes (no byte-progress — Trash moves are fast enough
        /// that a spinner is enough).
        #[qinvokable]
        #[cxx_name = "deleteSelection"]
        fn delete_selection(self: Pin<&mut FileListModel>);

        /// Permanently removes everything in the freedesktop Trash (files
        /// and their .trashinfo sidecars) — not a move-to-trash, so this
        /// one has no recovery path. Refreshes the listing afterward when
        /// currently browsing the Trash folder itself.
        #[qinvokable]
        #[cxx_name = "emptyTrash"]
        fn empty_trash(self: Pin<&mut FileListModel>);

        #[qinvokable]
        #[cxx_name = "openEntry"]
        fn open_entry(self: Pin<&mut FileListModel>, name: &QString);

        #[qinvokable]
        #[cxx_name = "duplicateEntry"]
        fn duplicate_entry(self: Pin<&mut FileListModel>, name: &QString);

        /// Multi-item counterpart to duplicateEntry — same background-task
        /// pattern as deleteSelection.
        #[qinvokable]
        #[cxx_name = "duplicateSelection"]
        fn duplicate_selection(self: Pin<&mut FileListModel>);

        #[qinvokable]
        #[cxx_name = "restoreEntry"]
        fn restore_entry(self: Pin<&mut FileListModel>, name: &QString);

        /// Multi-item counterpart to restoreEntry — same background-task
        /// pattern as deleteSelection.
        #[qinvokable]
        #[cxx_name = "restoreSelection"]
        fn restore_selection(self: Pin<&mut FileListModel>);

        #[qinvokable]
        #[cxx_name = "deletePermanentlyEntry"]
        fn delete_permanently_entry(self: Pin<&mut FileListModel>, name: &QString);

        /// Multi-item counterpart to deletePermanentlyEntry — same
        /// background-task pattern as deleteSelection.
        #[qinvokable]
        #[cxx_name = "deletePermanentlySelection"]
        fn delete_permanently_selection(self: Pin<&mut FileListModel>);

        #[qinvokable]
        #[cxx_name = "openTerminalHere"]
        fn open_terminal_here(self: Pin<&mut FileListModel>);

        #[qinvokable]
        #[cxx_name = "copyEntry"]
        fn copy_entry(self: Pin<&mut FileListModel>, name: &QString);

        #[qinvokable]
        #[cxx_name = "cutEntry"]
        fn cut_entry(self: Pin<&mut FileListModel>, name: &QString);

        /// Snapshots every currently-selected name into the clipboard, for
        /// pasting elsewhere — the multi-item counterpart to copyEntry.
        #[qinvokable]
        #[cxx_name = "copySelection"]
        fn copy_selection(self: Pin<&mut FileListModel>);

        /// Multi-item counterpart to cutEntry.
        #[qinvokable]
        #[cxx_name = "cutSelection"]
        fn cut_selection(self: Pin<&mut FileListModel>);

        #[qinvokable]
        #[cxx_name = "canPaste"]
        fn can_paste(self: &FileListModel) -> bool;

        /// Copies or moves the clipboard entry into the current folder.
        /// Runs the actual file I/O on a background task (via the shared
        /// multi-thread runtime) instead of blocking the Qt UI thread —
        /// isBusy/busyLabel flip on immediately and the model refreshes
        /// once the background task reports back through qt_thread().
        #[qinvokable]
        #[cxx_name = "pasteEntry"]
        fn paste_entry(self: Pin<&mut FileListModel>);

        /// Copies or moves an explicit list of absolute source paths into
        /// destDir — the drag-and-drop counterpart to pasteEntry, sharing
        /// its batch transfer machinery. `paths` is newline-joined (QML
        /// builds this from drop.urls, stripping each file:// prefix
        /// itself before joining, since this file never parses URIs).
        #[qinvokable]
        #[cxx_name = "dropPaths"]
        fn drop_paths(self: Pin<&mut FileListModel>, paths: &QString, dest_dir: &QString, is_move: bool);

        /// Reverts the most recent undoable operation (Ctrl+Z), fail-safe:
        /// entries whose files changed externally since are skipped and
        /// reported, never overwritten. No-op while isBusy.
        #[qinvokable]
        #[cxx_name = "undo"]
        fn undo(self: Pin<&mut FileListModel>);

        /// Re-applies the most recently undone operation (Ctrl+Shift+Z).
        /// Same fail-safe rules as undo. No-op while isBusy.
        #[qinvokable]
        #[cxx_name = "redo"]
        fn redo(self: Pin<&mut FileListModel>);

        /// Kicks off background thumbnail generation/lookup for one entry —
        /// called from FileListItem/FileGridItem when a delegate holding an
        /// image becomes visible, not eagerly for the whole folder, so a
        /// directory with thousands of photos doesn't decode all of them at
        /// once. No-ops if a thumbnail is already known or already pending.
        #[qinvokable]
        #[cxx_name = "requestThumbnail"]
        fn request_thumbnail(self: Pin<&mut FileListModel>, name: &QString);
    }

    unsafe extern "RustQt" {
        /// Emitted whenever a user-triggered file operation fails, carrying
        /// a short user-facing message. QML listens via
        /// `Connections { target: fileModel; function onErrorOccurred(message) { ... } }`.
        #[qsignal]
        #[cxx_name = "errorOccurred"]
        fn error_occurred(self: Pin<&mut FileListModel>, message: QString);

        /// Emitted after every successful undoable operation ("Moved 3
        /// items", canUndo: true — QML shows a snackbar with an Undo
        /// action) and after an undo/redo completes ("Undid: Moved 3
        /// items", canUndo: false — plain confirmation, no button).
        #[qsignal]
        #[cxx_name = "operationCompleted"]
        fn operation_completed(self: Pin<&mut FileListModel>, description: QString, can_undo: bool);
    }

    unsafe extern "RustQt" {
        #[qinvokable]
        #[cxx_name = "entryAbsolutePath"]
        fn entry_absolute_path(self: &FileListModel, name: &QString) -> QString;

        #[qinvokable]
        #[cxx_name = "folderItemCount"]
        fn folder_item_count(self: &FileListModel, name: &QString) -> i32;

        #[qinvokable]
        #[cxx_name = "folderSize"]
        fn folder_size(self: &FileListModel, name: &QString) -> i64;

        #[qinvokable]
        #[cxx_name = "readThemeColorsFile"]
        fn read_theme_colors_file(self: &FileListModel) -> QString;

        #[qinvokable]
        #[cxx_name = "saveSettings"]
        fn save_settings(self: &FileListModel);

        /// Populates themeColorsText immediately with the file's current
        /// contents (if any) and starts a background watch on its parent
        /// directory (not the file itself — editors commonly replace a
        /// file via a temp-file-then-rename swap, which a watch on the
        /// file's own inode would miss) so themeColorsText updates
        /// automatically whenever colors.json changes on disk. Call once,
        /// after the model exists — same reasoning as
        /// readThemeColorsFile's doc comment.
        #[qinvokable]
        #[cxx_name = "startThemeColorsWatch"]
        fn start_theme_colors_watch(self: Pin<&mut FileListModel>);

        // show_hidden/sort_key/sort_ascending aren't qproperties (their
        // setters already exist as setShowHidden/setSortKey/
        // setSortAscending, which do a model reset a plain qproperty
        // setter can't) — these are read-only getters so QML can still
        // show the actual current value, e.g. to initialize
        // ViewOptionsMenu's display state after a restart instead of
        // always starting from hardcoded defaults.
        #[qinvokable]
        #[cxx_name = "isShowHidden"]
        fn is_show_hidden(self: &FileListModel) -> bool;

        #[qinvokable]
        #[cxx_name = "currentSortKey"]
        fn current_sort_key(self: &FileListModel) -> QString;

        #[qinvokable]
        #[cxx_name = "isSortAscending"]
        fn is_sort_ascending(self: &FileListModel) -> bool;
    }

    unsafe extern "RustQt" {
        #[qinvokable]
        #[cxx_name = "setSearchQuery"]
        fn set_search_query(self: Pin<&mut FileListModel>, query: &QString);

        #[qinvokable]
        #[cxx_name = "setShowHidden"]
        fn set_show_hidden(self: Pin<&mut FileListModel>, show_hidden: bool);

        #[qinvokable]
        #[cxx_name = "setSortKey"]
        fn set_sort_key(self: Pin<&mut FileListModel>, sort_key: &QString);

        #[qinvokable]
        #[cxx_name = "setSortAscending"]
        fn set_sort_ascending(self: Pin<&mut FileListModel>, ascending: bool);
    }
}

use cxx_qt::CxxQtType;
use cxx_qt::Threading;
use cxx_qt_lib::{QByteArray, QHash, QHashPair_i32_QByteArray, QString, QVariant};
use std::path::PathBuf;
use std::sync::OnceLock;

// One Tokio runtime shared across all invokables, instead of building and
// tearing one down on every call. Multi-thread (not current-thread): most
// invokables still just runtime().block_on(...) synchronously on the Qt
// thread, which works fine either way, but paste_entry() needs a runtime
// with its own worker threads so runtime().spawn(...) actually makes
// progress in the background instead of sitting queued until some other
// call happens to drive the runtime.
fn runtime() -> &'static tokio::runtime::Runtime {
    static RUNTIME: OnceLock<tokio::runtime::Runtime> = OnceLock::new();
    RUNTIME.get_or_init(|| {
        tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()
            .expect("failed to create Tokio runtime")
    })
}

// Caps how many thumbnails can be decoded at once, process-wide. Without
// this, opening a folder full of photos fires off a requestThumbnail() for
// every delegate the grid/list instantiates up front (visible area plus
// cacheBuffer) nearly simultaneously — each one fully decodes its source
// image at native resolution before shrinking it, so e.g. 60 delegates on a
// folder of 20-30MP photos meant 60 full-resolution decode buffers (tens of
// MB each) alive in memory at once, easily reaching 1GB+. A small permit
// count keeps peak memory bounded to a few decodes' worth regardless of how
// many rows ask at once; the rest simply wait their turn.
fn thumbnail_semaphore() -> &'static tokio::sync::Semaphore {
    static SEMAPHORE: OnceLock<tokio::sync::Semaphore> = OnceLock::new();
    SEMAPHORE.get_or_init(|| tokio::sync::Semaphore::new(2))
}

pub struct FileListModelRust {
    entries: Vec<fm_core::FileEntry>,
    search_query: QString,
    show_hidden: bool,
    sort_key: QString,
    sort_ascending: bool,
    current_path: QString,
    home_path: QString,
    downloads_path: QString,
    documents_path: QString,
    trash_path: QString,
    theme_colors_path: QString,
    theme_colors_text: QString,
    /// Kept alive only for its Drop impl (stops the OS-level watch when
    /// the model is destroyed) — never read otherwise.
    theme_colors_watcher: Option<fm_core::watcher::DirWatcher>,
    view_mode: QString,
    icon_size_level: QString,
    saved_last_path: QString,
    resume_last_path: bool,
    app_config_dir: QString,
    is_busy: bool,
    busy_label: QString,
    transfer_done_bytes: i64,
    transfer_total_bytes: i64,
    transfer_speed_label: QString,
    clipboard_paths: Vec<PathBuf>,
    clipboard_is_cut: bool,
    /// Names currently selected in the view (Ctrl/Shift/drag-select) —
    /// scoped to the current folder's listing. Cleared on navigate() and
    /// pruned automatically in apply_entries_diff() whenever a selected
    /// name disappears from the listing.
    selected: std::collections::HashSet<String>,
    /// Source paths currently being thumbnailed on a background task —
    /// guards against re-spawning a duplicate task for the same entry if a
    /// delegate re-requests it (e.g. scrolling it out and back into view)
    /// before the first request has finished.
    pending_thumbnails: std::collections::HashSet<PathBuf>,
    /// Session-only undo/redo history of this app's own file operations.
    journal: UndoJournal,
    /// Cache of the displayed-row → `entries`-index mapping under the
    /// active search/hidden-file filter. row_count()/data() used to
    /// recompute this with a full O(n) scan (plus a QString conversion and
    /// per-entry lowercasing) on EVERY call — and Qt calls data() once per
    /// role per row, so scrolling a big directory paid that scan hundreds
    /// of times per frame. Rebuilt via rebuild_displayed() after every
    /// mutation of `entries`, `search_query`, or `show_hidden`.
    displayed: Vec<usize>,
    /// Bumped by every navigate()/refresh spawn; a background listing only
    /// applies its result if the generation still matches, so a slow
    /// listing that finishes after the user already navigated elsewhere
    /// (or a newer refresh superseded it) is discarded instead of
    /// clobbering the newer state.
    listing_generation: u64,
}

fn path_or_empty(path: Option<PathBuf>) -> QString {
    QString::from(&path.map(|p| p.display().to_string()).unwrap_or_default())
}

impl Default for FileListModelRust {
    fn default() -> Self {
        // Best-effort: create the app's config directory up front so an
        // external tool (e.g. a wallpaper-based color generator) has
        // somewhere to write a colors.json into without needing its own
        // mkdir logic. Not fatal if this fails or the dir already exists.
        if let Some(dir) = fm_core::paths::app_config_dir() {
            let _ = std::fs::create_dir_all(dir);
        }

        // Restores view mode, sort order, icon size, hidden-file
        // visibility, and the last visited folder from a previous run.
        // Settings::load() falls back to sensible defaults on its own if
        // the file is missing or invalid, so this is always safe to use.
        let settings = fm_core::settings::Settings::load();

        Self {
            entries: Vec::new(),
            search_query: QString::from(""),
            show_hidden: settings.show_hidden,
            sort_key: QString::from(&settings.sort_key),
            sort_ascending: settings.sort_ascending,
            current_path: QString::from(""),
            home_path: path_or_empty(fm_core::paths::home_dir()),
            downloads_path: path_or_empty(fm_core::paths::download_dir()),
            documents_path: path_or_empty(fm_core::paths::document_dir()),
            trash_path: path_or_empty(fm_core::paths::trash_dir()),
            theme_colors_path: path_or_empty(fm_core::paths::theme_colors_path()),
            theme_colors_text: QString::from(""),
            theme_colors_watcher: None,
            view_mode: QString::from(&settings.view_mode),
            icon_size_level: QString::from(&settings.icon_size_level),
            saved_last_path: QString::from(&settings.last_path),
            resume_last_path: settings.resume_last_path,
            app_config_dir: path_or_empty(fm_core::paths::app_config_dir()),
            is_busy: false,
            busy_label: QString::from(""),
            transfer_done_bytes: 0,
            transfer_total_bytes: 0,
            transfer_speed_label: QString::from(""),
            clipboard_paths: Vec::new(),
            clipboard_is_cut: false,
            selected: std::collections::HashSet::new(),
            pending_thumbnails: std::collections::HashSet::new(),
            journal: UndoJournal::default(),
            displayed: Vec::new(),
            listing_generation: 0,
        }
    }
}

impl FileListModelRust {
    /// Recomputes the `displayed` cache. Must run after every mutation of
    /// `entries`, `search_query`, or `show_hidden` (and before the
    /// matching end_reset/end_insert/end_remove call, so the view's
    /// follow-up row_count()/data() queries see a consistent mapping).
    fn rebuild_displayed(&mut self) {
        self.displayed = matching_indices(
            &self.entries,
            &self.search_query.to_string(),
            self.show_hidden,
        );
    }
}

const NAME_ROLE: i32 = 0x0100;
const IS_DIR_ROLE: i32 = 0x0101;
const SIZE_ROLE: i32 = 0x0102;
const ICON_KEY_ROLE: i32 = 0x0103;
const MODIFIED_ROLE: i32 = 0x0104;
const MIME_TYPE_ROLE: i32 = 0x0105;
const PERMISSIONS_ROLE: i32 = 0x0106;
const THUMBNAIL_PATH_ROLE: i32 = 0x0107;
const SELECTED_ROLE: i32 = 0x0108;

fn format_modified(modified: std::time::SystemTime) -> String {
    use time::format_description::well_known::Iso8601;
    use time::OffsetDateTime;

    OffsetDateTime::from(modified)
        .format(&Iso8601::DEFAULT)
        .unwrap_or_default()
}

async fn gather_entries(path: &std::path::Path) -> Vec<fm_core::FileEntry> {
    let mut rx = fm_core::listing::list_directory(path.to_path_buf());
    let mut entries = Vec::new();
    while let Some(result) = rx.recv().await {
        if let Ok(entry) = result {
            entries.push(entry);
        }
    }
    entries
}

/// Folders always sort before files, regardless of the chosen key — only
/// the secondary ordering (and its direction) is user-configurable.
/// sort_by_cached_key computes each entry's key exactly once — the old
/// comparator allocated two fresh lowercased names on every comparison,
/// which is O(n log n) allocations on a big directory.
fn sort_entries(entries: &mut [fm_core::FileEntry], sort_key: &str, ascending: bool) {
    #[derive(PartialEq, Eq, PartialOrd, Ord)]
    enum Key {
        Name(String),
        Size(u64),
        Modified(std::time::SystemTime),
        Type(String),
    }
    let key_for = |e: &fm_core::FileEntry| match sort_key {
        "size" => Key::Size(e.size),
        "modified" => Key::Modified(e.modified),
        "type" => Key::Type(e.mime_type.clone()),
        _ => Key::Name(e.name.to_lowercase()),
    };
    // `descending` only reverses the secondary key — the leading
    // !is_dir keeps folders grouped first in both directions.
    if ascending {
        entries.sort_by_cached_key(|e| (!e.is_dir, key_for(e)));
    } else {
        entries.sort_by_cached_key(|e| (!e.is_dir, std::cmp::Reverse(key_for(e))));
    }
}

/// Indices into `entries` matching the current search query and hidden-file
/// setting (all of them, in order, when nothing is filtered). Computed once
/// per mutation into the `displayed` cache (see rebuild_displayed) — never
/// on demand from data()/row_count(), which Qt calls once per role per row.
fn matching_indices(entries: &[fm_core::FileEntry], query: &str, show_hidden: bool) -> Vec<usize> {
    let query = query.to_lowercase();
    entries
        .iter()
        .enumerate()
        .filter(|(_, e)| show_hidden || !e.name.starts_with('.'))
        .filter(|(_, e)| query.is_empty() || e.name.to_lowercase().contains(&query))
        .map(|(i, _)| i)
        .collect()
}

impl qobject::FileListModel {
    fn row_count(&self, _parent: &cxx_qt_lib::QModelIndex) -> i32 {
        self.displayed.len() as i32
    }

    fn data(&self, index: &cxx_qt_lib::QModelIndex, role: i32) -> QVariant {
        let row = index.row();
        if row < 0 || row as usize >= self.displayed.len() {
            return QVariant::default();
        }
        let entry = &self.entries[self.displayed[row as usize]];
        match role {
            NAME_ROLE => QVariant::from(&QString::from(&entry.name)),
            IS_DIR_ROLE => QVariant::from(&entry.is_dir),
            SIZE_ROLE => QVariant::from(&(entry.size as i64)),
            ICON_KEY_ROLE => QVariant::from(&QString::from(&entry.icon_key)),
            MODIFIED_ROLE => QVariant::from(&QString::from(&format_modified(entry.modified))),
            MIME_TYPE_ROLE => QVariant::from(&QString::from(&entry.mime_type)),
            PERMISSIONS_ROLE => QVariant::from(&QString::from(&entry.permissions)),
            THUMBNAIL_PATH_ROLE => QVariant::from(&QString::from(
                &entry
                    .thumbnail_path
                    .as_ref()
                    .map(|p| format!("file://{}", p.display()))
                    .unwrap_or_default(),
            )),
            SELECTED_ROLE => QVariant::from(&self.selected.contains(&entry.name)),
            _ => QVariant::default(),
        }
    }

    fn role_names(&self) -> QHash<QHashPair_i32_QByteArray> {
        let mut roles = QHash::<QHashPair_i32_QByteArray>::default();
        roles.insert(NAME_ROLE, QByteArray::from("name"));
        roles.insert(IS_DIR_ROLE, QByteArray::from("isDir"));
        roles.insert(SIZE_ROLE, QByteArray::from("size"));
        roles.insert(ICON_KEY_ROLE, QByteArray::from("iconKey"));
        roles.insert(MODIFIED_ROLE, QByteArray::from("modified"));
        roles.insert(MIME_TYPE_ROLE, QByteArray::from("mimeType"));
        roles.insert(PERMISSIONS_ROLE, QByteArray::from("permissions"));
        roles.insert(THUMBNAIL_PATH_ROLE, QByteArray::from("thumbnailPath"));
        roles.insert(SELECTED_ROLE, QByteArray::from("selected"));
        roles
    }

    /// Emits `dataChanged` for the single row matching `name`, if it's
    /// currently visible under the active search/hidden-file filter — used
    /// by `set_selected` so toggling one row's selection doesn't touch any
    /// other row's bindings.
    fn notify_row_for_name(mut self: core::pin::Pin<&mut Self>, name: &str) {
        let Some(idx) = self.entries.iter().position(|e| e.name == name) else {
            return;
        };
        let Some(row) = self.displayed.iter().position(|&i| i == idx) else {
            return;
        };
        let parent = cxx_qt_lib::QModelIndex::default();
        let model_index = self.model_index(row as i32, 0, &parent);
        self.as_mut()
            .data_changed(&model_index, &model_index, &cxx_qt_lib::QList::<i32>::default());
    }

    fn set_selected(mut self: core::pin::Pin<&mut Self>, name: &QString, selected: bool) {
        let name = name.to_string();
        let changed = if selected {
            self.as_mut().rust_mut().selected.insert(name.clone())
        } else {
            self.as_mut().rust_mut().selected.remove(&name)
        };
        if changed {
            self.as_mut().notify_row_for_name(&name);
        }
    }

    fn select_range(mut self: core::pin::Pin<&mut Self>, from_name: &QString, to_name: &QString) {
        let displayed: Vec<&fm_core::FileEntry> =
            self.displayed.iter().map(|&i| &self.entries[i]).collect();
        let names = resolve_range_names(&displayed, &from_name.to_string(), &to_name.to_string());
        let row_count = displayed.len();
        if names.is_empty() {
            return;
        }
        self.as_mut().rust_mut().selected = names.into_iter().collect();

        if row_count == 0 {
            return;
        }
        let parent = cxx_qt_lib::QModelIndex::default();
        let first = self.model_index(0, 0, &parent);
        let last = self.model_index((row_count - 1) as i32, 0, &parent);
        self.as_mut()
            .data_changed(&first, &last, &cxx_qt_lib::QList::<i32>::default());
    }

    fn select_all(mut self: core::pin::Pin<&mut Self>) {
        let names: std::collections::HashSet<String> = self
            .displayed
            .iter()
            .map(|&i| self.entries[i].name.clone())
            .collect();
        let row_count = self.displayed.len();
        self.as_mut().rust_mut().selected = names;
        if row_count == 0 {
            return;
        }
        let parent = cxx_qt_lib::QModelIndex::default();
        let first = self.model_index(0, 0, &parent);
        let last = self.model_index((row_count - 1) as i32, 0, &parent);
        self.as_mut()
            .data_changed(&first, &last, &cxx_qt_lib::QList::<i32>::default());
    }

    fn clear_selection(mut self: core::pin::Pin<&mut Self>) {
        if self.selected.is_empty() {
            return;
        }
        let row_count = self.row_count(&cxx_qt_lib::QModelIndex::default());
        self.as_mut().rust_mut().selected.clear();
        if row_count == 0 {
            return;
        }
        let parent = cxx_qt_lib::QModelIndex::default();
        let first = self.model_index(0, 0, &parent);
        let last = self.model_index(row_count - 1, 0, &parent);
        self.as_mut()
            .data_changed(&first, &last, &cxx_qt_lib::QList::<i32>::default());
    }

    fn selected_count(&self) -> i32 {
        self.selected.len() as i32
    }

    fn single_selected_name(&self) -> QString {
        if self.selected.len() == 1 {
            QString::from(self.selected.iter().next().unwrap())
        } else {
            QString::from("")
        }
    }

    fn selected_names_joined(&self) -> QString {
        let names: Vec<&str> = self.selected.iter().map(|s| s.as_str()).collect();
        QString::from(&names.join("\n"))
    }

    fn open_selected_entry(mut self: core::pin::Pin<&mut Self>) {
        if self.selected.len() != 1 {
            return;
        }
        let name = self.selected.iter().next().unwrap().clone();
        let Some(entry) = self.entries.iter().find(|e| e.name == name) else {
            return;
        };
        if entry.is_dir {
            let path = QString::from(&format!("{}/{}", self.current_path.to_string(), name));
            self.as_mut().navigate(&path);
        } else {
            let name_q = QString::from(&name);
            self.as_mut().open_entry(&name_q);
        }
    }

    /// Navigation is asynchronous: the path bar, sidebar highlight, and an
    /// emptied view respond instantly while the listing streams in on a
    /// background task — the old block_on() here froze the whole UI for as
    /// long as the listing took (very visible on huge directories and slow
    /// filesystems, and it also delayed first paint at startup).
    fn navigate(mut self: core::pin::Pin<&mut Self>, path: &QString) {
        let path_buf = PathBuf::from(path.to_string());

        // Clearing the entries immediately isn't just cosmetic: currentPath
        // updates right away, so leaving the old directory's rows visible
        // would let a click/drop during the load act on old names resolved
        // against the NEW path.
        self.as_mut().begin_reset_model();
        self.as_mut().rust_mut().entries = Vec::new();
        // A search filter (and a selection) from the previous directory
        // shouldn't silently carry over into the new one.
        self.as_mut().rust_mut().search_query = QString::from("");
        self.as_mut().rust_mut().selected.clear();
        self.as_mut().rust_mut().rebuild_displayed();
        self.as_mut().end_reset_model();
        self.as_mut()
            .set_current_path(QString::from(&path_buf.display().to_string()));
        self.save_settings();

        let generation = {
            let mut state = self.as_mut().rust_mut();
            state.listing_generation += 1;
            state.listing_generation
        };
        let sort_key = self.sort_key.to_string();
        let ascending = self.sort_ascending;
        let qt_thread = self.qt_thread();
        runtime().spawn(async move {
            let mut entries = gather_entries(&path_buf).await;
            sort_entries(&mut entries, &sort_key, ascending);
            let _ = qt_thread.queue(move |mut model| {
                if model.listing_generation != generation {
                    return;
                }
                model.as_mut().begin_reset_model();
                model.as_mut().rust_mut().entries = entries;
                model.as_mut().rust_mut().rebuild_displayed();
                model.as_mut().end_reset_model();
            });
        });
    }

    fn set_search_query(mut self: core::pin::Pin<&mut Self>, query: &QString) {
        self.as_mut().begin_reset_model();
        self.as_mut().rust_mut().search_query = query.clone();
        self.as_mut().rust_mut().rebuild_displayed();
        self.as_mut().end_reset_model();
    }

    fn set_show_hidden(mut self: core::pin::Pin<&mut Self>, show_hidden: bool) {
        self.as_mut().begin_reset_model();
        self.as_mut().rust_mut().show_hidden = show_hidden;
        self.as_mut().rust_mut().rebuild_displayed();
        self.as_mut().end_reset_model();
    }

    fn set_sort_key(mut self: core::pin::Pin<&mut Self>, sort_key: &QString) {
        self.as_mut().begin_reset_model();
        self.as_mut().rust_mut().sort_key = sort_key.clone();
        let ascending = self.sort_ascending;
        let key = self.sort_key.to_string();
        sort_entries(&mut self.as_mut().rust_mut().entries, &key, ascending);
        self.as_mut().rust_mut().rebuild_displayed();
        self.as_mut().end_reset_model();
    }

    fn set_sort_ascending(mut self: core::pin::Pin<&mut Self>, ascending: bool) {
        self.as_mut().begin_reset_model();
        self.as_mut().rust_mut().sort_ascending = ascending;
        let key = self.sort_key.to_string();
        sort_entries(&mut self.as_mut().rust_mut().entries, &key, ascending);
        self.as_mut().rust_mut().rebuild_displayed();
        self.as_mut().end_reset_model();
    }

    fn create_folder(mut self: core::pin::Pin<&mut Self>, name: &QString) {
        let current = PathBuf::from(self.current_path.to_string());
        match runtime().block_on(fm_core::ops::create_folder(&current, &name.to_string())) {
            Ok(path) => {
                let op = UndoOp::CreateFolder { path };
                let desc = op.describe();
                self.as_mut().rust_mut().journal.record(op);
                self.as_mut().operation_completed(QString::from(&desc), true);
            }
            Err(e) => {
                eprintln!("create_folder failed: {e}");
                self.as_mut()
                    .error_occurred(QString::from(&format!("Couldn't create folder: {e}")));
            }
        }
        self.as_mut().refresh_entries_diff();
    }

    fn rename_entry(mut self: core::pin::Pin<&mut Self>, old_name: &QString, new_name: &QString) {
        let current = PathBuf::from(self.current_path.to_string());
        let target = current.join(old_name.to_string());
        match runtime().block_on(fm_core::ops::rename(&target, &new_name.to_string())) {
            Ok(new_path) => {
                let op = UndoOp::Rename {
                    from: target,
                    to: new_path,
                };
                let desc = op.describe();
                self.as_mut().rust_mut().journal.record(op);
                self.as_mut().operation_completed(QString::from(&desc), true);
            }
            Err(e) => {
                eprintln!("rename failed: {e}");
                self.as_mut().error_occurred(QString::from(&format!(
                    "Couldn't rename \"{}\": {e}",
                    old_name.to_string()
                )));
            }
        }
        self.as_mut().refresh_entries_diff();
    }

    fn delete_entry(mut self: core::pin::Pin<&mut Self>, name: &QString) {
        let current = PathBuf::from(self.current_path.to_string());
        let target = current.join(name.to_string());
        match runtime().block_on(fm_core::trash::move_to_trash(&target)) {
            Ok(trashed) => {
                let op = UndoOp::TrashDelete {
                    pairs: vec![(target, trashed)],
                };
                let desc = op.describe();
                self.as_mut().rust_mut().journal.record(op);
                self.as_mut().operation_completed(QString::from(&desc), true);
            }
            Err(e) => {
                eprintln!("delete_entry failed: {e}");
                self.as_mut().error_occurred(QString::from(&format!(
                    "Couldn't delete \"{}\": {e}",
                    name.to_string()
                )));
            }
        }
        self.as_mut().refresh_entries_diff();
    }

    fn delete_selection(mut self: core::pin::Pin<&mut Self>) {
        let current = PathBuf::from(self.current_path.to_string());
        let targets: Vec<PathBuf> = self.selected.iter().map(|name| current.join(name)).collect();
        if targets.is_empty() {
            return;
        }

        self.as_mut().set_is_busy(true);
        self.as_mut().set_busy_label(QString::from("Deleting…"));

        let qt_thread = self.qt_thread();
        runtime().spawn(async move {
            let mut failed: usize = 0;
            let mut pairs: Vec<(PathBuf, PathBuf)> = Vec::new();
            for target in targets {
                match fm_core::trash::move_to_trash(&target).await {
                    Ok(trashed) => pairs.push((target, trashed)),
                    Err(e) => {
                        eprintln!("delete_selection failed for {}: {e}", target.display());
                        failed += 1;
                    }
                }
            }
            let _ = qt_thread.queue(move |mut model| {
                model.as_mut().set_is_busy(false);
                model.as_mut().refresh_entries_diff();
                if failed > 0 {
                    model.as_mut().error_occurred(QString::from(&format!(
                        "Couldn't delete {}",
                        pluralize_items(failed)
                    )));
                }
                if !pairs.is_empty() {
                    let op = UndoOp::TrashDelete { pairs };
                    let desc = op.describe();
                    model.as_mut().rust_mut().journal.record(op);
                    model.as_mut().operation_completed(QString::from(&desc), true);
                }
            });
        });
    }

    fn empty_trash(mut self: core::pin::Pin<&mut Self>) {
        if let Err(e) = runtime().block_on(fm_core::trash::empty_trash()) {
            eprintln!("empty_trash failed: {e}");
            self.as_mut()
                .error_occurred(QString::from(&format!("Couldn't empty trash: {e}")));
        }
        if self.current_path.to_string() == self.trash_path.to_string() {
            self.as_mut().refresh_entries_diff();
        }
    }

    /// Re-lists the current directory and reconciles the model against the
    /// fresh listing with row-level insert/remove operations instead of a
    /// full reset, so a single create/rename/delete only disturbs the rows
    /// that actually changed (list position, scroll offset, and hover state
    /// of every other row survive untouched).
    ///
    /// The listing runs on a background task — the old block_on() here
    /// froze the UI after every operation for as long as the re-list took.
    /// The result is applied only if no navigate()/newer refresh started
    /// in the meantime (same generation guard navigate uses), so a slow
    /// stale listing can't clobber newer state.
    fn refresh_entries_diff(mut self: core::pin::Pin<&mut Self>) {
        let current = PathBuf::from(self.current_path.to_string());
        let generation = {
            let mut state = self.as_mut().rust_mut();
            state.listing_generation += 1;
            state.listing_generation
        };
        let sort_key = self.sort_key.to_string();
        let ascending = self.sort_ascending;
        let qt_thread = self.qt_thread();
        runtime().spawn(async move {
            let mut new_entries = gather_entries(&current).await;
            sort_entries(&mut new_entries, &sort_key, ascending);
            let _ = qt_thread.queue(move |mut model| {
                if model.listing_generation != generation {
                    return;
                }
                model.as_mut().apply_entries_diff(new_entries);
            });
        });
    }

    fn apply_entries_diff(mut self: core::pin::Pin<&mut Self>, new_entries: Vec<fm_core::FileEntry>) {
        fn same_entry(a: &fm_core::FileEntry, b: &fm_core::FileEntry) -> bool {
            a.name == b.name && a.is_dir == b.is_dir
        }

        // A selected name that no longer exists in the fresh listing (it
        // was deleted, renamed, or moved elsewhere) can't stay selected.
        let new_names: std::collections::HashSet<String> =
            new_entries.iter().map(|e| e.name.clone()).collect();
        self.as_mut()
            .rust_mut()
            .selected
            .retain(|name| new_names.contains(name));

        if !self.search_query.to_string().is_empty() || !self.show_hidden {
            // The row-level diff below assumes model rows map 1:1 onto
            // `entries` indices, which only holds when nothing is
            // filtered out — fall back to a plain reset while a search or
            // the (default-on) hidden-file filter is active, rather than
            // computing wrong row indices. This means the smooth per-row
            // diff mainly kicks in once "show hidden files" is turned on.
            self.as_mut().begin_reset_model();
            self.as_mut().rust_mut().entries = new_entries;
            self.as_mut().rust_mut().rebuild_displayed();
            self.as_mut().end_reset_model();
            return;
        }

        let parent = cxx_qt_lib::QModelIndex::default();

        // Phase 1: remove rows whose entry no longer exists, highest index
        // first so earlier indices stay valid as we go. Membership goes
        // through a hash set — probing new_entries linearly per old entry
        // made this quadratic, which a large directory felt on every
        // refresh.
        let remove_indices: Vec<usize> = {
            let new_keys: std::collections::HashSet<(&str, bool)> = new_entries
                .iter()
                .map(|e| (e.name.as_str(), e.is_dir))
                .collect();
            self.entries
                .iter()
                .enumerate()
                .filter(|(_, old)| !new_keys.contains(&(old.name.as_str(), old.is_dir)))
                .map(|(i, _)| i)
                .collect()
        };
        for &idx in remove_indices.iter().rev() {
            self.as_mut()
                .begin_remove_rows(&parent, idx as i32, idx as i32);
            self.as_mut().rust_mut().entries.remove(idx);
            self.as_mut().rust_mut().rebuild_displayed();
            self.as_mut().end_remove_rows();
        }

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

    fn open_entry(mut self: core::pin::Pin<&mut Self>, name: &QString) {
        let current = PathBuf::from(self.current_path.to_string());
        let target = current.join(name.to_string());
        if let Err(e) = runtime().block_on(fm_core::ops::open_file(&target)) {
            eprintln!("open_entry failed: {e}");
            self.as_mut().error_occurred(QString::from(&format!(
                "Couldn't open \"{}\": {e}",
                name.to_string()
            )));
        }
    }

    fn duplicate_entry(mut self: core::pin::Pin<&mut Self>, name: &QString) {
        let current = PathBuf::from(self.current_path.to_string());
        let target = current.join(name.to_string());
        match runtime().block_on(fm_core::ops::duplicate(&target)) {
            Ok(created) => {
                let op = UndoOp::CopyIn {
                    pairs: vec![(target, created)],
                };
                let desc = op.describe();
                self.as_mut().rust_mut().journal.record(op);
                self.as_mut().operation_completed(QString::from(&desc), true);
            }
            Err(e) => {
                eprintln!("duplicate_entry failed: {e}");
                self.as_mut().error_occurred(QString::from(&format!(
                    "Couldn't duplicate \"{}\": {e}",
                    name.to_string()
                )));
            }
        }
        self.as_mut().refresh_entries_diff();
    }

    fn duplicate_selection(mut self: core::pin::Pin<&mut Self>) {
        let current = PathBuf::from(self.current_path.to_string());
        let targets: Vec<PathBuf> = self.selected.iter().map(|name| current.join(name)).collect();
        if targets.is_empty() {
            return;
        }

        self.as_mut().set_is_busy(true);
        self.as_mut().set_busy_label(QString::from("Duplicating…"));

        let qt_thread = self.qt_thread();
        runtime().spawn(async move {
            let mut failed: usize = 0;
            let mut pairs: Vec<(PathBuf, PathBuf)> = Vec::new();
            for target in targets {
                match fm_core::ops::duplicate(&target).await {
                    Ok(created) => pairs.push((target, created)),
                    Err(e) => {
                        eprintln!("duplicate_selection failed for {}: {e}", target.display());
                        failed += 1;
                    }
                }
            }
            let _ = qt_thread.queue(move |mut model| {
                model.as_mut().set_is_busy(false);
                model.as_mut().refresh_entries_diff();
                if failed > 0 {
                    model.as_mut().error_occurred(QString::from(&format!(
                        "Couldn't duplicate {}",
                        pluralize_items(failed)
                    )));
                }
                if !pairs.is_empty() {
                    let op = UndoOp::CopyIn { pairs };
                    let desc = op.describe();
                    model.as_mut().rust_mut().journal.record(op);
                    model.as_mut().operation_completed(QString::from(&desc), true);
                }
            });
        });
    }

    fn restore_entry(mut self: core::pin::Pin<&mut Self>, name: &QString) {
        let current = PathBuf::from(self.current_path.to_string());
        let target = current.join(name.to_string());
        match runtime().block_on(fm_core::trash::restore(&target)) {
            Ok(restored) => {
                let op = UndoOp::Restore {
                    pairs: vec![(target, restored)],
                };
                let desc = op.describe();
                self.as_mut().rust_mut().journal.record(op);
                self.as_mut().operation_completed(QString::from(&desc), true);
            }
            Err(e) => {
                eprintln!("restore_entry failed: {e}");
                self.as_mut().error_occurred(QString::from(&format!(
                    "Couldn't restore \"{}\": {e}",
                    name.to_string()
                )));
            }
        }
        self.as_mut().refresh_entries_diff();
    }

    fn restore_selection(mut self: core::pin::Pin<&mut Self>) {
        let current = PathBuf::from(self.current_path.to_string());
        let targets: Vec<PathBuf> = self.selected.iter().map(|name| current.join(name)).collect();
        if targets.is_empty() {
            return;
        }

        self.as_mut().set_is_busy(true);
        self.as_mut().set_busy_label(QString::from("Restoring…"));

        let qt_thread = self.qt_thread();
        runtime().spawn(async move {
            let mut failed: usize = 0;
            let mut pairs: Vec<(PathBuf, PathBuf)> = Vec::new();
            for target in targets {
                match fm_core::trash::restore(&target).await {
                    Ok(restored) => pairs.push((target, restored)),
                    Err(e) => {
                        eprintln!("restore_selection failed for {}: {e}", target.display());
                        failed += 1;
                    }
                }
            }
            let _ = qt_thread.queue(move |mut model| {
                model.as_mut().set_is_busy(false);
                model.as_mut().refresh_entries_diff();
                if failed > 0 {
                    model.as_mut().error_occurred(QString::from(&format!(
                        "Couldn't restore {}",
                        pluralize_items(failed)
                    )));
                }
                if !pairs.is_empty() {
                    let op = UndoOp::Restore { pairs };
                    let desc = op.describe();
                    model.as_mut().rust_mut().journal.record(op);
                    model.as_mut().operation_completed(QString::from(&desc), true);
                }
            });
        });
    }

    fn delete_permanently_entry(mut self: core::pin::Pin<&mut Self>, name: &QString) {
        let current = PathBuf::from(self.current_path.to_string());
        let target = current.join(name.to_string());
        if let Err(e) = runtime().block_on(fm_core::trash::delete_permanently(&target)) {
            eprintln!("delete_permanently_entry failed: {e}");
            self.as_mut().error_occurred(QString::from(&format!(
                "Couldn't permanently delete \"{}\": {e}",
                name.to_string()
            )));
        }
        self.as_mut().refresh_entries_diff();
    }

    fn delete_permanently_selection(mut self: core::pin::Pin<&mut Self>) {
        let current = PathBuf::from(self.current_path.to_string());
        let targets: Vec<PathBuf> = self.selected.iter().map(|name| current.join(name)).collect();
        if targets.is_empty() {
            return;
        }

        self.as_mut().set_is_busy(true);
        self.as_mut().set_busy_label(QString::from("Deleting Permanently…"));

        let qt_thread = self.qt_thread();
        runtime().spawn(async move {
            let mut failed: usize = 0;
            for target in targets {
                if let Err(e) = fm_core::trash::delete_permanently(&target).await {
                    eprintln!(
                        "delete_permanently_selection failed for {}: {e}",
                        target.display()
                    );
                    failed += 1;
                }
            }
            let _ = qt_thread.queue(move |mut model| {
                model.as_mut().set_is_busy(false);
                model.as_mut().refresh_entries_diff();
                if failed > 0 {
                    model.as_mut().error_occurred(QString::from(&format!(
                        "Couldn't permanently delete {}",
                        pluralize_items(failed)
                    )));
                }
            });
        });
    }

    fn open_terminal_here(mut self: core::pin::Pin<&mut Self>) {
        let current = PathBuf::from(self.current_path.to_string());
        if let Err(e) = runtime().block_on(fm_core::ops::open_terminal(&current)) {
            eprintln!("open_terminal_here failed: {e}");
            self.as_mut()
                .error_occurred(QString::from(&format!("Couldn't open terminal here: {e}")));
        }
    }

    fn copy_entry(mut self: core::pin::Pin<&mut Self>, name: &QString) {
        let current = PathBuf::from(self.current_path.to_string());
        self.as_mut().rust_mut().clipboard_paths = vec![current.join(name.to_string())];
        self.as_mut().rust_mut().clipboard_is_cut = false;
    }

    fn cut_entry(mut self: core::pin::Pin<&mut Self>, name: &QString) {
        let current = PathBuf::from(self.current_path.to_string());
        self.as_mut().rust_mut().clipboard_paths = vec![current.join(name.to_string())];
        self.as_mut().rust_mut().clipboard_is_cut = true;
    }

    fn copy_selection(mut self: core::pin::Pin<&mut Self>) {
        let current = PathBuf::from(self.current_path.to_string());
        let paths: Vec<PathBuf> = self.selected.iter().map(|name| current.join(name)).collect();
        self.as_mut().rust_mut().clipboard_paths = paths;
        self.as_mut().rust_mut().clipboard_is_cut = false;
    }

    fn cut_selection(mut self: core::pin::Pin<&mut Self>) {
        let current = PathBuf::from(self.current_path.to_string());
        let paths: Vec<PathBuf> = self.selected.iter().map(|name| current.join(name)).collect();
        self.as_mut().rust_mut().clipboard_paths = paths;
        self.as_mut().rust_mut().clipboard_is_cut = true;
    }

    fn can_paste(&self) -> bool {
        !self.clipboard_paths.is_empty()
    }

    fn paste_entry(mut self: core::pin::Pin<&mut Self>) {
        let sources = self.clipboard_paths.clone();
        if sources.is_empty() {
            return;
        }
        let is_cut = self.clipboard_is_cut;
        let dest_dir = PathBuf::from(self.current_path.to_string());

        // A cut clears the whole clipboard after pasting once; a copy can
        // be pasted repeatedly — same rule as before, now applied via the
        // shared transfer_batch helper (see also dropPaths, which shares
        // this same batch copy/move-with-progress machinery).
        if is_cut {
            self.as_mut().rust_mut().clipboard_paths = Vec::new();
        }

        self.as_mut().transfer_batch(sources, dest_dir, is_cut, "paste");
    }

    fn drop_paths(mut self: core::pin::Pin<&mut Self>, paths: &QString, dest_dir: &QString, is_move: bool) {
        let sources: Vec<PathBuf> = paths.to_string().lines().map(PathBuf::from).collect();
        if sources.is_empty() {
            return;
        }
        let dest = PathBuf::from(dest_dir.to_string());
        let verb = if is_move { "move" } else { "copy" };
        self.as_mut().transfer_batch(sources, dest, is_move, verb);
    }

    fn undo(mut self: core::pin::Pin<&mut Self>) {
        if self.is_busy {
            return;
        }
        let Some(op) = self.as_mut().rust_mut().journal.pop_undo() else {
            self.as_mut()
                .operation_completed(QString::from("Nothing to undo"), false);
            return;
        };
        let desc = op.describe();
        self.as_mut().set_is_busy(true);
        self.as_mut().set_busy_label(QString::from("Undoing…"));

        let qt_thread = self.qt_thread();
        runtime().spawn(async move {
            let (redo_record, failed) = execute_undo(op).await;
            let _ = qt_thread.queue(move |mut model| {
                model.as_mut().set_is_busy(false);
                model.as_mut().refresh_entries_diff();
                if failed > 0 {
                    model.as_mut().error_occurred(QString::from(&format!(
                        "Couldn't undo {}",
                        pluralize_items(failed)
                    )));
                }
                if let Some(record) = redo_record {
                    model.as_mut().rust_mut().journal.push_redo(record);
                    model
                        .as_mut()
                        .operation_completed(QString::from(&format!("Undid: {desc}")), false);
                }
            });
        });
    }

    fn redo(mut self: core::pin::Pin<&mut Self>) {
        if self.is_busy {
            return;
        }
        let Some(op) = self.as_mut().rust_mut().journal.pop_redo() else {
            self.as_mut()
                .operation_completed(QString::from("Nothing to redo"), false);
            return;
        };
        let desc = op.describe();
        self.as_mut().set_is_busy(true);
        self.as_mut().set_busy_label(QString::from("Redoing…"));

        let qt_thread = self.qt_thread();
        runtime().spawn(async move {
            let (undo_record, failed) = execute_redo(op).await;
            let _ = qt_thread.queue(move |mut model| {
                model.as_mut().set_is_busy(false);
                model.as_mut().refresh_entries_diff();
                if failed > 0 {
                    model.as_mut().error_occurred(QString::from(&format!(
                        "Couldn't redo {}",
                        pluralize_items(failed)
                    )));
                }
                if let Some(record) = undo_record {
                    model.as_mut().rust_mut().journal.push_undo(record);
                    model
                        .as_mut()
                        .operation_completed(QString::from(&format!("Redid: {desc}")), false);
                }
            });
        });
    }

    /// Shared copy/move-with-progress batch machinery for both pasteEntry
    /// (sources from clipboard_paths) and dropPaths (sources from a
    /// drag-and-drop). `verb` only affects the dev-facing eprintln! label
    /// and the user-facing batch error message (e.g. "paste" keeps
    /// pasteEntry's existing wording; dropPaths passes "move" or "copy").
    fn transfer_batch(
        mut self: core::pin::Pin<&mut Self>,
        sources: Vec<PathBuf>,
        dest_dir: PathBuf,
        is_move: bool,
        verb: &'static str,
    ) {
        self.as_mut().set_is_busy(true);
        self.as_mut().set_busy_label(QString::from(if is_move {
            "Moving…"
        } else {
            "Copying…"
        }));
        self.as_mut().set_transfer_done_bytes(0);
        // The real total lands via the queue below once the background
        // walk finishes — path_size walks the entire source tree, and
        // computing it synchronously here froze the UI (before the busy
        // indicator even appeared) for however long the walk of a big
        // folder took.
        self.as_mut().set_transfer_total_bytes(0);
        self.as_mut().set_transfer_speed_label(QString::from(""));

        // Shared across every item in the batch and never reset between
        // them — copy_with_progress/move_entry_with_progress only ever
        // fetch_add onto `done`, so reusing the same counter across
        // sequential items gives one continuous running total for the
        // whole batch instead of restarting at 0 per item.
        let done_counter = std::sync::Arc::new(std::sync::atomic::AtomicU64::new(0));
        let (progress_tx, mut progress_rx) = tokio::sync::mpsc::unbounded_channel::<u64>();

        let qt_thread = self.qt_thread();
        let progress_qt_thread = qt_thread.clone();
        runtime().spawn(async move {
            let start = std::time::Instant::now();
            let mut last_emit = std::time::Instant::now() - std::time::Duration::from_secs(1);
            while let Some(done) = progress_rx.recv().await {
                if last_emit.elapsed() < std::time::Duration::from_millis(120) {
                    continue;
                }
                last_emit = std::time::Instant::now();
                let elapsed = start.elapsed().as_secs_f64().max(0.001);
                let speed = (done as f64 / elapsed) as u64;
                let _ = progress_qt_thread.queue(move |mut model| {
                    model.as_mut().set_transfer_done_bytes(done as i64);
                    model
                        .as_mut()
                        .set_transfer_speed_label(QString::from(&format!(
                            "{}/s",
                            fm_core::ops::format_bytes(speed)
                        )));
                });
            }
        });

        let total_qt_thread = qt_thread.clone();
        runtime().spawn(async move {
            // One combined denominator for the whole batch, computed off
            // the UI thread (spawn_blocking: path_size is synchronous
            // std::fs recursion) before the copying starts, so the
            // "done / total" display still opens with a real number.
            let sources_for_total = sources.clone();
            let total = tokio::task::spawn_blocking(move || {
                sources_for_total
                    .iter()
                    .map(|src| fm_core::ops::path_size(src))
                    .sum::<u64>()
            })
            .await
            .unwrap_or(0);
            let _ = total_qt_thread.queue(move |mut model| {
                model.as_mut().set_transfer_total_bytes(total as i64);
            });

            let mut failed: usize = 0;
            let mut succeeded: Vec<(PathBuf, PathBuf)> = Vec::new();
            for src in sources {
                let Some(file_name) = src.file_name().map(|n| n.to_os_string()) else {
                    continue;
                };
                let dest = unique_paste_destination(&dest_dir, std::path::Path::new(&file_name));
                let result = if is_move {
                    fm_core::ops::move_entry_with_progress(
                        &src,
                        &dest,
                        done_counter.clone(),
                        progress_tx.clone(),
                    )
                    .await
                } else {
                    fm_core::ops::copy_with_progress(
                        src.clone(),
                        dest.clone(),
                        done_counter.clone(),
                        progress_tx.clone(),
                    )
                    .await
                };
                match result {
                    Ok(()) => succeeded.push((src, dest)),
                    Err(e) => {
                        eprintln!("{verb} failed for {}: {e}", src.display());
                        failed += 1;
                    }
                }
            }

            let _ = qt_thread.queue(move |mut model| {
                model.as_mut().set_is_busy(false);
                model.as_mut().set_transfer_done_bytes(0);
                model.as_mut().set_transfer_total_bytes(0);
                model.as_mut().refresh_entries_diff();
                if failed > 0 {
                    model.as_mut().error_occurred(QString::from(&format!(
                        "Couldn't {verb} {}",
                        pluralize_items(failed)
                    )));
                }
                if !succeeded.is_empty() {
                    let op = if is_move {
                        UndoOp::Move { pairs: succeeded }
                    } else {
                        UndoOp::CopyIn { pairs: succeeded }
                    };
                    let desc = op.describe();
                    model.as_mut().rust_mut().journal.record(op);
                    model.as_mut().operation_completed(QString::from(&desc), true);
                }
            });
        });
    }

    fn request_thumbnail(mut self: core::pin::Pin<&mut Self>, name: &QString) {
        let current = PathBuf::from(self.current_path.to_string());
        let source_path = current.join(name.to_string());

        let Some(entry) = self.entries.iter().find(|e| e.path == source_path) else {
            return;
        };
        if entry.thumbnail_path.is_some()
            || !fm_core::thumbnails::is_thumbnailable(&entry.mime_type)
            || self.pending_thumbnails.contains(&source_path)
        {
            return;
        }

        let request = fm_core::thumbnails::ThumbnailRequest {
            source_path: source_path.clone(),
            mime_type: entry.mime_type.clone(),
            size: entry.size,
            modified: entry.modified,
        };
        self.as_mut()
            .rust_mut()
            .pending_thumbnails
            .insert(source_path.clone());

        let folder_snapshot = current;
        let qt_thread = self.qt_thread();

        runtime().spawn(async move {
            // Cheap cache-only probe first, NOT gated by the semaphore.
            // The semaphore queue is FIFO: on the first visit to a big
            // uncached folder it fills with hundreds of slow decodes, and
            // when cache checks had to wait in that same line, revisiting
            // the folder rendered nothing at all until the entire backlog
            // drained — already-thumbnailed images must never wait behind
            // generation work.
            let probe_request = request.clone();
            let cached = tokio::task::spawn_blocking(move || {
                fm_core::thumbnails::lookup_cached(&probe_request)
            })
            .await
            .ok()
            .flatten();

            let outcome = match cached {
                Some(path) => fm_core::thumbnails::ThumbnailOutcome::Ready(path),
                None => {
                    // Cache miss — real decode work, so wait for a permit;
                    // see thumbnail_semaphore()'s comment for why the cap
                    // exists.
                    let _permit = thumbnail_semaphore().acquire().await;
                    tokio::task::spawn_blocking(move || {
                        fm_core::thumbnails::get_or_generate(&request)
                    })
                    .await
                    .unwrap_or(fm_core::thumbnails::ThumbnailOutcome::Unavailable)
                }
            };

            let _ = qt_thread.queue(move |mut model| {
                model
                    .as_mut()
                    .rust_mut()
                    .pending_thumbnails
                    .remove(&source_path);

                // Stale guard: the user may have navigated to a different
                // folder while this ran in the background — discard the
                // result rather than patch a row it no longer belongs to.
                if model.current_path.to_string() != folder_snapshot.display().to_string() {
                    return;
                }
                let Some(idx) = model.entries.iter().position(|e| e.path == source_path) else {
                    return;
                };
                let fm_core::thumbnails::ThumbnailOutcome::Ready(thumb_path) = outcome else {
                    return;
                };
                model.as_mut().rust_mut().entries[idx].thumbnail_path = Some(thumb_path);

                // Model rows are the FILTERED view of `entries` (hidden
                // files and search misses removed — see data()/row_count()),
                // so `idx` must be mapped through the displayed cache before
                // it can name a row. Emitting dataChanged with the raw
                // entries index pointed at the wrong row whenever any hidden
                // file preceded this entry in sort order — the delegate that
                // was actually waiting never heard its thumbnail was ready,
                // so in any folder containing a dotfile, thumbnails silently
                // never appeared. If the entry is itself filtered out right
                // now, there's no row to notify; the stored thumbnail_path
                // is still picked up by data() whenever it becomes visible.
                let Some(row) = model.displayed.iter().position(|&i| i == idx) else {
                    return;
                };
                let parent = cxx_qt_lib::QModelIndex::default();
                let model_index = model.model_index(row as i32, 0, &parent);
                model.as_mut().data_changed(
                    &model_index,
                    &model_index,
                    &cxx_qt_lib::QList::<i32>::default(),
                );
            });
        });
    }

    fn entry_absolute_path(&self, name: &QString) -> QString {
        let current = PathBuf::from(self.current_path.to_string());
        QString::from(&current.join(name.to_string()).display().to_string())
    }

    /// A cheap, synchronous immediate-children count for the Properties
    /// dialog.
    fn folder_item_count(&self, name: &QString) -> i32 {
        let current = PathBuf::from(self.current_path.to_string());
        let target = current.join(name.to_string());
        std::fs::read_dir(&target)
            .map(|entries| entries.count() as i32)
            .unwrap_or(0)
    }

    /// A true recursive folder size for the Properties dialog, walking the
    /// whole tree synchronously. This blocks the UI thread for as long as
    /// the walk takes — fine for a typical folder, but a folder with a
    /// very large number of files/subdirectories (or a slow filesystem)
    /// will make the Properties dialog visibly stall while it opens.
    fn folder_size(&self, name: &QString) -> i64 {
        let current = PathBuf::from(self.current_path.to_string());
        let target = current.join(name.to_string());
        dir_size(&target) as i64
    }

    /// Reads themeColorsPath's raw contents for Color.qml to JSON.parse.
    /// Done here rather than via QML's XMLHttpRequest — Qt disables local
    /// file reads through XHR by default (QML_XHR_ALLOW_FILE_READ), and
    /// requiring users to set an env var just to use a color file isn't
    /// reasonable. Plain Rust file I/O has no such restriction. Returns an
    /// empty string if the file doesn't exist or can't be read.
    fn read_theme_colors_file(&self) -> QString {
        std::fs::read_to_string(self.theme_colors_path.to_string())
            .map(|contents| QString::from(&contents))
            .unwrap_or_else(|_| QString::from(""))
    }

    fn start_theme_colors_watch(mut self: core::pin::Pin<&mut Self>) {
        let initial = self.read_theme_colors_file();
        self.as_mut().set_theme_colors_text(initial);

        let path = PathBuf::from(self.theme_colors_path.to_string());
        let Some(parent) = path.parent().map(|p| p.to_path_buf()) else {
            return;
        };
        if !parent.exists() {
            return;
        }

        let (tx, mut rx) = tokio::sync::mpsc::unbounded_channel();
        let watcher = match fm_core::watcher::DirWatcher::new(&parent, tx) {
            Ok(w) => w,
            Err(e) => {
                eprintln!("start_theme_colors_watch failed: {e}");
                return;
            }
        };
        self.as_mut().rust_mut().theme_colors_watcher = Some(watcher);

        let watch_path = path;
        let qt_thread = self.qt_thread();
        runtime().spawn(async move {
            while let Some(event) = rx.recv().await {
                let touched = match &event {
                    fm_core::watcher::WatchEvent::Created(p) => p == &watch_path,
                    fm_core::watcher::WatchEvent::Modified(p) => p == &watch_path,
                    fm_core::watcher::WatchEvent::Renamed { to, .. } => to == &watch_path,
                    _ => false,
                };
                if !touched {
                    continue;
                }
                let contents = tokio::fs::read_to_string(&watch_path)
                    .await
                    .unwrap_or_default();
                let _ = qt_thread.queue(move |mut model| {
                    model.as_mut().set_theme_colors_text(QString::from(&contents));
                });
            }
        });
    }

    /// Persists the current view mode, sort order, icon size, hidden-file
    /// visibility, and current folder to settings.json. Called automatically
    /// on navigate(); QML also calls it directly after changing viewMode,
    /// iconSizeLevel, or a ViewOptionsMenu setting, since those don't
    /// otherwise trigger a Rust-side write.
    fn save_settings(&self) {
        let settings = fm_core::settings::Settings {
            view_mode: self.view_mode.to_string(),
            icon_size_level: self.icon_size_level.to_string(),
            sort_key: self.sort_key.to_string(),
            sort_ascending: self.sort_ascending,
            show_hidden: self.show_hidden,
            last_path: self.current_path.to_string(),
            resume_last_path: self.resume_last_path,
        };
        if let Err(e) = settings.save() {
            eprintln!("save_settings failed: {e}");
        }
    }

    fn is_show_hidden(&self) -> bool {
        self.show_hidden
    }

    fn current_sort_key(&self) -> QString {
        self.sort_key.clone()
    }

    fn is_sort_ascending(&self) -> bool {
        self.sort_ascending
    }
}

/// Picks a non-colliding destination for a paste: `dest_dir/name` if free,
/// otherwise `dest_dir/name (copy)`, `dest_dir/name (copy 2)`, etc. — the
/// same convention as fm_core::ops::duplicate, needed here too since
/// pasting into the same folder the entry was copied from (or any folder
/// that already has a same-named entry) would otherwise silently overwrite.
/// Moves src to dst, failing with AlreadyExists if anything already sits at
/// dst — tokio::fs::rename (inside move_entry) silently replaces an
/// existing file, which the undo conflict policy ("never overwrite")
/// forbids. symlink_metadata, not exists(): a dangling symlink still
/// occupies the name. The check-then-move race window is unavoidable and
/// acceptable for interactive undo.
async fn move_no_overwrite(src: &std::path::Path, dst: &std::path::Path) -> std::io::Result<()> {
    if tokio::fs::symlink_metadata(dst).await.is_ok() {
        return Err(std::io::Error::new(
            std::io::ErrorKind::AlreadyExists,
            "destination already exists",
        ));
    }
    fm_core::ops::move_entry(src, dst).await
}

/// Executes the inverse of `op`, entry by entry, fail-safe. Returns the
/// record to push onto the redo stack — containing only the entries that
/// succeeded, with fresh result paths where undoing produced new ones —
/// plus the count of entries that failed. (None, n) when nothing succeeded.
async fn execute_undo(op: UndoOp) -> (Option<UndoOp>, usize) {
    match op {
        UndoOp::Move { pairs } => {
            let mut ok = Vec::new();
            let mut failed = 0;
            for (orig, new) in pairs {
                match move_no_overwrite(&new, &orig).await {
                    Ok(()) => ok.push((orig, new)),
                    Err(e) => {
                        eprintln!("undo move failed for {}: {e}", new.display());
                        failed += 1;
                    }
                }
            }
            (
                (!ok.is_empty()).then_some(UndoOp::Move { pairs: ok }),
                failed,
            )
        }
        UndoOp::Rename { from, to } => match move_no_overwrite(&to, &from).await {
            Ok(()) => (Some(UndoOp::Rename { from, to }), 0),
            Err(e) => {
                eprintln!("undo rename failed for {}: {e}", to.display());
                (None, 1)
            }
        },
        UndoOp::TrashDelete { pairs } => {
            let mut ok = Vec::new();
            let mut failed = 0;
            for (orig, trashed) in pairs {
                // restore() uniquifies to "name (restored)" when the
                // original spot is occupied — the fail-safe policy forbids
                // that, so occupancy fails the entry up front instead.
                if tokio::fs::symlink_metadata(&orig).await.is_ok() {
                    eprintln!(
                        "undo trash failed for {}: original location occupied",
                        trashed.display()
                    );
                    failed += 1;
                    continue;
                }
                match fm_core::trash::restore(&trashed).await {
                    Ok(_) => ok.push((orig, trashed)),
                    Err(e) => {
                        eprintln!("undo trash failed for {}: {e}", trashed.display());
                        failed += 1;
                    }
                }
            }
            // The trashed halves in the redo record are stale (the files
            // just left the Trash) — execute_redo's TrashDelete arm
            // ignores them and re-trashes the originals from scratch.
            (
                (!ok.is_empty()).then_some(UndoOp::TrashDelete { pairs: ok }),
                failed,
            )
        }
        UndoOp::CopyIn { pairs } => {
            let mut ok = Vec::new();
            let mut failed = 0;
            for (src, created) in pairs {
                // To Trash, never a permanent delete — move_to_trash never
                // conflicts (the Trash spec uniquifies internally).
                match fm_core::trash::move_to_trash(&created).await {
                    Ok(_) => ok.push((src, created)),
                    Err(e) => {
                        eprintln!("undo copy failed for {}: {e}", created.display());
                        failed += 1;
                    }
                }
            }
            (
                (!ok.is_empty()).then_some(UndoOp::CopyIn { pairs: ok }),
                failed,
            )
        }
        UndoOp::CreateFolder { path } => match fm_core::trash::move_to_trash(&path).await {
            Ok(_) => (Some(UndoOp::CreateFolder { path }), 0),
            Err(e) => {
                eprintln!("undo create-folder failed for {}: {e}", path.display());
                (None, 1)
            }
        },
        UndoOp::Restore { pairs } => {
            let mut ok = Vec::new();
            let mut failed = 0;
            for (_stale_trashed, restored) in pairs {
                // Re-trashing mints a brand-new Trash path — the redo
                // record must carry it, not the stale pre-restore one,
                // so redo restores the right files.
                match fm_core::trash::move_to_trash(&restored).await {
                    Ok(new_trashed) => ok.push((new_trashed, restored)),
                    Err(e) => {
                        eprintln!("undo restore failed for {}: {e}", restored.display());
                        failed += 1;
                    }
                }
            }
            (
                (!ok.is_empty()).then_some(UndoOp::Restore { pairs: ok }),
                failed,
            )
        }
    }
}

/// Re-executes `op` forward, entry by entry, fail-safe — the mirror of
/// execute_undo. Returns the record to push back onto the undo stack (only
/// the entries that succeeded, with fresh result paths) plus the failure
/// count.
async fn execute_redo(op: UndoOp) -> (Option<UndoOp>, usize) {
    match op {
        UndoOp::Move { pairs } => {
            let mut ok = Vec::new();
            let mut failed = 0;
            for (orig, new) in pairs {
                match move_no_overwrite(&orig, &new).await {
                    Ok(()) => ok.push((orig, new)),
                    Err(e) => {
                        eprintln!("redo move failed for {}: {e}", orig.display());
                        failed += 1;
                    }
                }
            }
            (
                (!ok.is_empty()).then_some(UndoOp::Move { pairs: ok }),
                failed,
            )
        }
        UndoOp::Rename { from, to } => match move_no_overwrite(&from, &to).await {
            Ok(()) => (Some(UndoOp::Rename { from, to }), 0),
            Err(e) => {
                eprintln!("redo rename failed for {}: {e}", from.display());
                (None, 1)
            }
        },
        UndoOp::TrashDelete { pairs } => {
            let mut ok = Vec::new();
            let mut failed = 0;
            for (orig, _stale_trashed) in pairs {
                match fm_core::trash::move_to_trash(&orig).await {
                    Ok(new_trashed) => ok.push((orig, new_trashed)),
                    Err(e) => {
                        eprintln!("redo trash failed for {}: {e}", orig.display());
                        failed += 1;
                    }
                }
            }
            (
                (!ok.is_empty()).then_some(UndoOp::TrashDelete { pairs: ok }),
                failed,
            )
        }
        UndoOp::CopyIn { pairs } => {
            let mut ok = Vec::new();
            let mut failed = 0;
            for (src, created) in pairs {
                // tokio::fs::copy overwrites silently, so occupancy is
                // pre-checked here just like move_no_overwrite does.
                if tokio::fs::symlink_metadata(&created).await.is_ok() {
                    eprintln!(
                        "redo copy failed for {}: destination occupied",
                        created.display()
                    );
                    failed += 1;
                    continue;
                }
                match fm_core::ops::copy(&src, &created).await {
                    Ok(()) => ok.push((src, created)),
                    Err(e) => {
                        eprintln!("redo copy failed for {}: {e}", src.display());
                        failed += 1;
                    }
                }
            }
            (
                (!ok.is_empty()).then_some(UndoOp::CopyIn { pairs: ok }),
                failed,
            )
        }
        UndoOp::CreateFolder { path } => {
            // create_dir errors if anything already sits at path — the
            // fail-safe check comes built in.
            match tokio::fs::create_dir(&path).await {
                Ok(()) => (Some(UndoOp::CreateFolder { path }), 0),
                Err(e) => {
                    eprintln!("redo create-folder failed for {}: {e}", path.display());
                    (None, 1)
                }
            }
        }
        UndoOp::Restore { pairs } => {
            let mut ok = Vec::new();
            let mut failed = 0;
            for (trashed, restored) in pairs {
                if tokio::fs::symlink_metadata(&restored).await.is_ok() {
                    eprintln!(
                        "redo restore failed for {}: destination occupied",
                        restored.display()
                    );
                    failed += 1;
                    continue;
                }
                match fm_core::trash::restore(&trashed).await {
                    // The trashed half is stale the moment restore consumes
                    // it, but the undo record only needs `restored` (undo of
                    // a restore = re-trash), and execute_undo's Restore arm
                    // rebuilds fresh trashed paths when that happens.
                    Ok(new_restored) => ok.push((trashed, new_restored)),
                    Err(e) => {
                        eprintln!("redo restore failed for {}: {e}", trashed.display());
                        failed += 1;
                    }
                }
            }
            (
                (!ok.is_empty()).then_some(UndoOp::Restore { pairs: ok }),
                failed,
            )
        }
    }
}

fn unique_paste_destination(dest_dir: &std::path::Path, name: &std::path::Path) -> PathBuf {
    let candidate = dest_dir.join(name);
    if !candidate.exists() {
        return candidate;
    }

    let stem = name
        .file_stem()
        .and_then(|s| s.to_str())
        .unwrap_or_default();
    let ext = name.extension().and_then(|e| e.to_str());

    let mut candidate = match ext {
        Some(ext) => dest_dir.join(format!("{stem} (copy).{ext}")),
        None => dest_dir.join(format!("{stem} (copy)")),
    };
    let mut n = 2;
    while candidate.exists() {
        candidate = match ext {
            Some(ext) => dest_dir.join(format!("{stem} (copy {n}).{ext}")),
            None => dest_dir.join(format!("{stem} (copy {n})")),
        };
        n += 1;
    }
    candidate
}

fn dir_size(path: &std::path::Path) -> u64 {
    let Ok(entries) = std::fs::read_dir(path) else {
        return 0;
    };
    entries
        .flatten()
        .map(|entry| match entry.metadata() {
            // metadata() uses lstat on Unix (doesn't follow symlinks), so
            // a symlink counts its own small size, never the target's —
            // avoiding both double-counting and symlink-cycle infinite
            // recursion.
            Ok(metadata) if metadata.is_dir() => dir_size(&entry.path()),
            Ok(metadata) => metadata.len(),
            Err(_) => 0,
        })
        .sum()
}

/// Names of every entry between `from_name` and `to_name` inclusive, in
/// `displayed`'s order (the order the user actually sees, i.e. an
/// already-filtered/sorted slice — not raw `entries`, which may contain
/// hidden/filtered-out names the user never clicked between). Works
/// regardless of which of the two names comes first. Returns an empty Vec
/// if either name isn't found in `displayed`.
fn resolve_range_names(displayed: &[&fm_core::FileEntry], from_name: &str, to_name: &str) -> Vec<String> {
    let Some(from_idx) = displayed.iter().position(|e| e.name == from_name) else {
        return Vec::new();
    };
    let Some(to_idx) = displayed.iter().position(|e| e.name == to_name) else {
        return Vec::new();
    };
    let (start, end) = if from_idx <= to_idx {
        (from_idx, to_idx)
    } else {
        (to_idx, from_idx)
    };
    displayed[start..=end].iter().map(|e| e.name.clone()).collect()
}

/// "1 item" vs "N items" — used to summarize a batch operation's failure
/// count instead of listing every individual failure.
fn pluralize_items(count: usize) -> String {
    if count == 1 {
        "1 item".to_string()
    } else {
        format!("{count} items")
    }
}

/// One undoable operation, recorded after it succeeded, holding the paths
/// that actually resulted (post-uniquification). Every pair Vec is
/// (before, after) in the operation's own forward direction.
#[derive(Clone, Debug, PartialEq)]
enum UndoOp {
    /// (original path, new path) — cut-paste, internal drag-move, external
    /// drop with isMove. Undo moves each `new` back to `orig`.
    Move { pairs: Vec<(PathBuf, PathBuf)> },
    /// Undo renames `to` back to `from`.
    Rename { from: PathBuf, to: PathBuf },
    /// (original path, trashed files/ path). Undo restores from Trash. The
    /// trashed half is only meaningful while this sits on the undo stack —
    /// redo re-trashes the originals and rebuilds fresh trashed paths.
    TrashDelete { pairs: Vec<(PathBuf, PathBuf)> },
    /// (source path, created path) — copy-paste, external drop-copy,
    /// duplicate. Undo moves the created files to Trash (never permanent).
    CopyIn { pairs: Vec<(PathBuf, PathBuf)> },
    /// Undo moves the created folder to Trash.
    CreateFolder { path: PathBuf },
    /// (trashed files/ path, restored path). Undo re-trashes the restored
    /// files — producing *new* trashed paths, which replace the stale
    /// first halves in the record pushed onto the redo stack.
    Restore { pairs: Vec<(PathBuf, PathBuf)> },
}

impl UndoOp {
    /// Short user-facing summary shown in the operationCompleted snackbar
    /// ("Moved 3 items"), and after undo/redo prefixed as "Undid: …".
    fn describe(&self) -> String {
        fn leaf(path: &std::path::Path) -> &str {
            path.file_name().and_then(|n| n.to_str()).unwrap_or("?")
        }
        match self {
            UndoOp::Move { pairs } => format!("Moved {}", pluralize_items(pairs.len())),
            UndoOp::Rename { to, .. } => format!("Renamed to \"{}\"", leaf(to)),
            UndoOp::TrashDelete { pairs } => {
                format!("Moved {} to Trash", pluralize_items(pairs.len()))
            }
            UndoOp::CopyIn { pairs } => format!("Copied {}", pluralize_items(pairs.len())),
            UndoOp::CreateFolder { path } => format!("Created folder \"{}\"", leaf(path)),
            UndoOp::Restore { pairs } => format!("Restored {}", pluralize_items(pairs.len())),
        }
    }
}

const UNDO_CAP: usize = 100;

/// Session-only undo/redo history. record() is for freshly performed
/// operations (clears redo — the standard branch-discarding rule);
/// push_undo/push_redo move an op between stacks after a redo/undo
/// completed, without touching the other stack.
#[derive(Default)]
struct UndoJournal {
    undo_stack: Vec<UndoOp>,
    redo_stack: Vec<UndoOp>,
}

impl UndoJournal {
    fn record(&mut self, op: UndoOp) {
        self.redo_stack.clear();
        self.push_undo(op);
    }

    fn push_undo(&mut self, op: UndoOp) {
        self.undo_stack.push(op);
        if self.undo_stack.len() > UNDO_CAP {
            self.undo_stack.remove(0);
        }
    }

    fn push_redo(&mut self, op: UndoOp) {
        self.redo_stack.push(op);
        if self.redo_stack.len() > UNDO_CAP {
            self.redo_stack.remove(0);
        }
    }

    fn pop_undo(&mut self) -> Option<UndoOp> {
        self.undo_stack.pop()
    }

    fn pop_redo(&mut self) -> Option<UndoOp> {
        self.redo_stack.pop()
    }
}

#[cfg(test)]
mod selection_range_tests {
    use super::*;
    use std::path::PathBuf;
    use std::time::SystemTime;

    fn entry(name: &str) -> fm_core::FileEntry {
        fm_core::FileEntry {
            name: name.to_string(),
            path: PathBuf::from(name),
            is_dir: false,
            size: 0,
            modified: SystemTime::UNIX_EPOCH,
            mime_type: "text/plain".to_string(),
            icon_key: "text".to_string(),
            permissions: "rw-r--r--".to_string(),
            thumbnail_path: None,
        }
    }

    #[test]
    fn resolves_a_forward_range_inclusive() {
        let entries = vec![entry("a"), entry("b"), entry("c"), entry("d")];
        let refs: Vec<&fm_core::FileEntry> = entries.iter().collect();
        let names = resolve_range_names(&refs, "b", "d");
        assert_eq!(names, vec!["b".to_string(), "c".to_string(), "d".to_string()]);
    }

    #[test]
    fn resolves_a_reversed_range_the_same_way() {
        let entries = vec![entry("a"), entry("b"), entry("c"), entry("d")];
        let refs: Vec<&fm_core::FileEntry> = entries.iter().collect();
        let names = resolve_range_names(&refs, "d", "b");
        assert_eq!(names, vec!["b".to_string(), "c".to_string(), "d".to_string()]);
    }

    #[test]
    fn a_range_from_a_name_to_itself_is_just_that_one_name() {
        let entries = vec![entry("a"), entry("b")];
        let refs: Vec<&fm_core::FileEntry> = entries.iter().collect();
        let names = resolve_range_names(&refs, "a", "a");
        assert_eq!(names, vec!["a".to_string()]);
    }

    #[test]
    fn an_unknown_name_resolves_to_an_empty_range() {
        let entries = vec![entry("a"), entry("b")];
        let refs: Vec<&fm_core::FileEntry> = entries.iter().collect();
        assert!(resolve_range_names(&refs, "a", "missing").is_empty());
        assert!(resolve_range_names(&refs, "missing", "a").is_empty());
    }
}

#[cfg(test)]
mod pluralize_items_tests {
    use super::*;

    #[test]
    fn pluralizes_a_single_item() {
        assert_eq!(pluralize_items(1), "1 item");
    }

    #[test]
    fn pluralizes_multiple_items() {
        assert_eq!(pluralize_items(3), "3 items");
    }

    #[test]
    fn pluralizes_zero_as_plural() {
        assert_eq!(pluralize_items(0), "0 items");
    }
}

#[cfg(test)]
mod undo_journal_tests {
    use super::*;
    use std::path::PathBuf;

    fn move_op() -> UndoOp {
        UndoOp::Move {
            pairs: vec![(PathBuf::from("/a/x"), PathBuf::from("/b/x"))],
        }
    }

    #[test]
    fn record_pushes_onto_the_undo_stack() {
        let mut journal = UndoJournal::default();
        journal.record(move_op());
        assert_eq!(journal.pop_undo(), Some(move_op()));
        assert_eq!(journal.pop_undo(), None);
    }

    #[test]
    fn record_clears_the_redo_stack() {
        let mut journal = UndoJournal::default();
        journal.push_redo(move_op());
        journal.record(move_op());
        assert_eq!(journal.pop_redo(), None);
    }

    #[test]
    fn push_undo_does_not_clear_the_redo_stack() {
        let mut journal = UndoJournal::default();
        journal.push_redo(move_op());
        journal.push_undo(move_op());
        assert_eq!(journal.pop_redo(), Some(move_op()));
    }

    #[test]
    fn undo_stack_caps_at_100_dropping_the_oldest() {
        let mut journal = UndoJournal::default();
        journal.record(UndoOp::CreateFolder {
            path: PathBuf::from("/oldest"),
        });
        for _ in 0..100 {
            journal.record(move_op());
        }
        // 101 records, cap 100: the CreateFolder fell off the bottom.
        let mut popped = 0;
        while let Some(op) = journal.pop_undo() {
            assert_eq!(op, move_op());
            popped += 1;
        }
        assert_eq!(popped, 100);
    }

    #[test]
    fn describes_each_operation_kind() {
        let pair = (PathBuf::from("/a/x.txt"), PathBuf::from("/b/x.txt"));
        let two = vec![pair.clone(), pair.clone()];
        assert_eq!(
            UndoOp::Move { pairs: two.clone() }.describe(),
            "Moved 2 items"
        );
        assert_eq!(
            UndoOp::Rename {
                from: PathBuf::from("/a/old.txt"),
                to: PathBuf::from("/a/new.txt"),
            }
            .describe(),
            "Renamed to \"new.txt\""
        );
        assert_eq!(
            UndoOp::TrashDelete {
                pairs: vec![pair.clone()],
            }
            .describe(),
            "Moved 1 item to Trash"
        );
        assert_eq!(
            UndoOp::CopyIn { pairs: two.clone() }.describe(),
            "Copied 2 items"
        );
        assert_eq!(
            UndoOp::CreateFolder {
                path: PathBuf::from("/a/New Folder"),
            }
            .describe(),
            "Created folder \"New Folder\""
        );
        assert_eq!(
            UndoOp::Restore {
                pairs: vec![pair],
            }
            .describe(),
            "Restored 1 item"
        );
    }
}
