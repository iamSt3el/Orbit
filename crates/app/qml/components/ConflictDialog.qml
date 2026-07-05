import QtQuick
import com.filemanager.app 1.0

// Copy/move conflict resolution (roadmap round-2 item 15): shown when a
// paste/drop would land on existing names. One decision applies to the
// whole batch. Keep both (the historical default behavior) leads;
// Replace trashes the existing files first; Skip leaves conflicting
// sources untransferred; dismissing the dialog cancels the transfer.
Item {
    id: root

    // "replace" | "skip" | "keepBoth" | "cancel"
    signal resolved(string mode)
    // See ContextMenu.qml — lets the Loader wrapping this component tear
    // the instance down once it hides.
    signal closed

    property var conflictNames: []
    property int conflictCount: 0

    anchors.fill: parent
    visible: false
    z: 2000

    function open(namesJoined, count) {
        root.conflictNames = namesJoined.length > 0 ? namesJoined.split("\n") : []
        root.conflictCount = count
        visible = true
        root.forceActiveFocus()
    }

    function finish(mode) {
        visible = false
        root.resolved(mode)
        root.closed()
    }

    Keys.onEscapePressed: root.finish("cancel")

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
            onClicked: root.finish("cancel")
        }
    }

    Rectangle {
        id: dialog
        width: 380
        height: _column.implicitHeight + 40
        radius: Shape.extraLarge
        color: Elevation.surfaceAt(3)
        anchors.centerIn: parent

        Column {
            id: _column
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            Text {
                text: root.conflictCount === 1 ? "File already exists" : "Files already exist"
                color: Color.scheme.surfaceText
                font.family: Type.titleMedium.family
                font.weight: Type.titleMedium.weight
                font.pixelSize: Type.titleMedium.size
            }

            Text {
                width: parent.width
                text: (root.conflictCount === 1
                    ? "1 item in this folder has the same name."
                    : root.conflictCount + " items in this folder have the same names.")
                    + " What should happen to them?"
                wrapMode: Text.Wrap
                color: Color.scheme.surfaceVariantText
                font.family: Type.bodyMedium.family
                font.pixelSize: Type.bodyMedium.size
            }

            // First few conflicting names, so the decision isn't blind.
            Column {
                width: parent.width
                spacing: 2

                Repeater {
                    model: root.conflictNames.slice(0, 4)

                    delegate: Text {
                        required property var modelData
                        width: parent.width
                        text: "•  " + modelData
                        elide: Text.ElideMiddle
                        color: Color.scheme.surfaceText
                        font.family: Type.bodyMedium.family
                        font.pixelSize: Type.bodyMedium.size
                    }
                }

                Text {
                    visible: root.conflictNames.length > 4
                    text: "…and " + (root.conflictNames.length - 4) + " more"
                    color: Color.scheme.surfaceVariantText
                    font.family: Type.bodyMedium.family
                    font.pixelSize: Type.bodyMedium.size
                }
            }

            Row {
                anchors.right: parent.right
                spacing: 8

                Button {
                    variant: "text"
                    text: "Cancel"
                    onClicked: root.finish("cancel")
                }

                Button {
                    variant: "text"
                    text: "Skip"
                    onClicked: root.finish("skip")
                }

                Button {
                    variant: "outlined"
                    text: "Replace"
                    destructive: true
                    tooltip: "Existing files go to Trash"
                    onClicked: root.finish("replace")
                }

                Button {
                    variant: "filled"
                    text: "Keep both"
                    onClicked: root.finish("keepBoth")
                }
            }
        }
    }
}
