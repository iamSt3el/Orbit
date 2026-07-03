import QtQuick
import com.filemanager.app 1.0

// A minimal custom context menu (no Qt Quick Controls Menu, per this
// project's design system convention). Call popup(x, y) to show it
// anchored at a position within its parent; it closes itself on an
// outside click or Escape.
Item {
    id: root

    signal newFolderRequested

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
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
        onWheel: (wheel) => { wheel.accepted = true }
    }

    Rectangle {
        id: menu
        width: 200
        height: 48
        radius: Shape.medium
        color: Elevation.surfaceAt(3)

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Elevation.surfaceAt(1)
            opacity: _itemArea.containsMouse ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }

        Row {
            anchors.fill: parent
            anchors.leftMargin: 16
            spacing: 12

            Icon {
                content: "create_new_folder"
                iconSize: 20
                color: Color.scheme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: "New folder"
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
                root.newFolderRequested()
            }
        }
    }
}
