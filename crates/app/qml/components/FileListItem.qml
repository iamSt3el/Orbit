import QtQuick
import com.filemanager.app 1.0

Item {
    id: root

    // Set by the ListView's model role bindings.
    required property string name
    required property bool isDir
    required property int size
    required property string iconKey

    // The containing ListView's model (the FileListModel instance), read via
    // the attached ListView.view property rather than a manually-passed
    // property — more reliable across delegate recycling.
    readonly property var fileModel: ListView.view ? ListView.view.model : null

    width: ListView.view ? ListView.view.width : 0
    height: 60

    Rectangle {
        anchors.fill: parent
        color: _itemArea.containsMouse ? Elevation.surfaceAt(1) : "transparent"
        radius: Shape.small

        Behavior on color { ColorAnimation { duration: Motion.standard.duration } }

        Ripple {
            id: _itemArea
            anchors.fill: parent
            radius: parent.radius
            onClicked: {
                if (root.isDir) {
                    root.fileModel.navigate(root.fileModel.currentPath + "/" + root.name)
                }
            }
        }
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 12
        spacing: 16

        Rectangle {
            width: 40
            height: 40
            radius: Shape.medium
            color: root.isDir ? Qt.alpha(Color.scheme.primary, 0.12) : "transparent"
            anchors.verticalCenter: parent.verticalCenter

            Icon {
                anchors.centerIn: parent
                content: root.isDir ? "folder" : "description"
                iconSize: 22
                color: root.isDir ? Color.scheme.primary : Color.scheme.surfaceVariantText
            }
        }

        Column {
            width: parent.width - 40 - 40 - 32
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                text: root.name
                color: Color.scheme.surfaceText
                font.family: Type.bodyLarge.family
                font.weight: Type.bodyLarge.weight
                font.pixelSize: Type.bodyLarge.size
                elide: Text.ElideMiddle
                width: parent.width
            }

            Text {
                text: root.isDir ? "" : (root.size + " bytes")
                visible: text.length > 0
                color: Color.scheme.surfaceVariantText
                font.family: Type.bodyMedium.family
                font.weight: Type.bodyMedium.weight
                font.pixelSize: Type.bodyMedium.size
            }
        }

        Rectangle {
            width: 40
            height: 40
            radius: Shape.full
            color: "transparent"
            anchors.verticalCenter: parent.verticalCenter

            Icon {
                anchors.centerIn: parent
                content: "delete"
                iconSize: 20
                color: Color.scheme.surfaceVariantText
            }

            Ripple {
                anchors.fill: parent
                radius: parent.radius
                onClicked: root.fileModel.deleteEntry(root.name)
            }
        }
    }
}
