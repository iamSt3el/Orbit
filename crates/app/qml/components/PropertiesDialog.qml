import QtQuick
import QtQuick.Layouts
import "../util/format.js" as Format
import com.filemanager.app 1.0

// A minimal custom modal dialog showing an entry's details. The facts are
// one continuous "grouped card" (see GroupCard.qml) — modeled on the
// user's quickshell "Nebula" settings screen — rather than separately
// rounded/gapped cards: only the first row has top corners, only the last
// has bottom corners, and the rows in between are nearly flat top and
// bottom so the whole group reads as one card.
Item {
    id: root

    property var fileModel
    property string entryName: ""
    property bool entryIsDir: false
    // real, not int — QML's int is 32-bit and silently truncates any file
    // over ~2.1GB; the model exposes size as a 64-bit value and real (a
    // JS double) can represent that exactly. This was why Properties
    // showed a wrong (or missing) size for larger files.
    property real entrySize: 0
    property string entryModified: ""
    property string entryMimeType: ""
    property string entryPermissions: ""

    anchors.fill: parent
    visible: false
    z: 2000

    property rect sourceRect: Qt.rect(0, 0, 0, 0)
    property real centerOffsetX: 0

    // See ContextMenu.qml — lets the Loader wrapping this component tear
    // the instance down once it hides.
    signal closed

    function open(name, isDir, size, modified, mimeType, permissions) {
        root.entryName = name
        root.entryIsDir = isDir
        root.entrySize = size
        root.entryModified = modified
        root.entryMimeType = mimeType
        root.entryPermissions = permissions
        // Folder sizes are computed by a background walk (Nautilus-style)
        // so the dialog opens instantly — the Size fact live-ticks from
        // the folderScan* properties until the walk lands.
        if (isDir && root.fileModel) {
            root.fileModel.startFolderSizeScan(name)
        }
        visible = true
        closeAnim.stop()
        openAnim.stop()
        if (root.sourceRect.width > 0) {
            card.x = root.sourceRect.x
            card.y = root.sourceRect.y
            card.width = root.sourceRect.width
            card.height = root.sourceRect.height
            card.radius = Shape.small
        } else {
            card.x = (root.width - card.finalW * 0.9) / 2 + root.centerOffsetX
            card.y = (root.height - card.finalH * 0.9) / 2
            card.width = card.finalW * 0.9
            card.height = card.finalH * 0.9
            card.radius = Shape.extraLarge
        }
        _scrim.opacity = 0
        _content.opacity = 0
        openAnim.restart()
        root.forceActiveFocus()
    }

    function close() {
        if (closeAnim.running) {
            return
        }
        openAnim.stop()
        if (root.entryIsDir && root.fileModel) {
            root.fileModel.cancelFolderSizeScan()
        }
        closeAnim.restart()
    }

    function _finishClose() {
        visible = false
        root.closed()
    }

    Keys.onEscapePressed: root.close()
    Keys.onShortcutOverride: (event) => {
        event.accepted = event.key === Qt.Key_Escape
    }

    readonly property bool _isImage: !root.entryIsDir && root.entryMimeType.indexOf("image/") === 0

    readonly property var _facts: [
        {
            icon: "category",
            label: "Type",
            value: root.entryIsDir ? "Folder" : root.entryMimeType
        },
        {
            icon: "storage",
            label: "Size",
            value: root.entryIsDir
                ? (root.fileModel
                    ? (root.fileModel.folderScanRunning && root.fileModel.folderScanBytes === 0
                        ? "Calculating…"
                        : Format.formatBytes(root.fileModel.folderScanBytes)
                            + " (" + Format.formatItemCount(root.fileModel.folderScanItems) + ")")
                    : "—")
                : Format.formatBytes(root.entrySize)
        },
        {
            icon: "lock",
            label: "Permissions",
            value: root.entryPermissions
        },
        {
            icon: "schedule",
            label: "Modified",
            value: Format.formatModified(root.entryModified)
        }
    ]

    Rectangle {
        id: _scrim
        anchors.fill: parent
        color: Color.scheme.surface
        opacity: 0.4

        MouseArea {
            // See ItemContextMenu.qml — must accept every button and track
            // hover so nothing underneath can still be interacted with
            // while this dialog is open.
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.AllButtons
            onClicked: root.close()
            onWheel: (wheel) => { wheel.accepted = true }
        }
    }

    ParallelAnimation {
        id: openAnim
        NumberAnimation { target: card; property: "x"; to: card.finalX; duration: Motion.emphasizedDecelerate.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.emphasizedDecelerate.bezier }
        NumberAnimation { target: card; property: "y"; to: card.finalY; duration: Motion.emphasizedDecelerate.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.emphasizedDecelerate.bezier }
        NumberAnimation { target: card; property: "width"; to: card.finalW; duration: Motion.emphasizedDecelerate.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.emphasizedDecelerate.bezier }
        NumberAnimation { target: card; property: "height"; to: card.finalH; duration: Motion.emphasizedDecelerate.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.emphasizedDecelerate.bezier }
        NumberAnimation { target: card; property: "radius"; to: Shape.extraLarge; duration: Motion.emphasizedDecelerate.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.emphasizedDecelerate.bezier }
        NumberAnimation { target: _scrim; property: "opacity"; to: 0.4; duration: Motion.standard.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.standard.bezier }
        SequentialAnimation {
            PauseAnimation { duration: Math.round(Motion.emphasizedDecelerate.duration * 0.3) }
            NumberAnimation { target: _content; property: "opacity"; to: 1; duration: Math.round(Motion.emphasizedDecelerate.duration * 0.7); easing.type: Easing.OutCubic }
        }
    }

    SequentialAnimation {
        id: closeAnim
        ParallelAnimation {
            NumberAnimation { target: card; property: "x"; to: root.sourceRect.width > 0 ? root.sourceRect.x : (root.width - card.finalW * 0.9) / 2 + root.centerOffsetX; duration: Motion.emphasizedAccelerate.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.emphasizedAccelerate.bezier }
            NumberAnimation { target: card; property: "y"; to: root.sourceRect.width > 0 ? root.sourceRect.y : (root.height - card.finalH * 0.9) / 2; duration: Motion.emphasizedAccelerate.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.emphasizedAccelerate.bezier }
            NumberAnimation { target: card; property: "width"; to: root.sourceRect.width > 0 ? root.sourceRect.width : card.finalW * 0.9; duration: Motion.emphasizedAccelerate.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.emphasizedAccelerate.bezier }
            NumberAnimation { target: card; property: "height"; to: root.sourceRect.width > 0 ? root.sourceRect.height : card.finalH * 0.9; duration: Motion.emphasizedAccelerate.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.emphasizedAccelerate.bezier }
            NumberAnimation { target: card; property: "radius"; to: root.sourceRect.width > 0 ? Shape.small : Shape.extraLarge; duration: Motion.emphasizedAccelerate.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.emphasizedAccelerate.bezier }
            NumberAnimation { target: _scrim; property: "opacity"; to: 0; duration: Motion.emphasizedAccelerate.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.emphasizedAccelerate.bezier }
            NumberAnimation { target: _content; property: "opacity"; to: 0; duration: Math.round(Motion.emphasizedAccelerate.duration * 0.5); easing.type: Easing.OutCubic }
        }
        ScriptAction { script: root._finishClose() }
    }

    Rectangle {
        id: card
        radius: Shape.extraLarge
        color: Elevation.surfaceAt(3)
        clip: true

        Accessible.role: Accessible.Dialog
        Accessible.name: "Properties"

        readonly property real finalW: Math.min(400, root.width - 40)
        readonly property real finalH: _content.implicitHeight + 40
        readonly property real finalX: (root.width - finalW) / 2 + root.centerOffsetX
        readonly property real finalY: (root.height - finalH) / 2

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onWheel: (wheel) => { wheel.accepted = true }
        }

        Column {
            id: _content
            x: 20
            y: 20
            width: card.finalW - 40
            spacing: 16

            Column {
                width: parent.width
                spacing: 8

                // Real preview for images instead of the generic file
                // glyph — loads the actual file directly (not the list
                // view's cached thumbnail, which may not exist yet if this
                // entry was never scrolled into view) since entryAbsolutePath
                // is already exposed for this and Image handles its own
                // async decode. Behind a Loader, not a plain Item — most
                // Properties opens are for folders/non-image files, where
                // this whole Rectangle+Image+Icon subtree (and the decoded
                // texture behind it) would otherwise exist for nothing.
                Loader {
                    width: parent.width
                    height: 160
                    active: root._isImage
                    visible: active

                    sourceComponent: Rectangle {
                        radius: Shape.medium
                        color: Elevation.surfaceAt(1)
                        clip: true

                        Image {
                            id: previewImage
                            anchors.fill: parent
                            anchors.margins: 4
                            visible: status === Image.Ready
                            source: root.fileModel
                                ? "file://" + root.fileModel.entryAbsolutePath(root.entryName)
                                : ""
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            sourceSize.height: 320
                        }

                        Icon {
                            anchors.centerIn: parent
                            content: "image"
                            iconSize: 32
                            color: Color.scheme.surfaceVariantText
                            visible: previewImage.status !== Image.Ready
                        }
                    }
                }

                Icon {
                    visible: !root._isImage
                    anchors.horizontalCenter: parent.horizontalCenter
                    content: root.entryIsDir ? "folder" : "description"
                    iconSize: 40
                    color: root.entryIsDir ? Color.folderIcon : Color.scheme.surfaceVariantText
                }

                Text {
                    text: root.entryName
                    color: Color.scheme.surfaceText
                    font.family: Type.titleMedium.family
                    font.weight: Type.titleMedium.weight
                    font.pixelSize: Type.titleMedium.size
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideMiddle
                    width: parent.width
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            // One continuous grouped card — only the group's outer edges
            // are rounded; the rows in between are nearly flat, matching
            // GroupCard.qml (and the Nebula settings screen it's modeled
            // on) rather than each fact being its own separately-rounded,
            // gapped card.
            Column {
                width: parent.width
                spacing: 3

                Repeater {
                    model: root._facts

                    delegate: GroupCard {
                        required property var modelData
                        required property int index
                        isFirst: index === 0
                        isLast: index === root._facts.length - 1

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Icon {
                                content: modelData.icon
                                iconSize: 20
                                color: Color.scheme.surfaceVariantText
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: modelData.label
                                    color: Color.scheme.surfaceVariantText
                                    font.family: Type.labelMedium.family
                                    font.weight: Type.labelMedium.weight
                                    font.pixelSize: Type.labelMedium.size
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.value
                                    color: Color.scheme.surfaceText
                                    font.family: Type.bodyLarge.family
                                    font.pixelSize: Type.bodyLarge.size
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }

            Row {
                anchors.right: parent.right

                Button {
                    variant: "text"
                    text: "Close"
                    onClicked: root.close()
                }
            }
        }
    }
}
