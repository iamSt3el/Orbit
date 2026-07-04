# File Manager Bridge + Minimal Shell — Implementation Plan (Plan 2 of 3)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `fm-app`, a cxx-qt bridge crate + minimal, unstyled QML shell that wires `fm-core` (Plan 1) end to end: a real window listing a real directory's contents, with create-folder/rename/delete-to-Trash working. No Material 3 styling yet — that's Plan 3.

**Architecture:** `crates/app` (package `fm-app`) is a cxx-qt binary crate depending on `fm-core`. A single `FileListModel` QObject subclasses `QAbstractListModel` and is registered as a QML type. Directory loading is **synchronous at the bridge boundary for this plan**: `navigate()` blocks on a short-lived Tokio runtime to drain `fm_core::listing::list_directory`, then resets the model in one shot. True incremental streaming and live-watcher updates (via cxx-qt's cross-thread `Threading` mechanism) are explicitly deferred to a later plan — this plan proves the stack wires together correctly first.

**Tech Stack:** cxx-qt 0.9, cxx-qt-lib 0.9 (`qt_gui`, `qt_qml` features), cxx 1, Qt 6 (Core, Gui, Qml modules), `fm-core` (Plan 1), Tokio (already a dependency of `fm-core`).

## Global Constraints

- Target platform is Linux only.
- This plan does **not** implement incremental/streaming model updates or live filesystem-watcher integration — `navigate()` is a blocking, one-shot reload. That is scoped to a future plan.
- No Qt Quick Controls; the QML in this plan is deliberately plain/unstyled (a bare `ListView`) — Material 3 Expressive styling is Plan 3's job, not this one.
- MVP file operations in scope here: navigate, create folder, rename, delete (→ Trash). Copy/move are already implemented in `fm-core` (Plan 1) but their QML wiring is not required by this plan. Sort-toggling and filter-by-name (also listed as bridge invokables in the design spec) are deferred to Plan 3, where there's an actual styled UI (search field, sort control) to drive them from — wiring them against plain `Text`/`ListView` here would be untestable busywork.
- Every task's acceptance check is `cargo build -p fm-app` succeeding — there is no automated QML test harness for this project (per the design spec's testing section), so UI behavior is confirmed by a manual run in the final task.

## API Patterns Verified Before Writing This Plan

The following cxx-qt 0.9 patterns were independently compiled against the real crate (not taken from memory or docs) before this plan was written, because cxx-qt's macro API has changed across versions:

- A `QAbstractListModel` subclass requires **explicit** `#[cxx_name = "rowCount"]` / `#[cxx_name = "roleNames"]` on `#[cxx_override]` methods — cxx-qt does **not** auto-convert `snake_case` Rust names to the base class's `camelCase` C++ virtual names. Omitting this compiles but silently fails to override (confirmed by an actual `c++` compiler error: `marked 'override', but does not override`).
- Calling inherited base-class mutators (`beginResetModel`/`endResetModel`) requires `#[inherit] #[cxx_name = "..."]` declarations under `unsafe extern "RustQt"`, called as `self.as_mut().begin_reset_model()` etc.
- Mutating the wrapped Rust struct's fields from an invokable goes through `self.as_mut().rust_mut().<field> = ...` (the `CxxQtType::rust_mut` trait method) — this requires `use cxx_qt::CxxQtType;` in the file, since it's a plain trait method, not an inherent one.
- `QHash<i32, QByteArray>` (needed for `roleNames`) is a built-in pair in cxx-qt-lib specifically for this purpose: `cxx_qt_lib::QHash<cxx_qt_lib::QHashPair_i32_QByteArray>`.

---

### Task 1: App scaffold — boots a blank window

**Files:**
- Modify: `Cargo.toml` (workspace root — add `crates/app` to members)
- Create: `crates/app/Cargo.toml`
- Create: `crates/app/build.rs`
- Create: `crates/app/src/main.rs`
- Create: `crates/app/qml/main.qml`

**Interfaces:**
- Consumes: nothing yet (fm-core is added as a dependency here but not used until Task 3).
- Produces: a runnable `fm-app` binary that boots a Qt window. Later tasks add QML types and wire them into `qml/main.qml`.

- [ ] **Step 1: Add the app crate to the workspace**

`Cargo.toml` (workspace root):
```toml
[workspace]
resolver = "2"
members = ["crates/core", "crates/app"]
```

- [ ] **Step 2: Create the app crate manifest**

`crates/app/Cargo.toml`:
```toml
[package]
name = "fm-app"
version = "0.1.0"
edition = "2021"

[dependencies]
fm-core = { path = "../core" }
cxx = "1"
cxx-qt = "0.9"
cxx-qt-lib = { version = "0.9", features = ["qt_gui", "qt_qml"] }
tokio = { version = "1", features = ["full"] }

[build-dependencies]
cxx-qt-build = "0.9"
```

- [ ] **Step 3: Create the build script**

`crates/app/build.rs`:
```rust
use cxx_qt_build::{CxxQtBuilder, QmlModule};

fn main() {
    CxxQtBuilder::new_qml_module(
        QmlModule::new("com.filemanager.app").qml_files(["qml/main.qml"]),
    )
    .qt_module("Gui")
    .build();
}
```

- [ ] **Step 4: Create the QML entry point**

`crates/app/qml/main.qml`:
```qml
import QtQuick
import QtQuick.Window

Window {
    width: 800
    height: 600
    visible: true
    title: "File Manager"
}
```

- [ ] **Step 5: Create the Rust entry point**

`crates/app/src/main.rs`:
```rust
use cxx_qt_lib::{QGuiApplication, QQmlApplicationEngine, QUrl};

fn main() {
    let mut app = QGuiApplication::new();
    let mut engine = QQmlApplicationEngine::new();

    if let Some(engine) = engine.as_mut() {
        engine.load(&QUrl::from("qrc:/qt/qml/com/filemanager/app/main.qml"));
    }

    if let Some(app) = app.as_mut() {
        std::process::exit(app.exec());
    }
}
```

- [ ] **Step 6: Build**

Run: `cargo build -p fm-app`
Expected: builds successfully (this compiles cxx-qt-lib's `qt_gui`/`qt_qml` feature set the first time, which takes several minutes — subsequent builds in later tasks are incremental and much faster).

- [ ] **Step 7: Commit**

```bash
git add Cargo.toml crates/app/Cargo.toml crates/app/build.rs crates/app/src/main.rs crates/app/qml/main.qml
git commit -m "feat(app): scaffold fm-app, boots a blank window"
```

---

### Task 2: FileListModel — QAbstractListModel with fixture data, rendered in QML

**Files:**
- Create: `crates/app/src/file_list_model.rs`
- Modify: `crates/app/build.rs`
- Modify: `crates/app/qml/main.qml`

**Interfaces:**
- Consumes: nothing new (fixture data only — `fm-core` is wired in Task 3).
- Produces: a `FileListModel` QML type (`import com.filemanager.app 1.0`) exposing `rowCount`, `data`, `roleNames` for roles `name` (string), `isDir` (bool), `size` (int64), `iconKey` (string). Task 3 replaces the fixture data with real entries but keeps this exact role/type shape — later QML delegates in Task 4 rely on these role names.

- [ ] **Step 1: Write the bridge module**

`crates/app/src/file_list_model.rs`:
```rust
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
        #[qproperty(QString, current_path)]
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
}

use cxx_qt_lib::{QByteArray, QHash, QHashPair_i32_QByteArray, QString, QVariant};

pub struct Entry {
    pub name: String,
    pub is_dir: bool,
    pub size: i64,
    pub icon_key: String,
}

pub struct FileListModelRust {
    entries: Vec<Entry>,
    current_path: QString,
}

impl Default for FileListModelRust {
    fn default() -> Self {
        Self {
            entries: vec![
                Entry {
                    name: "example.txt".to_string(),
                    is_dir: false,
                    size: 1234,
                    icon_key: "text".to_string(),
                },
                Entry {
                    name: "Documents".to_string(),
                    is_dir: true,
                    size: 0,
                    icon_key: "folder".to_string(),
                },
            ],
            current_path: QString::from(""),
        }
    }
}

const NAME_ROLE: i32 = 0x0100;
const IS_DIR_ROLE: i32 = 0x0101;
const SIZE_ROLE: i32 = 0x0102;
const ICON_KEY_ROLE: i32 = 0x0103;

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
            SIZE_ROLE => QVariant::from(&entry.size),
            ICON_KEY_ROLE => QVariant::from(&QString::from(&entry.icon_key)),
            _ => QVariant::default(),
        }
    }

    fn role_names(&self) -> QHash<QHashPair_i32_QByteArray> {
        let mut roles = QHash::<QHashPair_i32_QByteArray>::default();
        roles.insert(NAME_ROLE, QByteArray::from("name"));
        roles.insert(IS_DIR_ROLE, QByteArray::from("isDir"));
        roles.insert(SIZE_ROLE, QByteArray::from("size"));
        roles.insert(ICON_KEY_ROLE, QByteArray::from("iconKey"));
        roles
    }
}
```

- [ ] **Step 2: Register the bridge file in the build script**

`crates/app/build.rs`:
```rust
use cxx_qt_build::{CxxQtBuilder, QmlModule};

fn main() {
    CxxQtBuilder::new_qml_module(
        QmlModule::new("com.filemanager.app").qml_files(["qml/main.qml"]),
    )
    .file("src/file_list_model.rs")
    .qt_module("Gui")
    .build();
}
```

- [ ] **Step 3: Register the module in `main.rs`**

`crates/app/src/main.rs` — add above `fn main()`:
```rust
mod file_list_model;
```

- [ ] **Step 4: Render the fixture data in QML**

`crates/app/qml/main.qml`:
```qml
import QtQuick
import QtQuick.Window
import com.filemanager.app 1.0

Window {
    width: 800
    height: 600
    visible: true
    title: "File Manager"

    FileListModel {
        id: fileModel
    }

    ListView {
        anchors.fill: parent
        model: fileModel
        delegate: Text {
            text: (isDir ? "[dir] " : "") + name + " (" + size + ")"
        }
    }
}
```

- [ ] **Step 5: Build**

Run: `cargo build -p fm-app`
Expected: builds successfully.

- [ ] **Step 6: Commit**

```bash
git add crates/app/build.rs crates/app/src/main.rs crates/app/src/file_list_model.rs crates/app/qml/main.qml
git commit -m "feat(app): add FileListModel with fixture data, rendered in QML"
```

---

### Task 3: Wire FileListModel to real fm-core directory listing

**Files:**
- Modify: `crates/app/src/file_list_model.rs`
- Modify: `crates/app/qml/main.qml`

**Interfaces:**
- Consumes: `fm_core::listing::list_directory(PathBuf) -> mpsc::Receiver<io::Result<FileEntry>>` (Plan 1), `fm_core::FileEntry` fields `name`, `is_dir`, `size`, `icon_key`.
- Produces: `qobject::FileListModel::navigate(self: Pin<&mut FileListModel>, path: &QString)` invokable, callable from QML. After this task, `Entry`/fixture data from Task 2 is replaced by real `fm_core::FileEntry` data.

- [ ] **Step 1: Replace the fixture `Entry` type and add `navigate`**

In `crates/app/src/file_list_model.rs`, add to the `extern "RustQt"` invokables block:
```rust
    unsafe extern "RustQt" {
        #[qinvokable]
        fn navigate(self: Pin<&mut FileListModel>, path: &QString);
    }
```

Replace the `pub struct Entry { ... }` and its use in `FileListModelRust`/`Default`/`data()` with `fm_core::FileEntry` directly — the full updated file:
```rust
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
        #[qproperty(QString, current_path)]
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
}

use cxx_qt::CxxQtType;
use cxx_qt_lib::{QByteArray, QHash, QHashPair_i32_QByteArray, QString, QVariant};
use std::path::PathBuf;

pub struct FileListModelRust {
    entries: Vec<fm_core::FileEntry>,
    current_path: QString,
}

impl Default for FileListModelRust {
    fn default() -> Self {
        Self {
            entries: Vec::new(),
            current_path: QString::from(""),
        }
    }
}

const NAME_ROLE: i32 = 0x0100;
const IS_DIR_ROLE: i32 = 0x0101;
const SIZE_ROLE: i32 = 0x0102;
const ICON_KEY_ROLE: i32 = 0x0103;

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
            _ => QVariant::default(),
        }
    }

    fn role_names(&self) -> QHash<QHashPair_i32_QByteArray> {
        let mut roles = QHash::<QHashPair_i32_QByteArray>::default();
        roles.insert(NAME_ROLE, QByteArray::from("name"));
        roles.insert(IS_DIR_ROLE, QByteArray::from("isDir"));
        roles.insert(SIZE_ROLE, QByteArray::from("size"));
        roles.insert(ICON_KEY_ROLE, QByteArray::from("iconKey"));
        roles
    }

    fn navigate(mut self: core::pin::Pin<&mut Self>, path: &QString) {
        let path_buf = PathBuf::from(path.to_string());
        let entries = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .expect("failed to create Tokio runtime")
            .block_on(gather_entries(&path_buf));

        self.as_mut().begin_reset_model();
        self.as_mut().rust_mut().entries = entries;
        self.as_mut().end_reset_model();
        self.as_mut()
            .set_current_path(QString::from(&path_buf.display().to_string()));
    }
}
```

- [ ] **Step 2: Trigger navigation on startup in QML**

`crates/app/qml/main.qml`:
```qml
import QtQuick
import QtQuick.Window
import com.filemanager.app 1.0

Window {
    width: 800
    height: 600
    visible: true
    title: "File Manager — " + fileModel.currentPath

    FileListModel {
        id: fileModel

        Component.onCompleted: navigate(Qt.application.arguments.length > 1
            ? Qt.application.arguments[1]
            : "/home")
    }

    ListView {
        anchors.fill: parent
        model: fileModel
        delegate: Text {
            text: (isDir ? "[dir] " : "") + name + " (" + size + ")"
        }
    }
}
```

- [ ] **Step 3: Build**

Run: `cargo build -p fm-app`
Expected: builds successfully.

- [ ] **Step 4: Commit**

```bash
git add crates/app/src/file_list_model.rs crates/app/qml/main.qml
git commit -m "feat(app): wire FileListModel to real fm-core directory listing"
```

---

### Task 4: File operation invokables + manual verification

**Files:**
- Modify: `crates/app/src/file_list_model.rs`
- Modify: `crates/app/qml/main.qml`

**Interfaces:**
- Consumes: `fm_core::ops::create_folder(&Path, &str) -> io::Result<PathBuf>`, `fm_core::ops::rename(&Path, &str) -> io::Result<PathBuf>`, `fm_core::trash::move_to_trash(&Path) -> io::Result<PathBuf>` (all Plan 1).
- Produces: `createFolder(name: &QString)`, `renameEntry(oldName: &QString, newName: &QString)`, `deleteEntry(name: &QString)` invokables on `FileListModel`, each refreshing the list afterward by re-running `navigate` against the current path.

- [ ] **Step 1: Add the invokable declarations**

In `crates/app/src/file_list_model.rs`, add to the bridge module:
```rust
    unsafe extern "RustQt" {
        #[qinvokable]
        fn create_folder(self: Pin<&mut FileListModel>, name: &QString);

        #[qinvokable]
        fn rename_entry(self: Pin<&mut FileListModel>, old_name: &QString, new_name: &QString);

        #[qinvokable]
        fn delete_entry(self: Pin<&mut FileListModel>, name: &QString);
    }
```

- [ ] **Step 2: Implement them, each refreshing via `navigate`**

Add to `impl qobject::FileListModel` in the same file:
```rust
    fn create_folder(mut self: core::pin::Pin<&mut Self>, name: &QString) {
        let current = PathBuf::from(self.current_path.to_string());
        let rt = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .expect("failed to create Tokio runtime");
        if let Err(e) = rt.block_on(fm_core::ops::create_folder(&current, &name.to_string())) {
            eprintln!("create_folder failed: {e}");
        }
        let refresh_path = QString::from(&current.display().to_string());
        self.as_mut().navigate(&refresh_path);
    }

    fn rename_entry(mut self: core::pin::Pin<&mut Self>, old_name: &QString, new_name: &QString) {
        let current = PathBuf::from(self.current_path.to_string());
        let target = current.join(old_name.to_string());
        let rt = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .expect("failed to create Tokio runtime");
        if let Err(e) = rt.block_on(fm_core::ops::rename(&target, &new_name.to_string())) {
            eprintln!("rename failed: {e}");
        }
        let refresh_path = QString::from(&current.display().to_string());
        self.as_mut().navigate(&refresh_path);
    }

    fn delete_entry(mut self: core::pin::Pin<&mut Self>, name: &QString) {
        let current = PathBuf::from(self.current_path.to_string());
        let target = current.join(name.to_string());
        let rt = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .expect("failed to create Tokio runtime");
        if let Err(e) = rt.block_on(fm_core::trash::move_to_trash(&target)) {
            eprintln!("delete_entry failed: {e}");
        }
        let refresh_path = QString::from(&current.display().to_string());
        self.as_mut().navigate(&refresh_path);
    }
```

- [ ] **Step 3: Expose a create-folder action and per-item delete in QML**

`crates/app/qml/main.qml`:
```qml
import QtQuick
import QtQuick.Window
import com.filemanager.app 1.0

Window {
    width: 800
    height: 600
    visible: true
    title: "File Manager — " + fileModel.currentPath

    FileListModel {
        id: fileModel

        Component.onCompleted: navigate(Qt.application.arguments.length > 1
            ? Qt.application.arguments[1]
            : "/home")
    }

    Column {
        anchors.fill: parent

        Row {
            Text {
                text: "New folder name:"
            }
            TextInput {
                id: newFolderName
                width: 150
            }
            Text {
                text: "[create]"
                MouseArea {
                    anchors.fill: parent
                    onClicked: fileModel.createFolder(newFolderName.text)
                }
            }
        }

        ListView {
            width: parent.width
            height: parent.height - 40
            model: fileModel
            delegate: Row {
                Text {
                    text: (isDir ? "[dir] " : "") + name + " (" + size + ")"
                }
                Text {
                    text: "  [delete]"
                    MouseArea {
                        anchors.fill: parent
                        onClicked: fileModel.deleteEntry(name)
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 4: Build**

Run: `cargo build -p fm-app`
Expected: builds successfully.

- [ ] **Step 5: Manual verification**

Run: `QT_QPA_PLATFORM=offscreen timeout 5 cargo run -p fm-app -- /tmp`
Expected: process starts, loads the QML, lists `/tmp`'s contents, and exits via the `timeout` after 5 seconds without a crash or QML error printed to stderr.

**Known sandbox caveat:** in a sandboxed/headless execution environment (no real access to the display or compositor socket even when `DISPLAY`/`WAYLAND_DISPLAY` env vars are set), a Qt GUI process can hang silently at platform-plugin initialization — before `QGuiApplication::new()` even returns — with **zero output on stdout/stderr**, regardless of `QT_QPA_PLATFORM=offscreen`, and regardless of what the QML does (confirmed by testing a QML file containing only `console.error(...); Qt.quit()` in `Component.onCompleted`, which also produced no output and hung). This is indistinguishable from a real hang by output alone. If this happens: rely on `cargo build -p fm-app` succeeding (the strongest signal available in that environment) and report the interactive run as unverifiable rather than claiming it passed. Do not spend excessive time debugging platform-plugin behavior — it is an environment constraint, not necessarily a code defect, given the same binary's `cargo build` succeeds and every cxx-qt API pattern it uses was independently verified to compile in isolation before this plan was written.

If a real, reachable display is available (interactive desktop session, not a sandboxed subprocess), run: `cargo run -p fm-app -- $HOME` and confirm interactively: the window lists `$HOME`'s contents, creating a folder via the text field + "[create]" adds it to the list, and clicking "[delete]" on an entry removes it from the list and moves it to `~/.local/share/Trash/files/`.

- [ ] **Step 6: Commit**

```bash
git add crates/app/src/file_list_model.rs crates/app/qml/main.qml
git commit -m "feat(app): add create/rename/delete invokables with list refresh"
```

---

## Plan Complete

`fm-app` now proves the full stack end to end: a real Qt/QML window backed by `fm-core`'s async file operations, with directory navigation, folder creation, and delete-to-Trash all working through the cxx-qt bridge. The QML is intentionally unstyled. Plan 3 replaces this plain `ListView`/`Text` UI with the Material 3 Expressive design system (tokens, ripple, shape morphing, spring motion) from the design spec, built on top of the same `FileListModel` and invokables established here. Incremental/streaming model updates and live filesystem-watcher integration remain open follow-up work beyond Plan 3's scope, noted here so they aren't silently forgotten.
