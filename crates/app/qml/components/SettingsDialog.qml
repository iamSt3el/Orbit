import QtQuick
import com.filemanager.app 1.0

// A minimal custom modal settings dialog (mirrors ConfirmDialog.qml's
// structure), opened from Sidebar's gear icon.
Item {
    id: root

    property var fileModel
    property bool resumeLastPath: true

    anchors.fill: parent
    visible: false
    z: 2000

    function open() {
        if (root.fileModel) {
            root.resumeLastPath = root.fileModel.resumeLastPath
        }
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
        id: dialog
        width: 360
        height: _column.implicitHeight + 40
        radius: Shape.extraLarge
        color: Elevation.surfaceAt(3)
        anchors.centerIn: parent

        Column {
            id: _column
            anchors.fill: parent
            anchors.margins: 20
            spacing: 16

            Text {
                text: "Settings"
                color: Color.scheme.surfaceText
                font.family: Type.titleMedium.family
                font.weight: Type.titleMedium.weight
                font.pixelSize: Type.titleMedium.size
            }

            Item {
                width: parent.width
                height: 40

                Text {
                    text: "Resume last folder on startup"
                    width: parent.width - 52
                    wrapMode: Text.Wrap
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    color: Color.scheme.surfaceText
                    font.family: Type.bodyLarge.family
                    font.pixelSize: Type.bodyLarge.size
                }

                Rectangle {
                    width: 40
                    height: 22
                    radius: Shape.full
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.resumeLastPath ? Color.scheme.primary : Color.scheme.surfaceContainerHighest
                    border.width: root.resumeLastPath ? 0 : 1
                    border.color: Color.scheme.outline
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Rectangle {
                        width: 16
                        height: 16
                        radius: Shape.full
                        color: Color.scheme.surface
                        anchors.verticalCenter: parent.verticalCenter
                        x: root.resumeLastPath ? parent.width - width - 3 : 3
                        Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.resumeLastPath = !root.resumeLastPath
                        if (root.fileModel) {
                            root.fileModel.resumeLastPath = root.resumeLastPath
                            root.fileModel.saveSettings()
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Color.scheme.outlineVariant
            }

            Item {
                width: parent.width
                height: 40

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Icon {
                        content: "refresh"
                        iconSize: 18
                        color: Color.scheme.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "Reload theme colors"
                        color: Color.scheme.primary
                        font.family: Type.bodyLarge.family
                        font.pixelSize: Type.bodyLarge.size
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.fileModel) {
                            Color.applyCustomColors(root.fileModel.readThemeColorsFile())
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Color.scheme.outlineVariant
            }

            Text {
                text: "Config folder"
                color: Color.scheme.surfaceVariantText
                font.family: Type.labelMedium.family
                font.weight: Type.labelMedium.weight
                font.pixelSize: Type.labelMedium.size
            }

            Text {
                text: root.fileModel ? root.fileModel.appConfigDir : ""
                width: parent.width
                elide: Text.ElideMiddle
                color: Color.scheme.surfaceText
                font.family: Type.bodyMedium.family
                font.pixelSize: Type.bodyMedium.size
            }

            Row {
                anchors.right: parent.right
                spacing: 8

                Button {
                    variant: "text"
                    text: "Close"
                    onClicked: root.close()
                }
            }
        }
    }
}
