import QtQuick
import com.filemanager.app 1.0

// A single global M3-style transient snackbar for surfacing failed
// operations (create/rename/delete/paste/etc.) that would otherwise fail
// silently — see docs/superpowers/specs/2026-07-04-error-surfacing-design.md.
// One instance lives in main.qml; call show(message) on it. Auto-dismisses
// after 4s — a new message while one is already showing replaces it and
// restarts the timer, rather than queuing multiple messages.
Item {
    id: root

    function show(text) {
        _label.text = text
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
        height: _label.implicitHeight + 24
        radius: Shape.extraSmall
        color: Color.scheme.inverseSurface

        Text {
            id: _label
            anchors.centerIn: parent
            width: parent.width - 32
            text: ""
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            color: Color.scheme.inverseOnSurface
            font.family: Type.bodyMedium.family
            font.pixelSize: Type.bodyMedium.size
        }
    }
}
