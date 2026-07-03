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
    property string entryPermissions: ""

    signal openRequested(string name)
    signal renameRequested(string name)
    signal duplicateRequested(string name)
    signal copyPathRequested(string name)
    signal deleteRequested(string name)
    signal propertiesRequested(string name, bool isDir, int size, string modified, string mimeType, string permissions)

    anchors.fill: parent
    visible: false
    z: 1000

    readonly property var _items: [
        { icon: "open_in_new", label: "Open" },
        { icon: "edit", label: "Rename" },
        { icon: "content_copy", label: "Duplicate" },
        { icon: "link", label: "Copy Path" },
        { icon: "delete", label: "Delete", destructive: true },
        { icon: "info", label: "Properties" }
    ]

    function popup(x, y, name, isDir, size, modified, mimeType, permissions) {
        root.entryName = name
        root.entryIsDir = isDir
        root.entrySize = size
        root.entryModified = modified
        root.entryMimeType = mimeType
        root.entryPermissions = permissions
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
                    required property int index
                    readonly property bool isFirst: index === 0
                    readonly property bool isLast: index === root._items.length - 1
                    readonly property bool destructive: !!menuItem.modelData.destructive
                    readonly property color _labelColor: menuItem.destructive ? Color.scheme.error : Color.scheme.surfaceText
                    width: menu.width
                    height: 44

                    // A thin divider before the destructive action, separating
                    // it from the routine actions above it.
                    Rectangle {
                        visible: menuItem.destructive
                        anchors.top: parent.top
                        width: parent.width
                        height: 1
                        color: Color.scheme.outlineVariant
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: Elevation.surfaceAt(1)
                        opacity: _itemArea.containsMouse ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        // Matches the outer menu's rounded top/bottom corners —
                        // Rectangle's `clip: true` only clips to the axis-aligned
                        // bounding box, not the rounded shape, so without this the
                        // hover highlight pokes out square-cornered.
                        topLeftRadius: menuItem.isFirst ? menu.radius : 0
                        topRightRadius: menuItem.isFirst ? menu.radius : 0
                        bottomLeftRadius: menuItem.isLast ? menu.radius : 0
                        bottomRightRadius: menuItem.isLast ? menu.radius : 0
                    }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        spacing: 12

                        Icon {
                            content: menuItem.modelData.icon
                            iconSize: 20
                            color: menuItem._labelColor
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: menuItem.modelData.label
                            color: menuItem._labelColor
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
                            case "Duplicate": root.duplicateRequested(root.entryName); break
                            case "Copy Path": root.copyPathRequested(root.entryName); break
                            case "Delete": root.deleteRequested(root.entryName); break
                            case "Properties":
                                root.propertiesRequested(root.entryName, root.entryIsDir, root.entrySize, root.entryModified, root.entryMimeType, root.entryPermissions)
                                break
                            }
                        }
                    }
                }
            }
        }
    }
}
