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
    }

    unsafe extern "RustQt" {
        #[qinvokable]
        fn navigate(self: Pin<&mut FileListModel>, path: &QString);
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

        #[qinvokable]
        #[cxx_name = "openEntry"]
        fn open_entry(self: Pin<&mut FileListModel>, name: &QString);

        #[qinvokable]
        #[cxx_name = "duplicateEntry"]
        fn duplicate_entry(self: Pin<&mut FileListModel>, name: &QString);

        #[qinvokable]
        #[cxx_name = "openTerminalHere"]
        fn open_terminal_here(self: Pin<&mut FileListModel>);

        #[qinvokable]
        #[cxx_name = "copyEntry"]
        fn copy_entry(self: Pin<&mut FileListModel>, name: &QString);

        #[qinvokable]
        #[cxx_name = "cutEntry"]
        fn cut_entry(self: Pin<&mut FileListModel>, name: &QString);

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
    clipboard_path: Option<PathBuf>,
    clipboard_is_cut: bool,
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
            clipboard_path: None,
            clipboard_is_cut: false,
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
        roles
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
        // A search filter from the previous directory shouldn't silently
        // carry over and hide entries in the new one.
        self.as_mut().rust_mut().search_query = QString::from("");
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
        }
        self.as_mut().refresh_entries_diff();
    }

    fn rename_entry(mut self: core::pin::Pin<&mut Self>, old_name: &QString, new_name: &QString) {
        let current = PathBuf::from(self.current_path.to_string());
        let target = current.join(old_name.to_string());
        if let Err(e) = runtime().block_on(fm_core::ops::rename(&target, &new_name.to_string())) {
            eprintln!("rename failed: {e}");
        }
        self.as_mut().refresh_entries_diff();
    }

    fn delete_entry(mut self: core::pin::Pin<&mut Self>, name: &QString) {
        let current = PathBuf::from(self.current_path.to_string());
        let target = current.join(name.to_string());
        if let Err(e) = runtime().block_on(fm_core::trash::move_to_trash(&target)) {
            eprintln!("delete_entry failed: {e}");
        }
        self.as_mut().refresh_entries_diff();
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

    fn open_entry(self: core::pin::Pin<&mut Self>, name: &QString) {
        let current = PathBuf::from(self.current_path.to_string());
        let target = current.join(name.to_string());
        if let Err(e) = runtime().block_on(fm_core::ops::open_file(&target)) {
            eprintln!("open_entry failed: {e}");
        }
    }

    fn duplicate_entry(mut self: core::pin::Pin<&mut Self>, name: &QString) {
        let current = PathBuf::from(self.current_path.to_string());
        let target = current.join(name.to_string());
        if let Err(e) = runtime().block_on(fm_core::ops::duplicate(&target)) {
            eprintln!("duplicate_entry failed: {e}");
        }
        self.as_mut().refresh_entries_diff();
    }

    fn open_terminal_here(self: core::pin::Pin<&mut Self>) {
        let current = PathBuf::from(self.current_path.to_string());
        if let Err(e) = runtime().block_on(fm_core::ops::open_terminal(&current)) {
            eprintln!("open_terminal_here failed: {e}");
        }
    }

    fn copy_entry(mut self: core::pin::Pin<&mut Self>, name: &QString) {
        let current = PathBuf::from(self.current_path.to_string());
        self.as_mut().rust_mut().clipboard_path = Some(current.join(name.to_string()));
        self.as_mut().rust_mut().clipboard_is_cut = false;
    }

    fn cut_entry(mut self: core::pin::Pin<&mut Self>, name: &QString) {
        let current = PathBuf::from(self.current_path.to_string());
        self.as_mut().rust_mut().clipboard_path = Some(current.join(name.to_string()));
        self.as_mut().rust_mut().clipboard_is_cut = true;
    }

    fn can_paste(&self) -> bool {
        self.clipboard_path.is_some()
    }

    fn paste_entry(mut self: core::pin::Pin<&mut Self>) {
        let Some(src) = self.clipboard_path.clone() else {
            return;
        };
        let is_cut = self.clipboard_is_cut;
        let dest_dir = PathBuf::from(self.current_path.to_string());
        let Some(file_name) = src.file_name() else {
            return;
        };
        let dest = unique_paste_destination(&dest_dir, std::path::Path::new(file_name));

        // Computed synchronously, up front — cheap relative to the actual
        // copy, and needed immediately so the "done / total" display has a
        // real denominator from the very first frame instead of starting
        // at "0 B / 0 B".
        let total = fm_core::ops::path_size(&src);

        self.as_mut().set_is_busy(true);
        self.as_mut().set_busy_label(QString::from(if is_cut {
            "Moving…"
        } else {
            "Copying…"
        }));
        self.as_mut().set_transfer_done_bytes(0);
        self.as_mut().set_transfer_total_bytes(total as i64);
        self.as_mut().set_transfer_speed_label(QString::from(""));

        // A cut clears itself from the clipboard after pasting once; a
        // copy can be pasted repeatedly, matching every other file
        // manager's clipboard behavior.
        if is_cut {
            self.as_mut().rust_mut().clipboard_path = None;
        }

        let done_counter = std::sync::Arc::new(std::sync::atomic::AtomicU64::new(0));
        let (progress_tx, mut progress_rx) = tokio::sync::mpsc::unbounded_channel::<u64>();

        // Progress relay: reads every update off the channel but only
        // forwards a throttled subset to the Qt thread, so a fast local
        // copy doesn't flood qt_thread.queue() with dozens of calls per
        // second for updates the UI couldn't render anyway.
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
            let result = if is_cut {
                fm_core::ops::move_entry_with_progress(&src, &dest, done_counter, progress_tx)
                    .await
            } else {
                fm_core::ops::copy_with_progress(src.clone(), dest.clone(), done_counter, progress_tx)
                    .await
            };
            let _ = qt_thread.queue(move |mut model| {
                if let Err(e) = result {
                    eprintln!("paste_entry failed: {e}");
                }
                model.as_mut().set_is_busy(false);
                model.as_mut().set_transfer_done_bytes(0);
                model.as_mut().set_transfer_total_bytes(0);
                model.as_mut().refresh_entries_diff();
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
