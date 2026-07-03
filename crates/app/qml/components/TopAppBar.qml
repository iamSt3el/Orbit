import QtQuick
import com.filemanager.app 1.0

Rectangle {
    id: root

    property string title: ""
    property bool showBackButton: false
    property string viewMode: "list" // "list" | "grid"
    signal backClicked
    signal listViewRequested
    signal gridViewRequested

    height: 64
    radius: 20
    color: Color.scheme.surfaceContainerHigh

    // Back button — the icon itself is a sibling of the hover-highlight
    // circle, not its child, so it stays visible when the highlight's
    // opacity is 0 (an icon nested inside an opacity-animated parent
    // fades with it, which made the button invisible until hovered).
    Item {
        id: backButton
        width: 48
        height: 48
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
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

    Text {
        anchors.left: backButton.visible ? backButton.right : parent.left
        anchors.leftMargin: backButton.visible ? 12 : 24
        anchors.right: themeToggle.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: root.title
        color: Color.scheme.surfaceText
        font.family: Type.titleLargeEmphasized.family
        font.weight: Type.titleLargeEmphasized.weight
        font.pixelSize: Type.titleLargeEmphasized.size
        elide: Text.ElideMiddle
    }

    // Dark/light theme toggle — same hover-circle pattern as the back
    // button (icon is a sibling of the opacity-animated highlight, not a
    // child, so it doesn't fade with it).
    Item {
        id: themeToggle
        width: 48
        height: 48
        anchors.right: viewToggle.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter

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
            iconSize: 22
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
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        iconSize: 18
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
