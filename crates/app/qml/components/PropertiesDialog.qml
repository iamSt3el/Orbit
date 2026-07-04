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
        visible = true
    }

    function close() {
        visible = false
        root.closed()
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
                    ? Format.formatBytes(root.fileModel.folderSize(root.entryName)) + " (" + Format.formatItemCount(root.fileModel.folderItemCount(root.entryName)) + ")"
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
        }
    }

    Rectangle {
        width: Math.min(400, root.width - 40)
        height: _content.implicitHeight + 40
        radius: Shape.extraLarge
        color: Elevation.surfaceAt(3)
        anchors.centerIn: parent

        Column {
            id: _content
            anchors.fill: parent
            anchors.margins: 20
            spacing: 16

            Column {
                width: parent.width
                spacing: 8

                // Real preview for images instead of the generic file
                // glyph — loads the actual file directly (not the list
                // view's cached thumbnail, which may not exist yet if this
                // entry was never scrolled into view) since entryAbsolutePath
                // is already exposed for this and Image handles its own
                // async decode.
                Item {
                    visible: root._isImage
                    width: parent.width
                    height: 160

                    Rectangle {
                        anchors.fill: parent
                        radius: Shape.medium
                        color: Elevation.surfaceAt(1)
                        clip: true

                        Image {
                            id: previewImage
                            anchors.fill: parent
                            anchors.margins: 4
                            visible: status === Image.Ready
                            source: root._isImage && root.fileModel
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
                    color: root.entryIsDir ? Color.scheme.primary : Color.scheme.surfaceVariantText
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
