mod file_list_model;

use cxx_qt_lib::{QGuiApplication, QQmlApplicationEngine, QUrl};

// Rust-side allocations (most importantly the transient full-resolution
// image decode buffers behind thumbnail generation — tens of MB each) go
// through mimalloc instead of glibc malloc. glibc hoards freed multi-MB
// chunks in its per-thread arenas indefinitely — measured ~100MB of
// "system bytes" with only ~34MB "in use" after browsing a wallpaper
// folder, unrecoverable even via malloc_trim — while mimalloc purges
// freed pages back to the OS within about a second. Qt's C++ side keeps
// its own allocator; this only governs Rust.
#[global_allocator]
static GLOBAL: mimalloc::MiMalloc = mimalloc::MiMalloc;

fn main() {
    fm_core::paths::migrate_legacy_config_dir();
    cxx_qt::init_qml_module!("com.filemanager.app");

    let mut app = QGuiApplication::new();
    let mut engine = QQmlApplicationEngine::new();

    if let Some(engine) = engine.as_mut() {
        engine.load(&QUrl::from("qrc:/qt/qml/com/filemanager/app/qml/main.qml"));
    }

    if let Some(app) = app.as_mut() {
        std::process::exit(app.exec());
    }
}
