import QtQuick
import "../util/format.js" as Format
import com.filemanager.app 1.0

// Preview/details pane (roadmap round-2 item 22): a right-side panel
// showing the single selected entry — full-size image preview for
// images, the Material glyph for everything else, plus the metadata the
// Properties dialog would show. Toggled by F9 / the header's info
// button; renders nothing useful when the selection isn't exactly one
// entry (main.qml hides it then).
Rectangle {
    id: root

    property var fileModel
    // The single selected entry's name ("" hides the content).
    property string entryName: ""

    // Re-queried whenever the name changes. \u{1f}-joined:
    // isDir, size, modified(ISO), mimeType, permissions, iconKey.
    readonly property var _info: {
        if (!fileModel || entryName.length === 0) {
            return null
        }
        var joined = fileModel.entryInfoJoined(entryName)
        if (joined.length === 0) {
            return null
        }
        var f = joined.split("\u001f")
        return {
            isDir: f[0] === "1",
            size: Number(f[1]),
            modified: f[2],
            mimeType: f[3],
            permissions: f[4],
            iconKey: f[5]
        }
    }

    color: Color.scheme.surfaceContainerHigh
    radius: Shape.largeIncreased

    Column {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 16
        spacing: 12
        visible: root._info !== null

        // Preview area: real image for images (decoded bounded via
        // sourceSize, straight from the file — no thumbnail cache
        // round-trip needed at this size), glyph for everything else.
        Item {
            width: parent.width
            height: 160

            Rectangle {
                anchors.fill: parent
                radius: Shape.large
                color: Elevation.surfaceAt(1)
            }

            Icon {
                anchors.centerIn: parent
                visible: previewImage.status !== Image.Ready
                content: root._info ? Format.iconForKey(root._info.iconKey, root._info.isDir) : "draft"
                iconSize: 64
                color: (root._info && root._info.isDir) ? Color.folderIcon
                    : (root._info ? Format.iconColorForKey(root._info.iconKey, Color.scheme.surfaceVariantText)
                                  : Color.scheme.surfaceVariantText)
            }

            Image {
                id: previewImage
                anchors.fill: parent
                anchors.margins: 8
                visible: status === Image.Ready
                source: (root._info && !root._info.isDir && root._info.iconKey === "image" && root.entryName.length > 0)
                    ? "file://" + root.fileModel.entryAbsolutePath(root.entryName).split("/").map(encodeURIComponent).join("/")
                    : ""
                sourceSize: Qt.size(480, 480)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }
        }

        Text {
            width: parent.width
            text: root.entryName
            color: Color.scheme.surfaceText
            font.family: Type.titleMedium.family
            font.weight: Type.titleMedium.weight
            font.pixelSize: Type.titleMedium.size
            elide: Text.ElideMiddle
        }

        Column {
            width: parent.width
            spacing: 8

            Repeater {
                model: root._info === null ? [] : [
                    { label: "Type", value: root._info.isDir ? "Folder" : root._info.mimeType },
                    { label: "Size", value: root._info.isDir ? "—" : Format.formatBytes(root._info.size) },
                    { label: "Modified", value: Format.formatModified(root._info.modified) },
                    { label: "Permissions", value: root._info.permissions }
                ]

                delegate: Column {
                    required property var modelData
                    width: parent.width
                    spacing: 1

                    Text {
                        text: parent.modelData.label
                        color: Color.scheme.surfaceVariantText
                        font.family: Type.labelMedium.family
                        font.weight: Type.labelMedium.weight
                        font.pixelSize: Type.labelMedium.size
                    }

                    Text {
                        width: parent.width
                        text: parent.modelData.value
                        color: Color.scheme.surfaceText
                        font.family: Type.bodyMedium.family
                        font.pixelSize: Type.bodyMedium.size
                        wrapMode: Text.Wrap
                    }
                }
            }
        }
    }

    // Placeholder when nothing (or multiple things) is selected.
    Text {
        anchors.centerIn: parent
        visible: root._info === null
        text: "Select one item\nto preview it"
        horizontalAlignment: Text.AlignHCenter
        color: Color.scheme.surfaceVariantText
        font.family: Type.bodyMedium.family
        font.pixelSize: Type.bodyMedium.size
    }
}
