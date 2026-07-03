use cxx_qt_build::{CxxQtBuilder, QmlModule};

fn main() {
    CxxQtBuilder::new_qml_module(
        QmlModule::new("com.filemanager.app").qml_files(["qml/main.qml"]),
    )
    .qt_module("Gui")
    .build();
}
