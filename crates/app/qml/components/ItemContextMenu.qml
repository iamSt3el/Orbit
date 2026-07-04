import QtQuick
import com.filemanager.app 1.0

// Right-click menu for a specific file/folder entry (as opposed to
// ContextMenu.qml, which is the background right-click menu for the
// current folder itself).
Item {
    id: root

    property string entryName: ""
    property bool entryIsDir: false
    // real, not int — see FileListItem.qml's `size` role for why.
    property real entrySize: 0
    property string entryModified: ""
    property string entryMimeType: ""
    property string entryPermissions: ""
    // How many items are selected at the moment this menu was popped up —
    // if more than 1, the menu shows only the actions that make sense in
    // bulk (Cut/Copy/Duplicate/Delete) instead of the full single-item menu.
    property int selectionCount: 1

    signal openRequested(string name)
    signal renameRequested(string name)
    signal duplicateRequested(string name)
    signal copyPathRequested(string name)
    signal copyRequested(string name)
    signal cutRequested(string name)
    signal deleteRequested(string name)
    signal propertiesRequested(string name, bool isDir, real size, string modified, string mimeType, string permissions)
    // See ContextMenu.qml — lets the Loader wrapping this component tear
    // the instance down once it hides.
    signal closed

    anchors.fill: parent
    visible: false
    z: 1000

    readonly property var _items: root.selectionCount > 1
        ? [
            { icon: "content_cut", label: "Cut " + root.selectionCount + " items", action: "cut" },
            { icon: "content_copy", label: "Copy " + root.selectionCount + " items", action: "copy" },
            { icon: "file_copy", label: "Duplicate " + root.selectionCount + " items", action: "duplicate" },
            { icon: "delete", label: "Delete " + root.selectionCount + " items", action: "delete", destructive: true }
        ]
        : [
            { icon: "open_in_new", label: "Open", action: "open" },
            { icon: "content_cut", label: "Cut", action: "cut" },
            { icon: "content_copy", label: "Copy", action: "copy" },
            { icon: "edit", label: "Rename", action: "rename" },
            { icon: "file_copy", label: "Duplicate", action: "duplicate" },
            { icon: "link", label: "Copy Path", action: "copyPath" },
            { icon: "delete", label: "Delete", action: "delete", destructive: true },
            { icon: "info", label: "Properties", action: "properties" }
        ]

    function popup(x, y, name, isDir, size, modified, mimeType, permissions, selectionCount) {
        root.entryName = name
        root.entryIsDir = isDir
        root.entrySize = size
        root.entryModified = modified
        root.entryMimeType = mimeType
        root.entryPermissions = permissions
        root.selectionCount = selectionCount
        menu.x = Math.min(x, root.width - menu.width)
        menu.y = Math.min(y, root.height - menu.height)
        visible = true
        root.forceActiveFocus()
    }

    function close() {
        visible = false
        root.closed()
    }

    Keys.onEscapePressed: root.close()

    MouseArea {
        // Must swallow every button and track hover itself — a MouseArea
        // that only accepts its default (left) button lets right-clicks
        // and hover-move events fall through to whatever is underneath,
        // which is how a click on the scrim could still open another
        // item's context menu behind this one.
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        onClicked: root.close()
        onWheel: (wheel) => { wheel.accepted = true }
    }

    Rectangle {
        id: menu
        width: 200
        height: _column.implicitHeight
        radius: Shape.small
        color: Elevation.surfaceAt(2)
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
                            switch (menuItem.modelData.action) {
                            case "open": root.openRequested(root.entryName); break
                            case "cut": root.cutRequested(root.entryName); break
                            case "copy": root.copyRequested(root.entryName); break
                            case "rename": root.renameRequested(root.entryName); break
                            case "duplicate": root.duplicateRequested(root.entryName); break
                            case "copyPath": root.copyPathRequested(root.entryName); break
                            case "delete": root.deleteRequested(root.entryName); break
                            case "properties":
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
