import QtQuick
import com.filemanager.app 1.0

// A minimal custom modal dialog (no Qt Quick Controls Dialog) for entering
// a new folder name, shown from the right-click context menu.
Item {
    id: root

    signal accepted(string name)

    anchors.fill: parent
    visible: false
    z: 2000

    function open() {
        nameInput.text = ""
        visible = true
        nameInput.forceActiveFocus()
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
        width: 320
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
                text: "New folder"
                color: Color.scheme.surfaceText
                font.family: Type.titleMedium.family
                font.weight: Type.titleMedium.weight
                font.pixelSize: Type.titleMedium.size
            }

            Rectangle {
                width: parent.width
                height: 44
                radius: Shape.small
                color: Color.scheme.surfaceContainerHighest
                border.width: nameInput.activeFocus ? 2 : 1
                border.color: nameInput.activeFocus ? Color.scheme.primary : Color.scheme.outline

                Behavior on border.width { NumberAnimation { duration: Motion.standard.duration } }

                TextInput {
                    id: nameInput
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    color: Color.scheme.surfaceText
                    font.family: Type.bodyLarge.family
                    font.pixelSize: Type.bodyLarge.size
                    clip: true

                    Keys.onReturnPressed: confirmButton.clicked()
                    Keys.onEscapePressed: root.close()
                }
            }

            Row {
                anchors.right: parent.right
                spacing: 8

                Button {
                    variant: "text"
                    text: "Cancel"
                    onClicked: root.close()
                }

                Button {
                    id: confirmButton
                    variant: "filled"
                    text: "Create"
                    onClicked: {
                        if (nameInput.text.length > 0) {
                            root.accepted(nameInput.text)
                            root.close()
                        }
                    }
                }
            }
        }
    }
}
