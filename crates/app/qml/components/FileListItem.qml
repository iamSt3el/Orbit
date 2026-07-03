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
    required property string thumbnailPath

    // Overridable from the view-options menu; defaults preserve the
    // original fixed sizing.
    property int iconSize: 22
    property int iconContainerSize: 40

    signal contextMenuRequested(real x, real y)

    // The containing ListView's model (the FileListModel instance), read via
    // the attached ListView.view property rather than a manually-passed
    // property — more reliable across delegate recycling.
    readonly property var fileModel: ListView.view ? ListView.view.model : null

    width: ListView.view ? ListView.view.width : 0
    height: 60

    // Only images (raster + svg, see fm_core::mime's icon_key_for) get a
    // thumbnail — everything else keeps its Material icon glyph. Requested
    // lazily per-delegate rather than for the whole folder up front, so a
    // directory with thousands of photos doesn't decode all of them at
    // once; FileListModel itself no-ops a repeat request for an entry
    // that's already resolved or already in flight.
    function _requestThumbnailIfNeeded() {
        if (root.fileModel && root.iconKey === "image" && root.thumbnailPath.length === 0) {
            root.fileModel.requestThumbnail(root.name)
        }
    }

    Component.onCompleted: root._requestThumbnailIfNeeded()

    // Reset by the ListView on delegate reuse (Qt Quick recycles delegate
    // items on scroll when ListView.reuseItems is true — hover state is
    // otherwise left stale on the recycled item since repositioning it
    // under the cursor doesn't generate a real mouse-move event).
    ListView.onReused: {
        rowArea.hoverEnabled = false
        rowArea.hoverEnabled = true
        root._requestThumbnailIfNeeded()
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
            }
        }
        onDoubleClicked: (mouse) => {
            if (mouse.button !== Qt.LeftButton) {
                return
            }
            if (root.isDir) {
                root.fileModel.navigate(root.fileModel.currentPath + "/" + root.name)
            } else {
                root.fileModel.openEntry(root.name)
            }
        }
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 12
        spacing: 16

        Item {
            width: root.iconContainerSize
            height: root.iconContainerSize
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
                content: Format.iconForKey(root.iconKey, root.isDir)
                iconSize: root.iconSize
                color: root.isDir ? Color.scheme.primary : Color.scheme.surfaceVariantText
                visible: opacity > 0
                opacity: thumbnail.status === Image.Ready ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: 120 } }
            }

            Image {
                id: thumbnail
                anchors.fill: parent
                visible: opacity > 0
                opacity: status === Image.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 120 } }
                source: root.thumbnailPath.length > 0 ? root.thumbnailPath : ""
                sourceSize: Qt.size(root.iconContainerSize, root.iconContainerSize)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }
        }

        Column {
            width: parent.width - root.iconContainerSize - 16
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
