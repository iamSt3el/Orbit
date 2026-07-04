import QtQuick
import com.filemanager.app 1.0

// A single global M3-style transient snackbar for surfacing failed
// operations and undoable-operation confirmations — see
// docs/superpowers/specs/2026-07-04-error-surfacing-design.md and
// docs/superpowers/specs/2026-07-04-undo-redo-design.md.
// One instance lives in main.qml; call show(message) on it, or
// show(message, actionLabel) to also render an action text button (e.g.
// "Undo") that emits actionClicked when pressed. Auto-dismisses after 4s —
// a new message while one is already showing replaces it and restarts the
// timer, rather than queuing multiple messages.
Item {
    id: root

    signal actionClicked()

    function show(text, actionLabel) {
        _label.text = text
        _action.label = actionLabel === undefined ? "" : actionLabel
        _bubble.visible = true
        _dismissTimer.restart()
    }

    anchors.fill: parent
    z: 5000

    Timer {
        id: _dismissTimer
        interval: 4000
        onTriggered: _bubble.visible = false
    }

    Rectangle {
        id: _bubble
        visible: false
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        width: Math.min(400, root.width - 48)
        height: Math.max(_label.implicitHeight, _action.implicitHeight) + 24
        radius: Shape.extraSmall
        color: Color.scheme.inverseSurface

        Text {
            id: _label
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.right: _action.visible ? _action.left : parent.right
            anchors.rightMargin: _action.visible ? 12 : 16
            anchors.verticalCenter: parent.verticalCenter
            text: ""
            wrapMode: Text.Wrap
            // Centered when it's a plain message (the original look);
            // left-aligned when sharing the row with an action button,
            // per the M3 snackbar layout.
            horizontalAlignment: _action.visible ? Text.AlignLeft : Text.AlignHCenter
            color: Color.scheme.inverseOnSurface
            font.family: Type.bodyMedium.family
            font.pixelSize: Type.bodyMedium.size
        }

        // M3 snackbar action: a text button tinted inversePrimary.
        Text {
            id: _action
            property string label: ""
            visible: label.length > 0
            text: label
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            color: Color.scheme.inversePrimary
            font.family: Type.labelLarge.family
            font.pixelSize: Type.labelLarge.size
            font.weight: Font.Medium

            MouseArea {
                anchors.fill: parent
                // Grown beyond the text so the tap target isn't tiny.
                anchors.margins: -10
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    _bubble.visible = false
                    root.actionClicked()
                }
            }
        }
    }
}
