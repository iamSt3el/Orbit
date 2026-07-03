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
        let refresh_path = QString::from(&current.display().to_string());
        self.as_mut().navigate(&refresh_path);
    }

    fn rename_entry(mut self: core::pin::Pin<&mut Self>, old_name: &QString, new_name: &QString) {
        let current = PathBuf::from(self.current_path.to_string());
        let target = current.join(old_name.to_string());
        if let Err(e) = runtime().block_on(fm_core::ops::rename(&target, &new_name.to_string())) {
            eprintln!("rename failed: {e}");
        }
        let refresh_path = QString::from(&current.display().to_string());
        self.as_mut().navigate(&refresh_path);
    }

    fn delete_entry(mut self: core::pin::Pin<&mut Self>, name: &QString) {
        let current = PathBuf::from(self.current_path.to_string());
        let target = current.join(name.to_string());
        if let Err(e) = runtime().block_on(fm_core::trash::move_to_trash(&target)) {
            eprintln!("delete_entry failed: {e}");
        }
        let refresh_path = QString::from(&current.display().to_string());
        self.as_mut().navigate(&refresh_path);
    }

    fn open_entry(self: core::pin::Pin<&mut Self>, name: &QString) {
        let current = PathBuf::from(self.current_path.to_string());
        let target = current.join(name.to_string());
        if let Err(e) = runtime().block_on(fm_core::ops::open_file(&target)) {
            eprintln!("open_entry failed: {e}");
        }
    }
}
