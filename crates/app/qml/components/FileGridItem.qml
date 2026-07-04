import QtQuick
import "../util/format.js" as Format
import com.filemanager.app 1.0

Item {
    id: root

    required property string name
    required property bool isDir
    // real, not int — QML's int is 32-bit and silently truncates any file
    // over ~2.1GB; the model exposes size as a 64-bit value and real (a
    // JS double) can represent that exactly.
    required property real size
    required property string iconKey
    required property string modified
    required property string mimeType
    required property string permissions
    required property string thumbnailPath

    // Overridable from the view-options menu; defaults preserve the
    // original fixed sizing.
    property int iconSize: 32
    property int iconContainerSize: 56

    signal contextMenuRequested(real x, real y)

    readonly property var fileModel: GridView.view ? GridView.view.model : null

    width: GridView.view ? GridView.view.cellWidth : 0
    height: GridView.view ? GridView.view.cellHeight : 0

    // See FileListItem.qml's matching comment — lazy per-delegate request,
    // no-ops if already resolved or already in flight.
    function _requestThumbnailIfNeeded() {
        if (root.fileModel && root.iconKey === "image" && root.thumbnailPath.length === 0) {
            root.fileModel.requestThumbnail(root.name)
        }
    }

    Component.onCompleted: root._requestThumbnailIfNeeded()

    GridView.onReused: {
        cellArea.hoverEnabled = false
        cellArea.hoverEnabled = true
        root._requestThumbnailIfNeeded()
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
                width: root.iconContainerSize
                height: root.iconContainerSize
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
                font.family: Type.bodySmall.family
                font.weight: Type.bodySmall.weight
                font.pixelSize: Type.bodySmall.size
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
    }
}
