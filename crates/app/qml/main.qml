import QtQuick
import QtQuick.Window
import com.filemanager.app 1.0

Window {
    id: window
    width: 900
    height: 650
    visible: true
    title: "File Manager"
    color: Color.scheme.surface

    FileListModel {
        id: fileModel

        Component.onCompleted: navigate(Qt.application.arguments.length > 1
            ? Qt.application.arguments[1]
            : "/home")
    }

    function parentPath(path) {
        var idx = path.lastIndexOf("/")
        if (idx <= 0) {
            return "/"
        }
        return path.substring(0, idx)
    }

    Column {
        anchors.fill: parent

        TopAppBar {
            width: parent.width
            title: fileModel.currentPath ? fileModel.currentPath : ""
            showBackButton: fileModel.currentPath && fileModel.currentPath !== "/"
            onBackClicked: fileModel.navigate(window.parentPath(fileModel.currentPath))
        }

        Item {
            width: parent.width
            height: parent.height - 64

            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                Rectangle {
                    id: newFolderRow
                    width: parent.width
                    height: 56
                    radius: Shape.large
                    color: Color.scheme.surfaceContainerHigh

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 8
                        spacing: 12

                        Rectangle {
                            width: 220
                            height: 40
                            radius: Shape.small
                            color: Color.scheme.surfaceContainerHighest
                            border.width: newFolderName.activeFocus ? 2 : 1
                            border.color: newFolderName.activeFocus ? Color.scheme.primary : Color.scheme.outline
                            anchors.verticalCenter: parent.verticalCenter

                            Behavior on border.width { NumberAnimation { duration: Motion.standard.duration } }

                            TextInput {
                                id: newFolderName
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                verticalAlignment: TextInput.AlignVCenter
                                color: Color.scheme.surfaceText
                                font.family: Type.bodyLarge.family
                                font.pixelSize: Type.bodyLarge.size
                                clip: true

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: newFolderName.text.length === 0
                                    text: "New folder name"
                                    color: Color.scheme.surfaceVariantText
                                    font.family: Type.bodyLarge.family
                                    font.pixelSize: Type.bodyLarge.size
                                }
                            }
                        }

                        Button {
                            variant: "tonal"
                            text: "Create"
                            icon: "create_new_folder"
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: {
                                if (newFolderName.text.length > 0) {
                                    fileModel.createFolder(newFolderName.text)
                                    newFolderName.text = ""
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: parent.height - newFolderRow.height - parent.spacing
                    radius: Shape.large
                    color: Color.scheme.surfaceContainerLow
                    clip: true

                    ListView {
                        anchors.fill: parent
                        anchors.margins: 4
                        model: fileModel
                        spacing: 2
                        reuseItems: true
                        cacheBuffer: 400
                        delegate: FileListItem {}
                    }
                }
            }
        }
    }
}
