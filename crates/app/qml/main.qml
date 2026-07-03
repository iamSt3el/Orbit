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

    property string viewMode: "list" // "list" | "grid"

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

    // Wheel notches deliver angleDelta in eighths of a degree — 120 units
    // is one physical "click" of a standard mouse wheel. Scrolling by a
    // fixed, larger-than-default number of pixels per notch here (instead
    // of relying on Flickable's own small default step) is what "increase
    // the scroll distance" means in practice.
    function applyWheelScroll(view, wheel) {
        var maxY = Math.max(0, view.contentHeight - view.height)
        view.contentY = Math.max(0, Math.min(maxY, view.contentY - (wheel.angleDelta.y / 120) * 180))
        wheel.accepted = true
    }

    Column {
        anchors.fill: parent

        TopAppBar {
            width: parent.width
            title: fileModel.currentPath ? fileModel.currentPath : ""
            showBackButton: fileModel.currentPath && fileModel.currentPath !== "/"
            viewMode: window.viewMode
            onBackClicked: fileModel.navigate(window.parentPath(fileModel.currentPath))
            onListViewRequested: window.viewMode = "list"
            onGridViewRequested: window.viewMode = "grid"
        }

        Item {
            width: parent.width
            height: parent.height - 72

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

                    Component {
                        id: listComponent

                        ListView {
                            id: listView
                            model: fileModel
                            spacing: 2
                            reuseItems: true
                            cacheBuffer: 400
                            acceptedButtons: Qt.NoButton
                            delegate: FileListItem {}

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.NoButton
                                onWheel: (wheel) => window.applyWheelScroll(listView, wheel)
                            }
                        }
                    }

                    Component {
                        id: gridComponent

                        GridView {
                            id: gridView
                            model: fileModel
                            cellWidth: 110
                            cellHeight: 110
                            reuseItems: true
                            cacheBuffer: 400
                            acceptedButtons: Qt.NoButton
                            delegate: FileGridItem {}

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.NoButton
                                onWheel: (wheel) => window.applyWheelScroll(gridView, wheel)
                            }
                        }
                    }

                    Loader {
                        anchors.fill: parent
                        anchors.margins: 4
                        sourceComponent: window.viewMode === "grid" ? gridComponent : listComponent
                    }
                }
            }
        }
    }
}
