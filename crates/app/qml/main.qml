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
    property string _pendingDeleteName: ""

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

    // Invisible helper for "Copy Path" — TextEdit.copy() writes the current
    // selection straight to the system clipboard, no extra module needed.
    TextEdit {
        id: clipboardHelper
        visible: false
        function copyText(text) {
            clipboardHelper.text = text
            clipboardHelper.selectAll()
            clipboardHelper.copy()
        }
    }

    // Layout modeled on the user's quickshell "Nebula" settings app: a top
    // bar, then a single unified card (surfaceContainer) holding the
    // sidebar and content side by side with no gap between them — the
    // sidebar's own surfaceContainerHigh fill and independent corner
    // radius is what visually separates it, not a literal gutter.
    Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        TopAppBar {
            width: parent.width
            title: fileModel.currentPath ? fileModel.currentPath : ""
            showBackButton: fileModel.currentPath && fileModel.currentPath !== "/"
            viewMode: window.viewMode
            onBackClicked: fileModel.navigate(window.parentPath(fileModel.currentPath))
            onListViewRequested: window.viewMode = "list"
            onGridViewRequested: window.viewMode = "grid"
        }

        Rectangle {
            width: parent.width
            height: parent.height - 64 - 12
            radius: 20
            color: Color.scheme.surfaceContainer
            clip: true

            Row {
                anchors.fill: parent
                spacing: 0

                Sidebar {
                    height: parent.height
                    fileModel: fileModel
                    currentPath: fileModel.currentPath ? fileModel.currentPath : ""
                }

                Item {
                    id: contentArea
                    width: parent.width - 200
                    height: parent.height

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
                            delegate: FileListItem {
                                onContextMenuRequested: (x, y) =>
                                    itemContextMenu.popup(x, y, name, isDir, size, modified, mimeType, permissions)
                            }

                            MouseArea {
                                // Stacked below the delegates (which live inside
                                // listView's contentItem) so a right-click over an
                                // item reaches FileListItem's own MouseArea first;
                                // this one only fires for clicks that miss every
                                // delegate, i.e. genuinely empty space.
                                id: listBackgroundArea
                                z: -1
                                anchors.fill: parent
                                acceptedButtons: Qt.RightButton
                                onWheel: (wheel) => window.applyWheelScroll(listView, wheel)
                                onClicked: (mouse) => {
                                    var scenePos = listBackgroundArea.mapToItem(null, mouse.x, mouse.y)
                                    contextMenu.popup(scenePos.x, scenePos.y)
                                }
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
                            cellHeight: 132
                            reuseItems: true
                            cacheBuffer: 400
                            acceptedButtons: Qt.NoButton
                            delegate: FileGridItem {
                                onContextMenuRequested: (x, y) =>
                                    itemContextMenu.popup(x, y, name, isDir, size, modified, mimeType, permissions)
                            }

                            MouseArea {
                                // See the matching comment in the ListView's
                                // overlay above — kept below the delegates in
                                // z-order so per-item right-clicks win.
                                id: gridBackgroundArea
                                z: -1
                                anchors.fill: parent
                                acceptedButtons: Qt.RightButton
                                onWheel: (wheel) => window.applyWheelScroll(gridView, wheel)
                                onClicked: (mouse) => {
                                    var scenePos = gridBackgroundArea.mapToItem(null, mouse.x, mouse.y)
                                    contextMenu.popup(scenePos.x, scenePos.y)
                                }
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
            }
        }
    }

    // Menus and dialogs are anchored to the whole Window, not just
    // contentArea — their dimmed backdrop needs to cover the top bar and
    // sidebar too, not stop at the file listing's edge.
    ContextMenu {
        id: contextMenu
        onNewFolderRequested: newFolderDialog.open()
        onOpenTerminalRequested: fileModel.openTerminalHere()
    }

    NewFolderDialog {
        id: newFolderDialog
        onAccepted: (name) => fileModel.createFolder(name)
    }

    ItemContextMenu {
        id: itemContextMenu
        onOpenRequested: (name) => {
            if (itemContextMenu.entryIsDir) {
                fileModel.navigate(fileModel.currentPath + "/" + name)
            } else {
                fileModel.openEntry(name)
            }
        }
        onRenameRequested: (name) => renameDialog.open(name)
        onDuplicateRequested: (name) => fileModel.duplicateEntry(name)
        onCopyPathRequested: (name) => clipboardHelper.copyText(fileModel.entryAbsolutePath(name))
        onDeleteRequested: (name) => {
            window._pendingDeleteName = name
            deleteConfirmDialog.open("Move \"" + name + "\" to Trash?")
        }
        onPropertiesRequested: (name, isDir, size, modified, mimeType, permissions) =>
            propertiesDialog.open(name, isDir, size, modified, mimeType, permissions)
    }

    RenameDialog {
        id: renameDialog
        onAccepted: (oldName, newName) => fileModel.renameEntry(oldName, newName)
    }

    PropertiesDialog {
        id: propertiesDialog
        fileModel: fileModel
    }

    ConfirmDialog {
        id: deleteConfirmDialog
        title: "Move to Trash"
        confirmLabel: "Delete"
        onConfirmed: fileModel.deleteEntry(window._pendingDeleteName)
    }
}
