import QtQuick
import com.filemanager.app 1.0

// A rounded pill bar showing the current path, doubling as an M3 search
// bar — tap the leading icon to switch it into a live filter over the
// current folder's contents (fileModel.setSearchQuery). Per the M3 spec,
// search bars are always a fully-rounded ("stadium") shape — Shape.full,
// never Shape.small (that's reserved for outlined text fields) — and use
// a flat surface-container-high fill rather than an outline: a border
// signals a text field, not a search bar. The leading icon swaps between
// the search glyph and a back arrow, mirroring the spec's
// docked-search-bar -> search-view icon behavior, and a trailing clear
// icon appears only once there's a query to clear.
Rectangle {
    id: root

    property string path: ""
    property var fileModel

    property bool searching: false

    implicitHeight: 40
    radius: Shape.full
    color: Color.scheme.surfaceContainerHigh

    function closeSearch() {
        root.searching = false
        searchInput.text = ""
        if (root.fileModel) {
            root.fileModel.setSearchQuery("")
        }
    }

    onSearchingChanged: if (root.searching) searchInput.forceActiveFocus()

    // A new folder was navigated to — any active search no longer applies.
    onPathChanged: closeSearch()

    Item {
        id: leadingIcon
        width: 32
        height: 32
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
            anchors.fill: parent
            radius: Shape.full
            color: Elevation.surfaceAt(3)
            opacity: _leadingArea.containsMouse ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }

        Icon {
            anchors.centerIn: parent
            content: root.searching ? "arrow_back" : "search"
            iconSize: 18
            color: Color.scheme.surfaceVariantText
        }

        MouseArea {
            id: _leadingArea
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
            text: root.searching ? "Back" : "Search"
            hovered: _leadingArea.containsMouse
        }
    }

    Text {
        text: root.path
        opacity: root.searching ? 0 : 1
        elide: Text.ElideMiddle
        anchors.left: leadingIcon.right
        anchors.leftMargin: 8
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        color: Color.scheme.surfaceText
        font.family: Type.bodyLarge.family
        font.pixelSize: Type.bodyLarge.size

        Behavior on opacity { NumberAnimation { duration: Motion.standard.duration; easing.type: Easing.OutCubic } }
    }

    TextInput {
        id: searchInput
        enabled: root.searching
        opacity: root.searching ? 1 : 0
        anchors.left: leadingIcon.right
        anchors.leftMargin: 8
        anchors.right: clearButton.left
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        clip: true
        color: Color.scheme.surfaceText
        font.family: Type.bodyLarge.family
        font.pixelSize: Type.bodyLarge.size

        onTextChanged: if (root.fileModel) root.fileModel.setSearchQuery(searchInput.text)
        Keys.onEscapePressed: root.closeSearch()

        Behavior on opacity { NumberAnimation { duration: Motion.standard.duration; easing.type: Easing.OutCubic } }

        Text {
            visible: searchInput.text.length === 0
            text: "Search this folder…"
            color: Color.scheme.surfaceVariantText
            font: searchInput.font
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // Trailing clear — only appears once there's a query to clear, so it
    // doesn't duplicate the leading icon's "exit search" action.
    Item {
        id: clearButton
        width: 32
        height: 32
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        visible: root.searching && searchInput.text.length > 0

        Rectangle {
            anchors.fill: parent
            radius: Shape.full
            color: Elevation.surfaceAt(3)
            opacity: _clearArea.containsMouse ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }

        Icon {
            anchors.centerIn: parent
            content: "close"
            iconSize: 16
            color: Color.scheme.surfaceVariantText
        }

        MouseArea {
            id: _clearArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: searchInput.text = ""
        }

        Tooltip {
            text: "Clear"
            hovered: _clearArea.containsMouse
        }
    }
}
