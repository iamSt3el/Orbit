import QtQuick
import QtQuick.Layouts
import com.filemanager.app 1.0

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
    signal backClicked
    signal listViewRequested
    signal gridViewRequested
    signal optionsRequested(real x, real y)

    height: 56

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 16
        spacing: 8

        // Back button — the icon itself is a sibling of the hover-highlight
        // circle, not its child, so it stays visible when the highlight's
        // opacity is 0 (an icon nested inside an opacity-animated parent
        // fades with it, which made the button invisible until hovered).
        Item {
            id: backButton
            Layout.preferredWidth: 48
            Layout.preferredHeight: 48
            visible: root.showBackButton

            Rectangle {
                anchors.fill: parent
                radius: Shape.full
                color: Elevation.surfaceAt(3)
                opacity: _backArea.containsMouse ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            }

            Icon {
                anchors.centerIn: parent
                content: "arrow_back"
                iconSize: 22
                color: Color.scheme.surfaceText
            }

            MouseArea {
                id: _backArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.backClicked()
            }

            Tooltip {
                text: "Back"
                hovered: root.showBackButton && _backArea.containsMouse
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
            Layout.preferredWidth: pathBar.searching
                ? Math.max(220, Math.min(480, root.width * 0.34))
                : Math.max(320, Math.min(900, root.width * 0.68))
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
            visible: root.fileModel && root.fileModel.isBusy
            running: visible
            color: Color.scheme.primary
        }

        // View options (hidden files / sort / icon size) — same hover-circle
        // pattern as the other icon buttons.
        Item {
            id: optionsButton
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40

            Rectangle {
                anchors.fill: parent
                radius: Shape.full
                color: Elevation.surfaceAt(3)
                opacity: _optionsArea.containsMouse ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            }

            Icon {
                anchors.centerIn: parent
                content: "tune"
                iconSize: 20
                color: Color.scheme.surfaceText
            }

            MouseArea {
                id: _optionsArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    var scenePos = optionsButton.mapToItem(null, 0, optionsButton.height)
                    root.optionsRequested(scenePos.x, scenePos.y)
                }
            }

            Tooltip {
                text: "View options"
                hovered: _optionsArea.containsMouse
            }
        }

        ButtonGroup {
            id: viewToggle
            Layout.preferredHeight: 32
            iconSize: 16
            model: [
                { value: "list", icon: "view_list", tooltip: "List view" },
                { value: "grid", icon: "grid_view", tooltip: "Grid view" }
            ]
            activeCheck: (value) => value === root.viewMode
            onSegmentClicked: (value) => {
                if (value === "list") root.listViewRequested()
                else root.gridViewRequested()
            }
        }
    }
}
