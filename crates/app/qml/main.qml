import QtQuick
import QtQuick.Window
import com.filemanager.app 1.0

Window {
    id: window
    width: 800
    height: 600
    visible: true
    title: "File Manager"
    color: Color.scheme.surface

    FileListModel {
        id: fileModel

        Component.onCompleted: navigate(Qt.application.arguments.length > 1
            ? Qt.application.arguments[1]
            : "/home")
    }

    Column {
        anchors.fill: parent

        TopAppBar {
            width: parent.width
            title: fileModel.currentPath
        }

        Row {
            width: parent.width
            height: 56
            spacing: 8
            leftPadding: 16
            topPadding: 8
            bottomPadding: 8

            TextInput {
                id: newFolderName
                width: 200
                anchors.verticalCenter: parent.verticalCenter
                color: Color.scheme.onSurface
                font.family: Type.bodyLarge.family
                font.pixelSize: Type.bodyLarge.size
            }

            Button {
                variant: "tonal"
                text: "New folder"
                icon: "create_new_folder"
                anchors.verticalCenter: parent.verticalCenter
                onClicked: fileModel.createFolder(newFolderName.text)
            }
        }

        ListView {
            width: parent.width
            height: parent.height - 64 - 56
            model: fileModel
            delegate: FileListItem {
                fileModel: fileModel
            }
        }
    }
}
