import QtQuick
import com.orbit.app 1.0

// Right-click menu for a pinned sidebar folder — a single action (unpin),
// TrashContextMenu's structural twin.
Item {
    id: root

    signal unpinRequested
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
        root.forceActiveFocus()
    }

    function close() {
        visible = false
        root.closed()
    }

    Keys.onEscapePressed: root.close()
    Keys.onShortcutOverride: (event) => {
        event.accepted = event.key === Qt.Key_Escape
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
        radius: Shape.large
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
                content: "keep_off"
                iconSize: 20
                color: Color.scheme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: "Unpin"
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
                root.unpinRequested()
            }
        }
    }
}
