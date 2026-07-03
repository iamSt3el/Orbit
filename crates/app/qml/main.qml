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
