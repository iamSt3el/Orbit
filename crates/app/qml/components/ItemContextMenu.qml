import QtQuick
import com.filemanager.app 1.0

// Right-click menu for a specific file/folder entry (as opposed to
// ContextMenu.qml, which is the background right-click menu for the
// current folder itself).
Item {
    id: root

    property string entryName: ""
    property bool entryIsDir: false
    property int entrySize: 0
    property string entryModified: ""
    property string entryMimeType: ""

    signal openRequested(string name)
    signal renameRequested(string name)
    signal deleteRequested(string name)
    signal propertiesRequested(string name, bool isDir, int size, string modified, string mimeType)

    anchors.fill: parent
    visible: false
    z: 1000

    readonly property var _items: [
        { icon: "open_in_new", label: "Open" },
        { icon: "edit", label: "Rename" },
        { icon: "delete", label: "Delete" },
        { icon: "info", label: "Properties" }
    ]

    function popup(x, y, name, isDir, size, modified, mimeType) {
        root.entryName = name
        root.entryIsDir = isDir
        root.entrySize = size
        root.entryModified = modified
        root.entryMimeType = mimeType
        menu.x = Math.min(x, root.width - menu.width)
        menu.y = Math.min(y, root.height - menu.height)
        visible = true
    }

    function close() {
        visible = false
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
        onWheel: (wheel) => { wheel.accepted = true }
    }

    Rectangle {
        id: menu
        width: 200
        height: _column.implicitHeight
        radius: Shape.medium
        color: Elevation.surfaceAt(3)
        clip: true

        Column {
            id: _column
            width: parent.width

            Repeater {
                model: root._items

                delegate: Item {
                    id: menuItem
                    required property var modelData
                    width: menu.width
                    height: 44

                    Rectangle {
                        anchors.fill: parent
                        color: Elevation.surfaceAt(1)
                        opacity: _itemArea.containsMouse ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        spacing: 12

                        Icon {
                            content: menuItem.modelData.icon
                            iconSize: 20
                            color: Color.scheme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: menuItem.modelData.label
                            color: Color.scheme.surfaceText
                            font.family: Type.bodyLarge.family
                            font.pixelSize: Type.bodyLarge.size
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: _itemArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.close()
                            switch (menuItem.modelData.label) {
                            case "Open": root.openRequested(root.entryName); break
                            case "Rename": root.renameRequested(root.entryName); break
                            case "Delete": root.deleteRequested(root.entryName); break
                            case "Properties":
                                root.propertiesRequested(root.entryName, root.entryIsDir, root.entrySize, root.entryModified, root.entryMimeType)
                                break
                            }
                        }
                    }
                }
            }
        }
    }
}
