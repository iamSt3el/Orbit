import QtQuick
import QtQuick.Window
import com.orbit.app 1.0

// M3 plain tooltip. Drop one inside any hoverable button and bind `hovered`
// to that button's own MouseArea/Ripple `containsMouse`:
//
//   Tooltip { text: "Back"; hovered: _backArea.containsMouse }
//
// Reparents itself to the top-level Window's contentItem on completion, so
// it always paints above sibling content and is never cut off by an
// ancestor's `clip: true` — a plain child of the button would otherwise be
// clipped (most buttons live inside clipped panels) or painted behind
// later-drawn siblings (paint order follows tree position, not z, across
// different parents).
Item {
    id: root

    property string text: ""
    // Defaults to the Item this Tooltip is declared inside — override only
    // when the tooltip should track a different item than its own parent.
    // Captured once in Component.onCompleted (see below), not a live
    // binding to root.parent — reparenting to the Window below would
    // otherwise retarget it at the window's contentItem instead.
    property Item anchorItem: null
    property bool hovered: false
    property int delay: 500
    property string edge: "below" // "above" | "below"

    readonly property int _gap: 6

    visible: false
    z: 10000
    width: _bubble.implicitWidth
    height: _bubble.implicitHeight

    Component.onCompleted: {
        if (root.anchorItem === null) {
            root.anchorItem = root.parent
        }
        var win = root.Window.window
        if (win && win.contentItem) {
            root.parent = win.contentItem
        }
    }

    function _reposition() {
        if (!root.anchorItem || !root.parent) {
            return
        }
        var topLeft = root.anchorItem.mapToItem(root.parent, 0, 0)
        root.x = topLeft.x + (root.anchorItem.width - root.width) / 2
        root.y = root.edge === "above"
            ? topLeft.y - root.height - root._gap
            : topLeft.y + root.anchorItem.height + root._gap
    }

    Timer {
        id: _showTimer
        interval: root.delay
        onTriggered: {
            root._reposition()
            root.visible = true
        }
    }

    onHoveredChanged: {
        if (root.hovered && root.text.length > 0) {
            _showTimer.restart()
        } else {
            _showTimer.stop()
            root.visible = false
        }
    }

    Rectangle {
        id: _bubble
        implicitWidth: _label.implicitWidth + 16
        implicitHeight: _label.implicitHeight + 8
        radius: Shape.extraSmall
        color: Color.scheme.inverseSurface

        Text {
            id: _label
            anchors.centerIn: parent
            text: root.text
            color: Color.scheme.inverseOnSurface
            font.family: Type.labelSmall.family
            font.weight: Type.labelSmall.weight
            font.pixelSize: Type.labelSmall.size
        }
    }
}
