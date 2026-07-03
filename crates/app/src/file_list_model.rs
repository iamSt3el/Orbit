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
        type FileListModel = super::FileListModelRust;
    }

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
    }
}

use cxx_qt::CxxQtType;
use cxx_qt_lib::{QByteArray, QHash, QHashPair_i32_QByteArray, QString, QVariant};
use std::path::PathBuf;
use std::sync::OnceLock;

// One Tokio runtime shared across all invokables, instead of building and
// tearing one down on every call. Safe because cxx-qt invokables always run
// on the Qt main thread, one at a time — never concurrently.
fn runtime() -> &'static tokio::runtime::Runtime {
    static RUNTIME: OnceLock<tokio::runtime::Runtime> = OnceLock::new();
    RUNTIME.get_or_init(|| {
        tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .expect("failed to create Tokio runtime")
    })
}

pub struct FileListModelRust {
    entries: Vec<fm_core::FileEntry>,
    current_path: QString,
    home_path: QString,
    downloads_path: QString,
    documents_path: QString,
    trash_path: QString,
}

fn path_or_empty(path: Option<PathBuf>) -> QString {
    QString::from(&path.map(|p| p.display().to_string()).unwrap_or_default())
}

impl Default for FileListModelRust {
    fn default() -> Self {
        Self {
            entries: Vec::new(),
            current_path: QString::from(""),
            home_path: path_or_empty(fm_core::paths::home_dir()),
            downloads_path: path_or_empty(fm_core::paths::download_dir()),
            documents_path: path_or_empty(fm_core::paths::document_dir()),
            trash_path: path_or_empty(fm_core::paths::trash_dir()),
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
    entries.sort_by(|a, b| match (a.is_dir, b.is_dir) {
        (true, false) => std::cmp::Ordering::Less,
        (false, true) => std::cmp::Ordering::Greater,
        _ => a.name.cmp(&b.name),
    });
    entries
}

impl qobject::FileListModel {
    fn row_count(&self, _parent: &cxx_qt_lib::QModelIndex) -> i32 {
        self.entries.len() as i32
    }

    fn data(&self, index: &cxx_qt_lib::QModelIndex, role: i32) -> QVariant {
        let row = index.row();
        if row < 0 || row as usize >= self.entries.len() {
            return QVariant::default();
        }
        let entry = &self.entries[row as usize];
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
        let entries = runtime().block_on(gather_entries(&path_buf));

        self.as_mut().begin_reset_model();
        self.as_mut().rust_mut().entries = entries;
        self.as_mut().end_reset_model();
        self.as_mut()
            .set_current_path(QString::from(&path_buf.display().to_string()));
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
        let new_entries = runtime().block_on(gather_entries(&current));
        self.as_mut().apply_entries_diff(new_entries);
    }

    fn apply_entries_diff(mut self: core::pin::Pin<&mut Self>, new_entries: Vec<fm_core::FileEntry>) {
        fn same_entry(a: &fm_core::FileEntry, b: &fm_core::FileEntry) -> bool {
            a.name == b.name && a.is_dir == b.is_dir
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
