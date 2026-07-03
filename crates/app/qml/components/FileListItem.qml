import QtQuick
import "../util/format.js" as Format
import com.filemanager.app 1.0

Item {
    id: root

    // Set by the ListView's model role bindings.
    required property string name
    required property bool isDir
    required property int size
    required property string iconKey
    required property string modified
    required property string mimeType
    required property string permissions

    signal contextMenuRequested(real x, real y)

    // The containing ListView's model (the FileListModel instance), read via
    // the attached ListView.view property rather than a manually-passed
    // property — more reliable across delegate recycling.
    readonly property var fileModel: ListView.view ? ListView.view.model : null

    width: ListView.view ? ListView.view.width : 0
    height: 60

    // Reset by the ListView on delegate reuse (Qt Quick recycles delegate
    // items on scroll when ListView.reuseItems is true — hover state is
    // otherwise left stale on the recycled item since repositioning it
    // under the cursor doesn't generate a real mouse-move event).
    ListView.onReused: {
        rowArea.hoverEnabled = false
        rowArea.hoverEnabled = true
    }

    // Lightweight hover highlight: a constant-color rectangle whose opacity
    // is animated, not its RGBA color. Animating a Behavior on `color` from
    // "transparent" to an opaque tint interpolates alpha and RGB together,
    // which visibly flashes through an intermediate near-black state before
    // settling — animating opacity on a fixed color avoids that entirely,
    // and is cheaper (no OpacityMask/layer compositing per row, which is
    // expensive to redo on every delegate during fast scrolling).
    Rectangle {
        anchors.fill: parent
        radius: Shape.small
        color: Elevation.surfaceAt(1)
        opacity: rowArea.containsMouse ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        id: rowArea
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

    Row {
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 12
        spacing: 16

        Item {
            width: 40
            height: 40
            anchors.verticalCenter: parent.verticalCenter

            // The tonal container behind a folder icon is a hover-only
            // affordance, not a permanent decoration — a constant tinted
            // box behind every folder row reads as visual noise at list
            // scale.
            Rectangle {
                anchors.fill: parent
                radius: Shape.medium
                color: Qt.alpha(Color.scheme.primary, 0.12)
                opacity: (root.isDir && rowArea.containsMouse) ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            }

            Icon {
                anchors.centerIn: parent
                content: root.isDir ? "folder" : "description"
                iconSize: 22
                color: root.isDir ? Color.scheme.primary : Color.scheme.surfaceVariantText
            }
        }

        Column {
            width: parent.width - 40 - 16
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
                text: root.isDir ? "" : Format.formatBytes(root.size)
                visible: text.length > 0
                color: Color.scheme.surfaceVariantText
                font.family: Type.bodyMedium.family
                font.weight: Type.bodyMedium.weight
                font.pixelSize: Type.bodyMedium.size
            }
        }
    }
}
