import QtQuick
import QtQuick.Layouts
import com.filemanager.app 1.0

// A minimal custom modal settings dialog (mirrors ConfirmDialog.qml's
// structure), opened from Sidebar's gear icon. Rows are grouped into
// GroupCard sections with a small section label above each, matching the
// user's quickshell "Nebula" settings screen.
Item {
    id: root

    property var fileModel
    property bool resumeLastPath: true
    // See ContextMenu.qml — lets the Loader wrapping this component tear
    // the instance down once it hides.
    signal closed

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
        root.closed()
    }

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

            Text {
                text: "General"
                color: Color.scheme.primary
                font.family: Type.labelMedium.family
                font.weight: Type.labelMedium.weight
                font.pixelSize: Type.labelMedium.size
            }

            Column {
                width: parent.width
                spacing: 3

                GroupCard {
                    isFirst: true
                    isLast: false

                    // A plain anchors-based row (not RowLayout) — Qt Quick
                    // Layouts don't support anchoring a MouseArea to a
                    // layout-managed sibling, and the whole row (not just
                    // the switch) should be clickable.
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: 40

                        Text {
                            anchors.left: parent.left
                            anchors.right: toggleTrack.left
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Resume last folder on startup"
                            wrapMode: Text.Wrap
                            color: Color.scheme.surfaceText
                            font.family: Type.bodyLarge.family
                            font.pixelSize: Type.bodyLarge.size
                        }

                        Rectangle {
                            id: toggleTrack
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
                }

                GroupCard {
                    isFirst: false
                    isLast: true

                    Item {
                        Layout.fillWidth: true
                        implicitHeight: 40

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
                }
            }

            Text {
                text: "Info"
                color: Color.scheme.primary
                font.family: Type.labelMedium.family
                font.weight: Type.labelMedium.weight
                font.pixelSize: Type.labelMedium.size
            }

            GroupCard {
                width: parent.width
                isFirst: true
                isLast: true

                Column {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: "Config folder"
                        color: Color.scheme.surfaceVariantText
                        font.family: Type.labelMedium.family
                        font.weight: Type.labelMedium.weight
                        font.pixelSize: Type.labelMedium.size
                    }

                    Text {
                        width: parent.width
                        text: root.fileModel ? root.fileModel.appConfigDir : ""
                        elide: Text.ElideMiddle
                        color: Color.scheme.surfaceText
                        font.family: Type.bodyMedium.family
                        font.pixelSize: Type.bodyMedium.size
                    }
                }
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
