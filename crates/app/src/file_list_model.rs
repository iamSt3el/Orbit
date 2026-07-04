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
        }
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
fn sort_entries(entries: &mut [fm_core::FileEntry], sort_key: &str, ascending: bool) {
    entries.sort_by(|a, b| {
        let dir_order = match (a.is_dir, b.is_dir) {
            (true, false) => std::cmp::Ordering::Less,
            (false, true) => std::cmp::Ordering::Greater,
            _ => std::cmp::Ordering::Equal,
        };
        if dir_order != std::cmp::Ordering::Equal {
            return dir_order;
        }
        let cmp = match sort_key {
            "size" => a.size.cmp(&b.size),
            "modified" => a.modified.cmp(&b.modified),
            "type" => a.mime_type.cmp(&b.mime_type),
            _ => a.name.to_lowercase().cmp(&b.name.to_lowercase()),
        };
        if ascending {
            cmp
        } else {
            cmp.reverse()
        }
    });
}

/// Indices into `entries` matching the current search query and hidden-file
/// setting (all of them, in order, when nothing is filtered). Recomputed on
/// demand rather than cached — directory sizes here are small enough
/// (hundreds to low thousands of entries) that a fresh linear scan per
/// `data()`/`row_count()` call is not a measurable cost, and it keeps the
/// create/rename/delete diff logic below untouched by filtering entirely.
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
        matching_indices(&self.entries, &self.search_query.to_string(), self.show_hidden).len() as i32
    }

    fn data(&self, index: &cxx_qt_lib::QModelIndex, role: i32) -> QVariant {
        let row = index.row();
        let matching = matching_indices(&self.entries, &self.search_query.to_string(), self.show_hidden);
        if row < 0 || row as usize >= matching.len() {
            return QVariant::default();
        }
        let entry = &self.entries[matching[row as usize]];
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
        let matching = matching_indices(&self.entries, &self.search_query.to_string(), self.show_hidden);
        let Some(row) = matching.iter().position(|&i| i == idx) else {
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
        let matching = matching_indices(&self.entries, &self.search_query.to_string(), self.show_hidden);
        let displayed: Vec<&fm_core::FileEntry> = matching.iter().map(|&i| &self.entries[i]).collect();
        let names = resolve_range_names(&displayed, &from_name.to_string(), &to_name.to_string());
        if names.is_empty() {
            return;
        }
        self.as_mut().rust_mut().selected = names.into_iter().collect();

        if matching.is_empty() {
            return;
        }
        let parent = cxx_qt_lib::QModelIndex::default();
        let first = self.model_index(0, 0, &parent);
        let last = self.model_index((matching.len() - 1) as i32, 0, &parent);
        self.as_mut()
            .data_changed(&first, &last, &cxx_qt_lib::QList::<i32>::default());
    }

    fn select_all(mut self: core::pin::Pin<&mut Self>) {
        let matching = matching_indices(&self.entries, &self.search_query.to_string(), self.show_hidden);
        let names: std::collections::HashSet<String> =
            matching.iter().map(|&i| self.entries[i].name.clone()).collect();
        self.as_mut().rust_mut().selected = names;
        if matching.is_empty() {
            return;
        }
        let parent = cxx_qt_lib::QModelIndex::default();
        let first = self.model_index(0, 0, &parent);
        let last = self.model_index((matching.len() - 1) as i32, 0, &parent);
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

    fn navigate(mut self: core::pin::Pin<&mut Self>, path: &QString) {
        let path_buf = PathBuf::from(path.to_string());
        let mut entries = runtime().block_on(gather_entries(&path_buf));
        sort_entries(
            &mut entries,
            &self.sort_key.to_string(),
            self.sort_ascending,
        );

        self.as_mut().begin_reset_model();
        self.as_mut().rust_mut().entries = entries;
        // A search filter (and a selection) from the previous directory
        // shouldn't silently carry over into the new one.
        self.as_mut().rust_mut().search_query = QString::from("");
        self.as_mut().rust_mut().selected.clear();
        self.as_mut().end_reset_model();
        self.as_mut()
            .set_current_path(QString::from(&path_buf.display().to_string()));
        self.save_settings();
    }

    fn set_search_query(mut self: core::pin::Pin<&mut Self>, query: &QString) {
        self.as_mut().begin_reset_model();
        self.as_mut().rust_mut().search_query = query.clone();
        self.as_mut().end_reset_model();
    }

    fn set_show_hidden(mut self: core::pin::Pin<&mut Self>, show_hidden: bool) {
        self.as_mut().begin_reset_model();
        self.as_mut().rust_mut().show_hidden = show_hidden;
        self.as_mut().end_reset_model();
    }

    fn set_sort_key(mut self: core::pin::Pin<&mut Self>, sort_key: &QString) {
        self.as_mut().begin_reset_model();
        self.as_mut().rust_mut().sort_key = sort_key.clone();
        let ascending = self.sort_ascending;
        let key = self.sort_key.to_string();
        sort_entries(&mut self.as_mut().rust_mut().entries, &key, ascending);
        self.as_mut().end_reset_model();
    }

    fn set_sort_ascending(mut self: core::pin::Pin<&mut Self>, ascending: bool) {
        self.as_mut().begin_reset_model();
        self.as_mut().rust_mut().sort_ascending = ascending;
        let key = self.sort_key.to_string();
        sort_entries(&mut self.as_mut().rust_mut().entries, &key, ascending);
        self.as_mut().end_reset_model();
    }

    fn create_folder(mut self: core::pin::Pin<&mut Self>, name: &QString) {
        let current = PathBuf::from(self.current_path.to_string());
        if let Err(e) =
            runtime().block_on(fm_core::ops::create_folder(&current, &name.to_string()))
        {
            eprintln!("create_folder failed: {e}");
            self.as_mut()
                .error_occurred(QString::from(&format!("Couldn't create folder: {e}")));
        }
        self.as_mut().refresh_entries_diff();
    }

    fn rename_entry(mut self: core::pin::Pin<&mut Self>, old_name: &QString, new_name: &QString) {
        let current = PathBuf::from(self.current_path.to_string());
        let target = current.join(old_name.to_string());
        if let Err(e) = runtime().block_on(fm_core::ops::rename(&target, &new_name.to_string())) {
            eprintln!("rename failed: {e}");
            self.as_mut().error_occurred(QString::from(&format!(
                "Couldn't rename \"{}\": {e}",
                old_name.to_string()
            )));
        }
        self.as_mut().refresh_entries_diff();
    }

    fn delete_entry(mut self: core::pin::Pin<&mut Self>, name: &QString) {
        let current = PathBuf::from(self.current_path.to_string());
        let target = current.join(name.to_string());
        if let Err(e) = runtime().block_on(fm_core::trash::move_to_trash(&target)) {
            eprintln!("delete_entry failed: {e}");
            self.as_mut().error_occurred(QString::from(&format!(
                "Couldn't delete \"{}\": {e}",
                name.to_string()
            )));
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
            for target in targets {
                if let Err(e) = fm_core::trash::move_to_trash(&target).await {
                    eprintln!("delete_selection failed for {}: {e}", target.display());
                }
            }
            let _ = qt_thread.queue(move |mut model| {
                model.as_mut().set_is_busy(false);
                model.as_mut().refresh_entries_diff();
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
    fn refresh_entries_diff(mut self: core::pin::Pin<&mut Self>) {
        let current = PathBuf::from(self.current_path.to_string());
        let mut new_entries = runtime().block_on(gather_entries(&current));
        sort_entries(
            &mut new_entries,
            &self.sort_key.to_string(),
            self.sort_ascending,
        );
        self.as_mut().apply_entries_diff(new_entries);
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
            self.as_mut().end_reset_model();
            return;
        }

        let old_entries = self.entries.clone();
        let parent = cxx_qt_lib::QModelIndex::default();

        // Phase 1: remove rows whose entry no longer exists, highest index
        // first so earlier indices stay valid as we go.
        let mut remove_indices: Vec<usize> = old_entries
            .iter()
            .enumerate()
            .filter(|(_, old)| !new_entries.iter().any(|n| same_entry(n, old)))
            .map(|(i, _)| i)
            .collect();
        remove_indices.sort_unstable();
        for &idx in remove_indices.iter().rev() {
            self.as_mut()
                .begin_remove_rows(&parent, idx as i32, idx as i32);
            self.as_mut().rust_mut().entries.remove(idx);
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
        if let Err(e) = runtime().block_on(fm_core::ops::duplicate(&target)) {
            eprintln!("duplicate_entry failed: {e}");
            self.as_mut().error_occurred(QString::from(&format!(
                "Couldn't duplicate \"{}\": {e}",
                name.to_string()
            )));
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
            for target in targets {
                if let Err(e) = fm_core::ops::duplicate(&target).await {
                    eprintln!("duplicate_selection failed for {}: {e}", target.display());
                }
            }
            let _ = qt_thread.queue(move |mut model| {
                model.as_mut().set_is_busy(false);
                model.as_mut().refresh_entries_diff();
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

        // Computed synchronously, up front — one combined denominator for
        // the whole batch (cheap relative to the actual copy), so the
        // "done / total" display starts with a real number even for a
        // multi-item paste.
        let total: u64 = sources.iter().map(|src| fm_core::ops::path_size(src)).sum();

        self.as_mut().set_is_busy(true);
        self.as_mut().set_busy_label(QString::from(if is_cut {
            "Moving…"
        } else {
            "Copying…"
        }));
        self.as_mut().set_transfer_done_bytes(0);
        self.as_mut().set_transfer_total_bytes(total as i64);
        self.as_mut().set_transfer_speed_label(QString::from(""));

        // A cut clears the whole clipboard after pasting once; a copy can
        // be pasted repeatedly — same rule as the single-item version this
        // replaces, just applied to the whole batch.
        if is_cut {
            self.as_mut().rust_mut().clipboard_paths = Vec::new();
        }

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

        runtime().spawn(async move {
            let mut last_error = None;
            for src in sources {
                let Some(file_name) = src.file_name().map(|n| n.to_os_string()) else {
                    continue;
                };
                let dest = unique_paste_destination(&dest_dir, std::path::Path::new(&file_name));
                let result = if is_cut {
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
                if let Err(e) = result {
                    eprintln!("paste_entry failed for {}: {e}", src.display());
                    last_error = Some(e);
                }
            }

            let _ = qt_thread.queue(move |mut model| {
                if let Some(e) = last_error {
                    eprintln!("paste_entry: at least one item in the batch failed: {e}");
                }
                model.as_mut().set_is_busy(false);
                model.as_mut().set_transfer_done_bytes(0);
                model.as_mut().set_transfer_total_bytes(0);
                model.as_mut().refresh_entries_diff();
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
                // so `idx` must be mapped through matching_indices before it
                // can name a row. Emitting dataChanged with the raw entries
                // index pointed at the wrong row whenever any hidden file
                // preceded this entry in sort order — the delegate that was
                // actually waiting never heard its thumbnail was ready, so
                // in any folder containing a dotfile, thumbnails silently
                // never appeared. If the entry is itself filtered out right
                // now, there's no row to notify; the stored thumbnail_path
                // is still picked up by data() whenever it becomes visible.
                let matching = matching_indices(
                    &model.entries,
                    &model.search_query.to_string(),
                    model.show_hidden,
                );
                let Some(row) = matching.iter().position(|&i| i == idx) else {
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
