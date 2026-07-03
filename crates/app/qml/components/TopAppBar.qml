import QtQuick
import QtQuick.Layouts
import com.filemanager.app 1.0

// The content pane's own header row — back button, current path/search,
// view options, theme toggle, and the list/grid switch. Deliberately not a
// separate floating/colored bar: it lives directly on the unified card's
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
        }

        PathBar {
            id: pathBar
            Layout.preferredHeight: 40
            // Fixed-width pill in both states, never stretched to fill the
            // header — matches the compact reference design rather than a
            // full-width bar. Search is half the width of the plain path
            // display.
            Layout.preferredWidth: pathBar.searching ? 130 : 260
            path: root.title
            fileModel: root.fileModel
        }

        Item {
            // Absorbs whatever space PathBar doesn't use, so the trailing
            // controls stay pinned to the right instead of hugging the path.
            Layout.fillWidth: true
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
        }

        // Dark/light theme toggle.
        Item {
            id: themeToggle
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40

            Rectangle {
                anchors.fill: parent
                radius: Shape.full
                color: Elevation.surfaceAt(3)
                opacity: _themeArea.containsMouse ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            }

            Icon {
                anchors.centerIn: parent
                content: Color.darkMode ? "light_mode" : "dark_mode"
                iconSize: 20
                color: Color.scheme.surfaceText
            }

            MouseArea {
                id: _themeArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Color.darkMode = !Color.darkMode
            }
        }

        ButtonGroup {
            id: viewToggle
            Layout.preferredHeight: 32
            iconSize: 16
            model: [
                { value: "list", icon: "view_list" },
                { value: "grid", icon: "grid_view" }
            ]
            activeCheck: (value) => value === root.viewMode
            onSegmentClicked: (value) => {
                if (value === "list") root.listViewRequested()
                else root.gridViewRequested()
            }
        }
    }
}
