import QtQuick
import com.filemanager.app 1.0

// A minimal custom modal dialog showing an entry's details.
Item {
    id: root

    property string entryName: ""
    property bool entryIsDir: false
    property int entrySize: 0
    property string entryModified: ""
    property string entryMimeType: ""

    anchors.fill: parent
    visible: false
    z: 2000

    function open(name, isDir, size, modified, mimeType) {
        root.entryName = name
        root.entryIsDir = isDir
        root.entrySize = size
        root.entryModified = modified
        root.entryMimeType = mimeType
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
            anchors.fill: parent
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
            spacing: 12

            Row {
                width: parent.width
                spacing: 12

                Rectangle {
                    width: 40
                    height: 40
                    radius: Shape.medium
                    color: root.entryIsDir ? Qt.alpha(Color.scheme.primary, 0.12) : "transparent"

                    Icon {
                        anchors.centerIn: parent
                        content: root.entryIsDir ? "folder" : "description"
                        iconSize: 24
                        color: root.entryIsDir ? Color.scheme.primary : Color.scheme.surfaceVariantText
                    }
                }

                Text {
                    text: root.entryName
                    color: Color.scheme.surfaceText
                    font.family: Type.titleMedium.family
                    font.weight: Type.titleMedium.weight
                    font.pixelSize: Type.titleMedium.size
                    elide: Text.ElideMiddle
                    width: parent.width - 52
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Repeater {
                model: [
                    { label: "Type", value: root.entryIsDir ? "Folder" : root.entryMimeType },
                    { label: "Size", value: root.entryIsDir ? "—" : (root.entrySize + " bytes") },
                    { label: "Modified", value: root.entryModified }
                ]

                delegate: Row {
                    required property var modelData
                    width: parent.width
                    spacing: 8

                    Text {
                        text: modelData.label
                        color: Color.scheme.surfaceVariantText
                        font.family: Type.bodyMedium.family
                        font.pixelSize: Type.bodyMedium.size
                        width: 80
                    }

                    Text {
                        text: modelData.value
                        color: Color.scheme.surfaceText
                        font.family: Type.bodyMedium.family
                        font.pixelSize: Type.bodyMedium.size
                        elide: Text.ElideRight
                        width: parent.width - 88
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
