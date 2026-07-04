import QtQuick
import com.filemanager.app 1.0

// Right-click menu for the sidebar's Trash shortcut — a single destructive
// action (permanently emptying the Trash), unlike ItemContextMenu's varied
// per-file action list.
Item {
    id: root

    signal emptyTrashRequested
    // See ContextMenu.qml — lets the Loader wrapping this component tear
    // the instance down once it hides.
    signal closed

    anchors.fill: parent
    visible: false
    z: 1000

    function popup(x, y) {
        menu.x = Math.min(x, root.width - menu.width)
        menu.y = Math.min(y, root.height - menu.height)
        visible = true
    }

    function close() {
        visible = false
        root.closed()
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
        width: 200
        height: 44
        radius: Shape.small
        color: Elevation.surfaceAt(2)
        clip: true

        Rectangle {
            anchors.fill: parent
            radius: menu.radius
            color: Elevation.surfaceAt(1)
            opacity: _itemArea.containsMouse ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }

        Row {
            anchors.fill: parent
            anchors.leftMargin: 16
            spacing: 12

            Icon {
                content: "delete_forever"
                iconSize: 20
                color: Color.scheme.error
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: "Empty Trash"
                color: Color.scheme.error
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
                root.emptyTrashRequested()
            }
        }
    }
}
