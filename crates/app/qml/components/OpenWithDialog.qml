import QtQuick
import com.filemanager.app 1.0

// "Open with…" chooser (roadmap round-2 item 26): lists installed apps
// whose desktop entries claim the file's mime type; clicking one
// launches it on the file. Same modal-scrim pattern as the other
// dialogs.
Item {
    id: root

    property var fileModel
    signal closed

    property string entryName: ""
    // Array of { name, exec } parsed from openWithApps().
    property var apps: []

    anchors.fill: parent
    visible: false
    z: 2000

    property real centerOffsetX: 0

    ModalTransition {
        id: _transition
        card: dialog
        scrim: _scrim
        onExited: {
            root.visible = false
            root.closed()
        }
    }

    function open(name) {
        root.entryName = name
        var joined = root.fileModel ? root.fileModel.openWithApps(name) : ""
        var parsed = []
        if (joined.length > 0) {
            var lines = joined.split("\n")
            for (var i = 0; i < lines.length; i++) {
                var parts = lines[i].split("\u001f")
                if (parts.length >= 2) {
                    parsed.push({ name: parts[0], exec: parts[1], iconPath: parts.length > 2 ? parts[2] : "" })
                }
            }
        }
        root.apps = parsed
        visible = true
        _transition.enter()
        root.forceActiveFocus()
    }

    function close() {
        _transition.exit()
    }

    Keys.onEscapePressed: root.close()
    Keys.onShortcutOverride: (event) => {
        event.accepted = event.key === Qt.Key_Escape
    }

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

    Rectangle {
        id: dialog
        width: 340
        height: Math.min(460, _header.height + 24 + Math.max(52, appList.contentHeight) + 20)
        radius: Shape.extraLarge
        color: Elevation.surfaceAt(3)
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: root.centerOffsetX

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onWheel: (wheel) => { wheel.accepted = true }
        }

        Column {
            id: _header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 20
            spacing: 4

            Text {
                text: "Open with"
                color: Color.scheme.surfaceText
                font.family: Type.titleMedium.family
                font.weight: Type.titleMedium.weight
                font.pixelSize: Type.titleMedium.size
            }

            Text {
                width: parent.width
                text: root.entryName
                color: Color.scheme.surfaceVariantText
                font.family: Type.bodyMedium.family
                font.pixelSize: Type.bodyMedium.size
                elide: Text.ElideMiddle
            }
        }

        ListView {
            id: appList
            anchors.top: _header.bottom
            anchors.topMargin: 12
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            anchors.bottomMargin: 12
            clip: true
            model: root.apps

            delegate: Item {
                id: appRow
                required property var modelData
                width: appList.width
                height: 44

                Rectangle {
                    anchors.fill: parent
                    radius: Shape.small
                    color: Elevation.surfaceAt(1)
                    opacity: _appArea.containsMouse ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    spacing: 12

                    Item {
                        width: 24
                        height: 24
                        anchors.verticalCenter: parent.verticalCenter

                        Image {
                            id: _appImage
                            anchors.fill: parent
                            visible: status === Image.Ready
                            source: appRow.modelData.iconPath.length > 0
                                ? "file://" + appRow.modelData.iconPath : ""
                            sourceSize.width: 48
                            sourceSize.height: 48
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                        }

                        Icon {
                            anchors.centerIn: parent
                            visible: _appImage.status !== Image.Ready
                            content: "apps"
                            iconSize: 20
                            color: Color.scheme.primary
                        }
                    }

                    Text {
                        text: appRow.modelData.name
                        color: Color.scheme.surfaceText
                        font.family: Type.bodyLarge.family
                        font.pixelSize: Type.bodyLarge.size
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: _appArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.fileModel.openEntryWith(root.entryName, appRow.modelData.exec)
                        root.close()
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: root.apps.length === 0
                text: "No installed apps claim this file type"
                color: Color.scheme.surfaceVariantText
                font.family: Type.bodyMedium.family
                font.pixelSize: Type.bodyMedium.size
            }
        }
    }
}
