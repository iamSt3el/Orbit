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
    // See FileListItem.qml's matching property.
    required property bool selected

    // Overridable from the view-options menu; defaults preserve the
    // original fixed sizing.
    property int iconSize: 32
    property int iconContainerSize: 56

    signal contextMenuRequested(real x, real y)

    readonly property var fileModel: GridView.view ? GridView.view.model : null

    // See FileListItem.qml's matching properties/function for why.
    Drag.active: false
    Drag.dragType: Drag.Automatic
    Drag.supportedActions: Qt.CopyAction | Qt.MoveAction
    Drag.proposedAction: Qt.MoveAction
    Drag.keys: ["text/uri-list", "application/x-filemanager-internal"]
    Drag.onDragFinished: (dropAction) => {
        root.Drag.active = false
        root.Window.window._internalDragActive = false
    }

    // grabToImage is asynchronous — Drag.active only flips on once the
    // snapshot is ready, so the OS drag always starts with a real preview
    // image instead of just a bare cursor.
    function _startDrag() {
        root.Window.window._internalDragActive = true
        var names = root.selected ? root.fileModel.selectedNamesJoined().split("\n") : [root.name]
        // Percent-encode each path segment: a bare space (or #, %, ?) in a
        // filename makes an invalid URI that strict receivers mangle or
        // reject; our own DropAreas decode symmetrically on the way in.
        var uris = names.map((n) => "file://" + root.fileModel.entryAbsolutePath(n).split("/").map(encodeURIComponent).join("/"))
        root.Drag.mimeData = { "text/uri-list": uris.join("\r\n") }
        root.grabToImage((result) => {
            root.Drag.imageSource = result.url
            root.Drag.active = true
        })
    }

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
            anchors.fill: parent
            // Selection rounds the corners (roadmap item 11) — a whisper
            // of the removed selection badge, spring per the motion rule.
            radius: root.selected ? Shape.extraLarge : Shape.medium
            Behavior on radius {
                SpringAnimation {
                    spring: Motion.springStandard.spring
                    damping: Motion.springStandard.damping
                }
            }
            color: Color.scheme.secondaryContainer
            opacity: root.selected ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }

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

                Rectangle {
                    // See FileListItem.qml's matching highlight for why
                    // this exists alongside the hover-highlight above.
                    anchors.fill: parent
                    radius: Shape.medium
                    color: Qt.alpha(Color.scheme.primary, 0.12)
                    opacity: folderDropArea.containsDrag ? 1 : 0
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

            property real _pressX: 0
            property real _pressY: 0
            property bool _dragging: false

            onPressed: (mouse) => {
                cellArea._pressX = mouse.x
                cellArea._pressY = mouse.y
                cellArea._dragging = false
            }
            onPositionChanged: (mouse) => {
                if (!cellArea.pressed || cellArea._dragging || !(cellArea.pressedButtons & Qt.LeftButton)) {
                    return
                }
                var dx = mouse.x - cellArea._pressX
                var dy = mouse.y - cellArea._pressY
                if (Math.sqrt(dx * dx + dy * dy) < 6) {
                    return
                }
                cellArea._dragging = true
                root._startDrag()
            }
            onReleased: {
                cellArea._dragging = false
            }
            onClicked: (mouse) => {
                if (cellArea._dragging) {
                    return
                }
                if (mouse.button === Qt.RightButton) {
                    if (!root.selected) {
                        root.fileModel.clearSelection()
                        root.fileModel.setSelected(root.name, true)
                        root.GridView.view.selectionAnchor = root.name
                    }
                    var scenePos = root.mapToItem(null, mouse.x, mouse.y)
                    root.contextMenuRequested(scenePos.x, scenePos.y)
                    return
                }
                if (mouse.modifiers & Qt.ShiftModifier) {
                    root.fileModel.selectRange(root.GridView.view.selectionAnchor, root.name)
                } else if (mouse.modifiers & Qt.ControlModifier) {
                    root.fileModel.setSelected(root.name, !root.selected)
                    root.GridView.view.selectionAnchor = root.name
                } else {
                    root.fileModel.clearSelection()
                    root.fileModel.setSelected(root.name, true)
                    root.GridView.view.selectionAnchor = root.name
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

        // An internal drag is always a move regardless of
        // drop.proposedAction — see the matching comment in
        // FileListItem.qml for why (some platforms don't reliably reflect
        // Drag.proposedAction: Qt.MoveAction back on the DragEvent).
        // window._internalDragActive detects "this is our own drag", not
        // drop.keys (same cross-platform reliability problem).
        DropArea {
            id: folderDropArea
            anchors.fill: parent
            enabled: root.isDir
            keys: ["text/uri-list"]

            // Spring-loaded folders — see FileListItem.qml's matching
            // Timer: hovering a drag here for a beat navigates into the
            // folder; leaving before it fires cancels.
            Timer {
                interval: 800
                running: folderDropArea.containsDrag
                onTriggered: root.fileModel.navigate(root.fileModel.currentPath + "/" + root.name)
            }

            onDropped: (drop) => {
                if (!drop.hasUrls) {
                    return
                }
                var isMove = root.Window.window._internalDragActive || drop.proposedAction === Qt.MoveAction
                drop.acceptProposedAction()
                var paths = []
                for (var i = 0; i < drop.urls.length; i++) {
                    // decodeURIComponent: QUrl.toString() is percent-encoded, so a
                    // dropped "my photo.jpg" otherwise arrives as a literal
                    // "my%20photo.jpg" path and every operation on it fails.
                    paths.push(decodeURIComponent(drop.urls[i].toString().replace("file://", "")))
                }
                var destDir = root.fileModel.currentPath + "/" + root.name
                root.fileModel.dropPaths(paths.join("\n"), destDir, isMove)
            }
        }
    }
}
