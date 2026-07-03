import QtQuick
import com.filemanager.app 1.0

Item {
    id: root

    required property string name
    required property bool isDir
    required property int size
    required property string iconKey

    readonly property var fileModel: GridView.view ? GridView.view.model : null

    width: GridView.view ? GridView.view.cellWidth : 0
    height: GridView.view ? GridView.view.cellHeight : 0

    GridView.onReused: {
        cellArea.hoverEnabled = false
        cellArea.hoverEnabled = true
        deleteArea.hoverEnabled = false
        deleteArea.hoverEnabled = true
    }

    Rectangle {
        id: card
        anchors.fill: parent
        anchors.margins: 6
        radius: Shape.medium
        color: cellArea.containsMouse ? Elevation.surfaceAt(1) : "transparent"

        Behavior on color { ColorAnimation { duration: 120 } }

        Column {
            anchors.centerIn: parent
            spacing: 8

            Rectangle {
                width: 56
                height: 56
                radius: Shape.medium
                color: root.isDir ? Qt.alpha(Color.scheme.primary, 0.12) : "transparent"
                anchors.horizontalCenter: parent.horizontalCenter

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
        }

        MouseArea {
            id: cellArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (root.isDir) {
                    root.fileModel.navigate(root.fileModel.currentPath + "/" + root.name)
                }
            }
        }

        Rectangle {
            width: 28
            height: 28
            radius: Shape.full
            color: Elevation.surfaceAt(3)
            opacity: (cellArea.containsMouse || deleteArea.containsMouse) ? 1 : 0
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 6

            Behavior on opacity { NumberAnimation { duration: 120 } }

            Icon {
                anchors.centerIn: parent
                content: "delete"
                iconSize: 16
                color: Color.scheme.surfaceVariantText
            }

            MouseArea {
                id: deleteArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.fileModel.deleteEntry(root.name)
            }
        }
    }
}
