import QtQuick
import com.filemanager.app 1.0

// M3 Expressive split button (roadmap item 10), in ButtonGroup's
// connected-shape language: pill outer corners, tight inner corners, 2px
// gap. Leading segment switches to the view you'd switch TO (so its icon
// is the *other* mode's); trailing chevron opens the View options menu
// and springs its inner corners fully round while that menu is open.
Item {
    id: root

    property string viewMode: "list" // "list" | "grid"
    property bool menuOpen: false
    signal toggleRequested()
    signal menuRequested(real x, real y)

    readonly property real fullRadius: height / 2
    readonly property real innerRadius: 4

    height: 32
    implicitWidth: _lead.width + 2 + _trail.width

    Rectangle {
        id: _lead
        width: 44
        height: parent.height
        anchors.left: parent.left
        color: Color.scheme.surfaceContainerHighest
        topLeftRadius: root.fullRadius
        bottomLeftRadius: root.fullRadius
        topRightRadius: root.innerRadius
        bottomRightRadius: root.innerRadius

        Icon {
            anchors.centerIn: parent
            content: root.viewMode === "grid" ? "view_list" : "grid_view"
            iconSize: 16
            color: Color.scheme.surfaceText
        }

        Ripple {
            id: _leadRipple
            anchors.fill: parent
            topLeftRadius: root.fullRadius
            bottomLeftRadius: root.fullRadius
            topRightRadius: root.innerRadius
            bottomRightRadius: root.innerRadius
            hoverColor: Qt.alpha(Color.scheme.primary, 0.08)
            rippleColor: Qt.alpha(Color.scheme.primary, 0.25)
            onClicked: root.toggleRequested()
        }

        Tooltip {
            text: root.viewMode === "grid" ? "Switch to list view" : "Switch to grid view"
            hovered: _leadRipple.containsMouse
        }
    }

    Rectangle {
        id: _trail
        width: 28
        height: parent.height
        anchors.right: parent.right
        color: Color.scheme.surfaceContainerHighest
        topRightRadius: root.fullRadius
        bottomRightRadius: root.fullRadius
        // The M3 Expressive split-button open morph: inner corners spring
        // fully round while the menu is up.
        topLeftRadius: root.menuOpen ? root.fullRadius : root.innerRadius
        bottomLeftRadius: root.menuOpen ? root.fullRadius : root.innerRadius
        Behavior on topLeftRadius {
            SpringAnimation {
                spring: Motion.springStandard.spring
                damping: Motion.springStandard.damping
            }
        }
        Behavior on bottomLeftRadius {
            SpringAnimation {
                spring: Motion.springStandard.spring
                damping: Motion.springStandard.damping
            }
        }

        Icon {
            anchors.centerIn: parent
            content: "arrow_drop_down"
            iconSize: 18
            color: Color.scheme.surfaceText
        }

        Ripple {
            id: _trailRipple
            anchors.fill: parent
            topRightRadius: root.fullRadius
            bottomRightRadius: root.fullRadius
            topLeftRadius: root.menuOpen ? root.fullRadius : root.innerRadius
            bottomLeftRadius: root.menuOpen ? root.fullRadius : root.innerRadius
            hoverColor: Qt.alpha(Color.scheme.primary, 0.08)
            rippleColor: Qt.alpha(Color.scheme.primary, 0.25)
            onClicked: {
                var scenePos = _trail.mapToItem(null, 0, _trail.height)
                root.menuRequested(scenePos.x, scenePos.y)
            }
        }

        Tooltip {
            text: "View options"
            hovered: _trailRipple.containsMouse
        }
    }
}
