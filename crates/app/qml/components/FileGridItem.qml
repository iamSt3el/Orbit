import QtQuick
import "../util/format.js" as Format
import com.filemanager.app 1.0

Item {
    id: root

    required property string name
    required property bool isDir
    required property int size
    required property string iconKey
    required property string modified
    required property string mimeType
    required property string permissions

    signal contextMenuRequested(real x, real y)

    readonly property var fileModel: GridView.view ? GridView.view.model : null

    width: GridView.view ? GridView.view.cellWidth : 0
    height: GridView.view ? GridView.view.cellHeight : 0

    GridView.onReused: {
        cellArea.hoverEnabled = false
        cellArea.hoverEnabled = true
    }

    Item {
        id: card
        anchors.fill: parent
        anchors.margins: 6

        Rectangle {
            // No permanent fill here — a fully opaque `surface`-colored box
            // behind every single grid icon (regardless of hover) read as a
            // grid of dark rectangles in dark mode, since `surface` is
            // darker than the content panel behind it. Hover-only opacity,
            // constant color (see FileListItem.qml for why not `Behavior on
            // color` from "transparent").
            anchors.fill: parent
            radius: Shape.medium
            color: Elevation.surfaceAt(1)
            opacity: cellArea.containsMouse ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }

        Column {
            anchors.centerIn: parent
            spacing: 8

            Item {
                width: 56
                height: 56
                anchors.horizontalCenter: parent.horizontalCenter

                // Hover-only tonal container, matching FileListItem — see
                // its comment for why this isn't a permanent background.
                Rectangle {
                    anchors.fill: parent
                    radius: Shape.medium
                    color: Qt.alpha(Color.scheme.primary, 0.12)
                    opacity: (root.isDir && cellArea.containsMouse) ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                }

                Icon {
                    anchors.centerIn: parent
                    content: root.isDir ? "folder" : "description"
                    iconSize: 32
                    color: root.isDir ? Color.scheme.primary : Color.scheme.surfaceVariantText
                }
            }

            Text {
                text: root.name
                color: Color.scheme.surfaceText
                font.family: Type.bodyMedium.family
                font.weight: Type.bodyMedium.weight
                font.pixelSize: Type.bodyMedium.size
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideMiddle
                width: card.width - 16
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: root.isDir ? "" : Format.formatBytes(root.size)
                visible: text.length > 0
                color: Color.scheme.surfaceVariantText
                font.family: Type.bodyMedium.family
                font.weight: Type.bodyMedium.weight
                font.pixelSize: 11
                horizontalAlignment: Text.AlignHCenter
                width: card.width - 16
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        MouseArea {
            id: cellArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton) {
                    var scenePos = root.mapToItem(null, mouse.x, mouse.y)
                    root.contextMenuRequested(scenePos.x, scenePos.y)
                } else if (root.isDir) {
                    root.fileModel.navigate(root.fileModel.currentPath + "/" + root.name)
                }
            }
        }
    }
}
