import QtQuick
import "../util/format.js" as Format
import com.orbit.app 1.0

Item {
    id: root

    // Set by the ListView's model role bindings.
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
    required property real childCount
    required property string matchLine
    // Bound to the model's `selected` role — true while this row is part
    // of the current multi-selection (Ctrl/Shift/drag-select).
    required property bool selected
    required property int index

    // Overridable from the view-options menu; defaults preserve the
    // original fixed sizing.
    property int iconSize: 22
    property int iconContainerSize: 40

    signal contextMenuRequested(real x, real y)

    // The containing ListView's model (the FileListModel instance), read via
    // the attached ListView.view property rather than a manually-passed
    // property — more reliable across delegate recycling.
    readonly property var fileModel: ListView.view ? ListView.view.model : null

    // Keyboard cursor (roadmap item 7): the model-side cursorRow indexes
    // displayed rows, which is exactly this delegate's index.
    readonly property bool isCursor: fileModel ? fileModel.cursorRow === root.index : false

    // Recursive-search results are rel-path names too, but they must keep
    // showing the full relative path un-indented — tree presentation only
    // applies outside an active search.
    readonly property bool _searchActive: fileModel ? fileModel.searchActive === true : false
    readonly property int treeDepth: root._searchActive ? 0 : root.name.split("/").length - 1
    readonly property string displayName: root._searchActive
        ? root.name : root.name.substring(root.name.lastIndexOf("/") + 1)
    readonly property bool isExpanded: (root.isDir && fileModel)
        ? ("\n" + fileModel.expandedDirsJoined + "\n").indexOf("\n" + root.name + "\n") >= 0
        : false

    // Dragging a row that's already part of the selection drags the whole
    // selection; dragging an unselected row drags just that one item —
    // mirrors the existing right-click rule in rowArea.onClicked below.
    // grabToImage is asynchronous — the drag only starts once the
    // snapshot is ready, so the OS drag always starts with a real preview
    // image instead of just a bare cursor. The drag itself runs on the
    // window's persistent dragProxy, NOT on this delegate: a delegate is
    // destroyed whenever the listing changes (spring-loaded navigation
    // mid-drag, watcher refresh), and destroying an active drag source
    // crashes Qt.
    function _startDrag() {
        var names = root.selected ? root.fileModel.selectedNamesJoined().split("\n") : [root.name]
        // Percent-encode each path segment: a bare space (or #, %, ?) in a
        // filename makes an invalid URI that strict receivers mangle or
        // reject; our own DropAreas decode symmetrically on the way in.
        var uris = names.map((n) => "file://" + root.fileModel.entryAbsolutePath(n).split("/").map(encodeURIComponent).join("/"))
        root.Window.window.startInternalDragWithGhost(
            uris.join("\r\n"), names.length,
            Format.iconForKey(root.iconKey, root.isDir), root.displayName)
    }

    width: ListView.view ? ListView.view.width : 0
    height: 60

    Accessible.role: Accessible.ListItem
    Accessible.name: root.isDir ? root.displayName + ", folder" : root.displayName
    Accessible.onPressAction: {
        if (root.isDir) {
            root.fileModel.navigate(root.fileModel.currentPath + "/" + root.name)
        } else {
            root.fileModel.openEntry(root.name)
        }
    }

    // Only images (raster + svg) and videos (one ffmpeg-extracted frame,
    // see fm_core::thumbnails) get a thumbnail — everything else keeps its
    // Material icon glyph. Requested lazily per-delegate rather than for
    // the whole folder up front, so a directory with thousands of photos
    // doesn't decode all of them at once; FileListModel itself no-ops a
    // repeat request for an entry that's already resolved or already in
    // flight.
    function _requestThumbnailIfNeeded() {
        if (root.fileModel && (root.iconKey === "image" || root.iconKey === "video") && root.thumbnailPath.length === 0) {
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
    // Persistent tint while selected — distinct from the transient
    // opacity-animated hover highlight below, which continues to layer on
    // top of it on hover.
    Rectangle {
        anchors.fill: parent
        radius: Shape.small
        color: Color.scheme.secondaryContainer
        opacity: root.selected ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }

    Rectangle {
        anchors.fill: parent
        radius: Shape.small
        color: Elevation.surfaceAt(1)
        opacity: rowArea.containsMouse ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }

    // M3 focus ring on the keyboard-cursor row — an outline, not a fill,
    // so it layers cleanly over both the selection tint and hover.
    Rectangle {
        anchors.fill: parent
        radius: Shape.small
        color: "transparent"
        border.width: 2
        border.color: Color.scheme.primary
        visible: root.isCursor
    }

    MouseArea {
        id: rowArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        property real _pressX: 0
        property real _pressY: 0
        property bool _dragging: false

        onPressed: (mouse) => {
            rowArea._pressX = mouse.x
            rowArea._pressY = mouse.y
            rowArea._dragging = false
        }
        onPositionChanged: (mouse) => {
            if (!rowArea.pressed || rowArea._dragging || !(rowArea.pressedButtons & Qt.LeftButton)) {
                return
            }
            var dx = mouse.x - rowArea._pressX
            var dy = mouse.y - rowArea._pressY
            if (Math.sqrt(dx * dx + dy * dy) < 6) {
                return
            }
            rowArea._dragging = true
            root._startDrag()
        }
        onReleased: {
            rowArea._dragging = false
        }
        onClicked: (mouse) => {
            if (rowArea._dragging) {
                return
            }
            if (mouse.button === Qt.MiddleButton) {
                if (root.isDir) {
                    root.Window.window.openPathInNewTab(root.fileModel.currentPath + "/" + root.name)
                }
                return
            }
            if (mouse.button === Qt.RightButton) {
                // Right-clicking an item already part of the selection
                // keeps the whole selection (so the menu can act on all of
                // it); right-clicking outside it replaces the selection
                // with just this entry, matching every reference file
                // manager.
                if (!root.selected) {
                    root.fileModel.clearSelection()
                    root.fileModel.setSelected(root.name, true)
                    root.ListView.view.selectionAnchor = root.name
                }
                var origin = root.mapToItem(null, 0, 0)
                root.Window.window.noteContainerSource(origin.x, origin.y, root.width, root.height)
                var scenePos = root.mapToItem(null, mouse.x, mouse.y)
                root.contextMenuRequested(scenePos.x, scenePos.y)
                return
            }
            if (mouse.modifiers & Qt.ShiftModifier) {
                root.fileModel.selectRange(root.ListView.view.selectionAnchor, root.name)
            } else if (mouse.modifiers & Qt.ControlModifier) {
                root.fileModel.setSelected(root.name, !root.selected)
                root.ListView.view.selectionAnchor = root.name
            } else {
                root.fileModel.clearSelection()
                root.fileModel.setSelected(root.name, true)
                root.ListView.view.selectionAnchor = root.name
            }
            // Arrow keys continue from the clicked row; focus bubbles
            // from the delegate up to fileViewArea's Keys handler.
            root.fileModel.setCursor(root.name)
            root.forceActiveFocus()
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

    // Folder rows are drop targets — accepts both our own internal drags
    // (moving an item into a subfolder) and an external file dropped
    // precisely on this row. An internal drag is always a move regardless
    // of drop.proposedAction — some platforms don't reliably reflect
    // Drag.proposedAction: Qt.MoveAction back on the DragEvent, which
    // silently turned every internal drag-to-move into a copy that left
    // the original behind. window._internalDragActive (not drop.keys,
    // which has the same cross-platform reliability problem) is what
    // detects "this is our own drag"; a genuinely external drop defers to
    // drop.proposedAction.
    DropArea {
        id: folderDropArea
        anchors.fill: parent
        enabled: root.isDir
        keys: ["text/uri-list"]

        // Spring-loaded folders (roadmap item 8): parking a drag over a
        // folder row for a beat navigates into it, so one drag can reach
        // a nested destination without dropping halfway. The Timer's
        // running state simply mirrors containsDrag — moving the drag off
        // the row before it fires cancels the spring-load.
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

    Row {
        anchors.fill: parent
        anchors.leftMargin: 12 + root.treeDepth * 24
        anchors.rightMargin: 12
        spacing: 12

        Item {
            width: 20
            height: 20
            anchors.verticalCenter: parent.verticalCenter

            Icon {
                anchors.centerIn: parent
                content: "chevron_right"
                iconSize: 18
                color: Color.scheme.surfaceVariantText
                visible: root.isDir && !root._searchActive
                rotation: root.isExpanded ? 90 : 0
                Behavior on rotation { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            }

            MouseArea {
                anchors.fill: parent
                enabled: root.isDir && !root._searchActive
                cursorShape: Qt.PointingHandCursor
                onClicked: root.fileModel.toggleExpanded(root.name)
            }
        }

        Item {
            width: root.iconContainerSize
            height: root.iconContainerSize
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                // Same tonal highlight as the hover case above, but for a
                // drag hovering over this folder mid-drop.
                anchors.fill: parent
                radius: Shape.medium
                color: Qt.alpha(Color.scheme.primary, 0.12)
                opacity: folderDropArea.containsDrag ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            }

            Icon {
                anchors.centerIn: parent
                content: Format.iconForKey(root.iconKey, root.isDir)
                iconSize: root.isDir ? Math.round(root.iconSize * 1.3) : root.iconSize
                color: root.isDir ? Color.folderIcon : Format.iconColorForKey(root.iconKey, Color.scheme.surfaceVariantText)
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

            // Play badge over video thumbnails — see FileGridItem.qml.
            Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: 14
                height: 14
                radius: Shape.full
                color: Qt.alpha("#000000", 0.55)
                visible: root.iconKey === "video" && thumbnail.status === Image.Ready

                Icon {
                    anchors.centerIn: parent
                    content: "play_arrow"
                    iconSize: 10
                    color: "#ffffff"
                }
            }
        }

        Column {
            width: parent.width - root.iconContainerSize - 44
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                text: root.displayName
                color: Color.scheme.surfaceText
                font.family: Type.bodyLarge.family
                font.weight: Type.bodyLarge.weight
                font.pixelSize: Type.bodyLarge.size
                elide: Text.ElideMiddle
                width: parent.width
            }

            Text {
                // Size for files plus a humanized modified time for
                // everything (round-2 item 20) — folders previously had
                // no secondary line at all.
                text: {
                    if (root.matchLine.length > 0) {
                        return root.matchLine
                    }
                    var parts = []
                    if (root.isDir) {
                        if (root.childCount >= 0) {
                            parts.push(root.childCount === 0
                                ? "Empty" : Format.formatItemCount(root.childCount))
                        }
                    } else {
                        parts.push(Format.formatBytes(root.size))
                    }
                    if (root.modified.length > 0) {
                        parts.push(Format.humanizeModified(root.modified))
                    }
                    return parts.join(" · ")
                }
                font.italic: root.matchLine.length > 0
                visible: text.length > 0
                elide: Text.ElideRight
                width: parent.width
                color: Color.scheme.surfaceVariantText
                font.family: Type.bodyMedium.family
                font.weight: Type.bodyMedium.weight
                font.pixelSize: Type.bodyMedium.size
            }
        }
    }
}
