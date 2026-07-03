import QtQuick
import "../util/format.js" as Format
import com.filemanager.app 1.0

// A minimal custom modal dialog showing an entry's details.
Item {
    id: root

    property string entryName: ""
    property bool entryIsDir: false
    property int entrySize: 0
    property string entryModified: ""
    property string entryMimeType: ""
    property string entryPermissions: ""

    anchors.fill: parent
    visible: false
    z: 2000

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
    }

    Rectangle {
        anchors.fill: parent
        color: Color.scheme.inverseSurface
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
        width: 360
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

                Icon {
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

            Rectangle {
                width: parent.width
                height: _infoColumn.implicitHeight + 16
                radius: Shape.medium
                color: Color.scheme.surfaceContainerHigh

                Column {
                    id: _infoColumn
                    anchors.fill: parent
                    anchors.margins: 8

                    Repeater {
                        model: [
                            { label: "Type", value: root.entryIsDir ? "Folder" : root.entryMimeType },
                            { label: "Size", value: root.entryIsDir ? "—" : Format.formatBytes(root.entrySize) },
                            { label: "Permissions", value: root.entryPermissions },
                            { label: "Modified", value: Format.formatModified(root.entryModified) }
                        ]

                        delegate: Row {
                            required property var modelData
                            width: _infoColumn.width
                            height: 36
                            spacing: 8

                            Text {
                                text: modelData.label
                                color: Color.scheme.surfaceVariantText
                                font.family: Type.bodyMedium.family
                                font.pixelSize: Type.bodyMedium.size
                                width: 92
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: modelData.value
                                color: Color.scheme.surfaceText
                                font.family: Type.bodyMedium.family
                                font.pixelSize: Type.bodyMedium.size
                                elide: Text.ElideRight
                                width: parent.width - 100
                                anchors.verticalCenter: parent.verticalCenter
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
