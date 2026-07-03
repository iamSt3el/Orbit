use cxx_qt_build::{CxxQtBuilder, QmlFile, QmlModule};

fn main() {
    CxxQtBuilder::new_qml_module(
        QmlModule::new("com.filemanager.app")
            .qml_files(["qml/main.qml"])
            .qml_file(QmlFile::from("qml/tokens/Color.qml").singleton(true))
            .qml_file(QmlFile::from("qml/tokens/Type.qml").singleton(true))
            .qml_file(QmlFile::from("qml/tokens/Shape.qml").singleton(true))
            .qml_file(QmlFile::from("qml/tokens/Elevation.qml").singleton(true))
            .qml_file(QmlFile::from("qml/tokens/Motion.qml").singleton(true)),
    )
    .file("src/file_list_model.rs")
    .qt_module("Gui")
    .build();
}
