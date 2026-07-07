import QtQuick
import com.filemanager.app 1.0

// A minimal custom modal confirmation dialog, mirroring RenameDialog.qml's
// structure. Used to gate destructive actions (currently: delete) behind an
// explicit yes/no.
Item {
    id: root

    property string title: "Delete"
    property string message: ""
    property string confirmLabel: "Delete"
    signal confirmed
    // See ContextMenu.qml — lets the Loader wrapping this component tear
    // the instance down once it hides.
    signal closed

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

    function open(msg) {
        root.message = msg
        visible = true
        _transition.enter()
        root.forceActiveFocus()
    }

    function close() {
        _transition.exit()
    }

    Keys.onEscapePressed: root.close()

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
        }
    }

    Rectangle {
        id: dialog
        Accessible.role: Accessible.Dialog
        Accessible.name: root.title
        width: 320
        height: _column.implicitHeight + 40
        radius: Shape.extraLarge
        color: Elevation.surfaceAt(3)
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: root.centerOffsetX

        Column {
            id: _column
            anchors.fill: parent
            anchors.margins: 20
            spacing: 16

            Text {
                text: root.title
                color: Color.scheme.surfaceText
                font.family: Type.titleMedium.family
                font.weight: Type.titleMedium.weight
                font.pixelSize: Type.titleMedium.size
            }

            Text {
                text: root.message
                width: parent.width
                wrapMode: Text.Wrap
                color: Color.scheme.surfaceVariantText
                font.family: Type.bodyMedium.family
                font.pixelSize: Type.bodyMedium.size
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
                    variant: "filled"
                    destructive: true
                    text: root.confirmLabel
                    onClicked: {
                        root.confirmed()
                        root.close()
                    }
                }
            }
        }
    }
}
