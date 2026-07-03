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
