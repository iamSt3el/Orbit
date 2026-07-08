import QtQuick
import QtQuick.Layouts
import com.orbit.app 1.0

// The content pane's own header row — back button, current path/search,
// view options, and the list/grid switch. Deliberately not a separate
// floating/colored bar: it lives directly on the unified card's
// surfaceContainer background, matching the "right layout" that groups
// content-scoped controls with the content they act on.
Item {
    id: root

    property string title: ""
    property bool showBackButton: false
    property string viewMode: "list" // "list" | "grid"
    property var fileModel
    property bool viewOptionsOpen: false
    property bool canGoBack: false
    property bool canGoForward: false
    property bool showMenuButton: false
    signal menuClicked
    signal backClicked
    signal forwardClicked
    signal upClicked
    signal listViewRequested
    signal gridViewRequested
    signal optionsRequested(real x, real y)

    height: 56

    function startPathEdit() {
        pathBar.startEditing()
    }

    function startSearch() {
        pathBar.searching = true
    }

    // The hover-circle icon-button pattern shared by the nav cluster —
    // icon as a sibling of the highlight (see the old back button's
    // comment), plus a disabled look for history edges.
    component NavButton: Item {
        id: nav
        property string icon: ""
        property string tip: ""
        property bool available: true
        signal activated()
        implicitWidth: 40
        implicitHeight: 40

        Accessible.role: Accessible.Button
        Accessible.name: nav.tip
        Accessible.onPressAction: if (nav.available) nav.activated()

        Rectangle {
            anchors.fill: parent
            radius: Shape.full
            color: Elevation.surfaceAt(3)
            opacity: (_navArea.containsMouse && nav.available) ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }

        Icon {
            anchors.centerIn: parent
            content: nav.icon
            iconSize: 20
            color: Color.scheme.surfaceText
            opacity: nav.available ? 1 : 0.35
        }

        MouseArea {
            id: _navArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: nav.available ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (nav.available) nav.activated()
        }

        Tooltip {
            text: nav.tip
            hovered: _navArea.containsMouse
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 16
        spacing: 8

        // Browser-style navigation cluster (roadmap item 14): back and
        // forward walk the history stacks; up goes to the parent folder
        // (the old back button's job). Disabled ends stay visible so the
        // header doesn't reflow as history changes.
        Row {
            id: _navCluster
            spacing: 8

            NavButton {
                visible: root.showMenuButton
                icon: "menu"
                tip: "Sidebar"
                onActivated: root.menuClicked()
            }

            NavButton {
                icon: "arrow_back"
                tip: "Back"
                available: root.canGoBack
                onActivated: root.backClicked()
            }

            NavButton {
                icon: "arrow_forward"
                tip: "Forward"
                available: root.canGoForward
                onActivated: root.forwardClicked()
            }

            NavButton {
                icon: "arrow_upward"
                tip: "Up"
                available: root.showBackButton
                onActivated: root.upClicked()
            }
        }

        // A flexible spacer on each side of PathBar, equal weight, is what
        // centers it in the row — matched pair, not just "fill the rest".
        Item {
            Layout.fillWidth: true
        }

        PathBar {
            id: pathBar
            Layout.preferredHeight: 40
            // Proportional to the header's own width (clamped so it never
            // gets uselessly tiny on a narrow window or absurdly wide on an
            // ultrawide one), not a fixed pixel size — the M3 adaptive-layout
            // principle applied to this one control instead of a full
            // window-size-class system, since that's all this bar needs.
            // Search is roughly half the width of the plain path display.
            // Spring-animated per M3 Expressive motion — a resize this
            // visible reads as a snap without it.
            readonly property real _availableWidth:
                Math.max(100, root.width - 28 - _navCluster.width - _splitButton.width - 60)
            Layout.preferredWidth: Math.min(_availableWidth, pathBar.searching
                ? Math.max(220, Math.min(480, root.width * 0.34))
                : Math.max(320, Math.min(900, root.width * 0.68)))
            Behavior on Layout.preferredWidth {
                SpringAnimation {
                    spring: Motion.springStandard.spring
                    damping: Motion.springStandard.damping
                }
            }
            path: root.title
            fileModel: root.fileModel
        }

        Item {
            Layout.fillWidth: true
        }

        // Shape-morph loader — visible only while a background file
        // operation (copy/move) is running. The sidebar's TransferStatus
        // carries the actual detail (speed/done/total); this is just an
        // ambient "something is happening" cue near the trailing controls.
        ShapeLoader {
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            size: 20
            // Ternary, not `&&`: with fileModel undefined the && chain
            // yields undefined itself, which can't assign to a bool.
            visible: root.fileModel ? root.fileModel.isBusy : false
            running: visible
            color: Color.scheme.primary
        }

        // Split button (roadmap item 10): leading side switches list/grid,
        // trailing chevron opens View options — replaces the old separate
        // segmented toggle + tune icon button.
        SplitButton {
            id: _splitButton
            Layout.preferredHeight: 32
            viewMode: root.viewMode
            menuOpen: root.viewOptionsOpen
            onToggleRequested: root.viewMode === "grid" ? root.listViewRequested() : root.gridViewRequested()
            onMenuRequested: (x, y) => root.optionsRequested(x, y)
        }
    }
}
