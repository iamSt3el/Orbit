import QtQuick
import com.filemanager.app 1.0

// A rounded pill bar showing the current path, doubling as a search box —
// click the icon on the right to switch it into a live filter over the
// current folder's contents (fileModel.setSearchQuery), with an X to
// clear back to the plain path view. Styling loosely follows a reference
// screenshot the user provided of a path/browse field.
Rectangle {
    id: root

    property string path: ""
    property var fileModel

    property bool searching: false

    implicitHeight: 40
    radius: Shape.small
    color: Color.scheme.surfaceContainerHighest
    border.width: 1
    border.color: Color.scheme.outlineVariant

    function closeSearch() {
        root.searching = false
        searchInput.text = ""
        if (root.fileModel) {
            root.fileModel.setSearchQuery("")
        }
    }

    // A new folder was navigated to — any active search no longer applies.
    onPathChanged: closeSearch()

    Text {
        visible: !root.searching
        text: root.path
        elide: Text.ElideMiddle
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.right: iconButton.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        color: Color.scheme.surfaceText
        font.family: Type.bodyLarge.family
        font.pixelSize: Type.bodyLarge.size
    }

    TextInput {
        id: searchInput
        visible: root.searching
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.right: iconButton.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        clip: true
        color: Color.scheme.surfaceText
        font.family: Type.bodyLarge.family
        font.pixelSize: Type.bodyLarge.size

        onVisibleChanged: if (visible) searchInput.forceActiveFocus()
        onTextChanged: if (root.fileModel) root.fileModel.setSearchQuery(searchInput.text)
        Keys.onEscapePressed: root.closeSearch()

        Text {
            visible: searchInput.text.length === 0
            text: "Search this folder…"
            color: Color.scheme.surfaceVariantText
            font: searchInput.font
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Item {
        id: iconButton
        width: 32
        height: 32
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
            anchors.fill: parent
            radius: Shape.full
            color: Elevation.surfaceAt(3)
            opacity: _iconArea.containsMouse ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }

        Icon {
            anchors.centerIn: parent
            content: root.searching ? "close" : "search"
            iconSize: 18
            color: Color.scheme.surfaceVariantText
        }

        MouseArea {
            id: _iconArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (root.searching) {
                    root.closeSearch()
                } else {
                    root.searching = true
                }
            }
        }

        Tooltip {
            text: root.searching ? "Clear search" : "Search"
            hovered: _iconArea.containsMouse
        }
    }
}
