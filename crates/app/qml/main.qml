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
