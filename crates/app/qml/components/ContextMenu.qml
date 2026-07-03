import QtQuick
import com.filemanager.app 1.0

// A minimal custom context menu (no Qt Quick Controls Menu, per this
// project's design system convention) for the background of the current
// folder (as opposed to ItemContextMenu.qml, which is per file/folder).
// Call popup(x, y) to show it anchored at a position within its parent; it
// closes itself on an outside click or Escape.
Item {
    id: root

    signal newFolderRequested
    signal openTerminalRequested
    signal pasteRequested

    anchors.fill: parent
    visible: false
    z: 1000

    // Set fresh by main.qml right before each popup() call — canPaste()
    // isn't a reactive qproperty, so this is a snapshot, not a live
    // binding (matching how popup() already takes the entry's other
    // fields as plain snapshot arguments).
    property bool canPaste: false

    readonly property var _items: canPaste
        ? [
            { icon: "create_new_folder", label: "New folder" },
            { icon: "content_paste", label: "Paste" },
            { icon: "terminal", label: "Open Terminal Here" }
        ]
        : [
            { icon: "create_new_folder", label: "New folder" },
            { icon: "terminal", label: "Open Terminal Here" }
        ]

    function popup(x, y) {
        menu.x = Math.min(x, root.width - menu.width)
        menu.y = Math.min(y, root.height - menu.height)
        visible = true
    }

    function close() {
        visible = false
    }

    MouseArea {
        // See ItemContextMenu.qml — must accept every button and track
        // hover so nothing underneath can still be interacted with while
        // this menu is open.
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        onClicked: root.close()
        onWheel: (wheel) => { wheel.accepted = true }
    }

    Rectangle {
        id: menu
        width: 220
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
                    width: menu.width
                    height: 44

                    Rectangle {
                        anchors.fill: parent
                        color: Elevation.surfaceAt(1)
                        opacity: _itemArea.containsMouse ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
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
                            case "New folder": root.newFolderRequested(); break
                            case "Paste": root.pasteRequested(); break
                            case "Open Terminal Here": root.openTerminalRequested(); break
                            }
                        }
                    }
                }
            }
        }
    }
}
