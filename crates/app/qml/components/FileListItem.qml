import QtQuick
import com.filemanager.app 1.0

Item {
    id: root

    // Set by the ListView's model role bindings (name, isDir, size, iconKey)
    // plus the containing view's own `model` (the FileListModel instance),
    // used here only to call deleteEntry.
    required property string name
    required property bool isDir
    required property int size
    required property string iconKey
    property var fileModel

    width: ListView.view ? ListView.view.width : 0
    height: 56

    Rectangle {
        anchors.fill: parent
        color: _itemArea.containsMouse ? Elevation.surfaceAt(1) : "transparent"
        radius: Shape.small

        Behavior on color { ColorAnimation { duration: Motion.standard.duration } }

        Ripple {
            id: _itemArea
            anchors.fill: parent
            radius: parent.radius
        }
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 16

        Icon {
            content: root.isDir ? "folder" : "description"
            iconSize: 24
            color: Color.scheme.onSurfaceVariant
            anchors.verticalCenter: parent.verticalCenter
        }

        Column {
            width: parent.width - 24 - 24 - 32
            anchors.verticalCenter: parent.verticalCenter

            Text {
                text: root.name
                color: Color.scheme.onSurface
                font.family: Type.bodyLarge.family
                font.weight: Type.bodyLarge.weight
                font.pixelSize: Type.bodyLarge.size
                elide: Text.ElideMiddle
                width: parent.width
            }

            Text {
                text: root.isDir ? "" : (root.size + " bytes")
                visible: text.length > 0
                color: Color.scheme.onSurfaceVariant
                font.family: Type.bodyMedium.family
                font.weight: Type.bodyMedium.weight
                font.pixelSize: Type.bodyMedium.size
            }
        }

        Icon {
            content: "delete"
            iconSize: 20
            color: Color.scheme.onSurfaceVariant
            anchors.verticalCenter: parent.verticalCenter

            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                cursorShape: Qt.PointingHandCursor
                onClicked: root.fileModel.deleteEntry(root.name)
            }
        }
    }
}
