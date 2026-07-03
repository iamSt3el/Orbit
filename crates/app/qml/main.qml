import QtQuick
import QtQuick.Window
import com.filemanager.app 1.0

Window {
    id: window
    width: 1000
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

        Row {
            width: parent.width
            height: parent.height - 72

            Sidebar {
                height: parent.height
                fileModel: fileModel
                currentPath: fileModel.currentPath ? fileModel.currentPath : ""
            }

            Item {
                id: contentArea
                width: parent.width - 220
                height: parent.height

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 16
                    radius: Shape.large
                    color: Color.scheme.surfaceContainerLow
                    clip: true

                    Component {
                        id: listComponent

                        ListView {
                            id: listView
                            anchors.fill: parent
                            anchors.margins: 4
                            anchors.rightMargin: 14
                            model: fileModel
                            spacing: 2
                            reuseItems: true
                            cacheBuffer: 400
                            acceptedButtons: Qt.NoButton
                            delegate: FileListItem {}

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.RightButton
                                onWheel: (wheel) => window.applyWheelScroll(listView, wheel)
                                onClicked: (mouse) => contextMenu.popup(mouse.x + 20, mouse.y + 20)
                            }

                            ScrollBar {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.rightMargin: -12
                                flickable: listView
                            }
                        }
                    }

                    Component {
                        id: gridComponent

                        GridView {
                            id: gridView
                            anchors.fill: parent
                            anchors.margins: 4
                            anchors.rightMargin: 14
                            model: fileModel
                            readonly property int minCellWidth: 110
                            cellWidth: width / Math.max(1, Math.floor(width / minCellWidth))
                            cellHeight: 120
                            reuseItems: true
                            cacheBuffer: 400
                            acceptedButtons: Qt.NoButton
                            delegate: FileGridItem {}

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.RightButton
                                onWheel: (wheel) => window.applyWheelScroll(gridView, wheel)
                                onClicked: (mouse) => contextMenu.popup(mouse.x + 20, mouse.y + 20)
                            }

                            ScrollBar {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.rightMargin: -12
                                flickable: gridView
                            }
                        }
                    }

                    Loader {
                        anchors.fill: parent
                        sourceComponent: window.viewMode === "grid" ? gridComponent : listComponent
                    }
                }

                ContextMenu {
                    id: contextMenu
                    onNewFolderRequested: newFolderDialog.open()
                }

                NewFolderDialog {
                    id: newFolderDialog
                    onAccepted: (name) => fileModel.createFolder(name)
                }
            }
        }
    }
}
