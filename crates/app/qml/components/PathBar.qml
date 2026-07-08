import QtQuick
import com.orbit.app 1.0

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
    property bool editing: false

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

    function startEditing() {
        root.closeSearch()
        root.editing = true
        pathInput.text = root.path
        pathInput.forceActiveFocus()
        pathInput.selectAll()
    }

    onSearchingChanged: {
        if (root.searching) {
            root.editing = false
            searchInput.forceActiveFocus()
        }
    }

    // A new folder was navigated to — any active search no longer applies.
    onPathChanged: {
        closeSearch()
        root.editing = false
    }

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
            content: (root.searching || root.editing) ? "arrow_back" : "search"
            iconSize: 18
            color: Color.scheme.surfaceVariantText
        }

        MouseArea {
            id: _leadingArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (root.editing) {
                    root.editing = false
                } else if (root.searching) {
                    root.closeSearch()
                } else {
                    root.searching = true
                }
            }
        }

        Tooltip {
            text: (root.searching || root.editing) ? "Back" : "Search"
            hovered: _leadingArea.containsMouse
        }
    }

    // Clickable breadcrumbs (roadmap item 13): every ancestor is a chip
    // that navigates on click; the last (current) segment is emphasized
    // and inert. Replaces the old elided plain-text path.
    Item {
        id: crumbs
        opacity: (root.searching || root.editing) ? 0 : 1
        visible: opacity > 0
        anchors.left: leadingIcon.right
        anchors.leftMargin: 8
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        clip: true

        Behavior on opacity { NumberAnimation { duration: Motion.standard.duration; easing.type: Easing.OutCubic } }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.IBeamCursor
            onClicked: root.startEditing()
        }

        readonly property var segments: {
            var p = root.path
            if (p.length === 0) {
                return []
            }
            var segs = [{ label: "/", target: "/" }]
            if (p === "/") {
                return segs
            }
            var parts = p.split("/").filter((s) => s.length > 0)
            var acc = ""
            for (var i = 0; i < parts.length; i++) {
                acc += "/" + parts[i]
                segs.push({ label: parts[i], target: acc })
            }
            return segs
        }

        Row {
            id: crumbRow
            spacing: 0
            anchors.verticalCenter: parent.verticalCenter
            // Deep paths overflow to the LEFT: the deepest segments (the
            // ones worth clicking) stay visible at the right edge.
            x: Math.min(0, crumbs.width - crumbRow.width)

            Repeater {
                model: crumbs.segments

                delegate: Row {
                    id: crumb
                    required property var modelData
                    required property int index
                    readonly property bool isLast: index === crumbs.segments.length - 1
                    spacing: 0

                    Icon {
                        visible: crumb.index > 0
                        content: "chevron_right"
                        iconSize: 14
                        color: Color.scheme.surfaceVariantText
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Item {
                        width: _crumbText.implicitWidth + 12
                        height: 26
                        anchors.verticalCenter: parent.verticalCenter

                        // Highlight is a sibling of the text, not its
                        // parent — see TopAppBar's back button for why.
                        Rectangle {
                            anchors.fill: parent
                            radius: Shape.small
                            color: Elevation.surfaceAt(3)
                            opacity: (_crumbArea.containsMouse && !crumb.isLast) ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        }

                        Text {
                            id: _crumbText
                            anchors.centerIn: parent
                            text: crumb.modelData.label
                            color: crumb.isLast ? Color.scheme.surfaceText : Color.scheme.surfaceVariantText
                            font.family: Type.bodyLarge.family
                            font.pixelSize: Type.bodyLarge.size
                            font.weight: crumb.isLast ? Font.Medium : Font.Normal
                        }

                        MouseArea {
                            id: _crumbArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: crumb.isLast ? Qt.ArrowCursor : Qt.PointingHandCursor
                            onClicked: {
                                if (!crumb.isLast && root.fileModel) {
                                    root.fileModel.navigate(crumb.modelData.target)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    TextInput {
        id: pathInput
        enabled: root.editing
        opacity: root.editing ? 1 : 0
        visible: opacity > 0
        anchors.left: leadingIcon.right
        anchors.leftMargin: 8
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        clip: true
        color: Color.scheme.surfaceText
        selectionColor: Color.scheme.primary
        selectedTextColor: Color.scheme.primaryText
        font.family: Type.bodyLarge.family
        font.pixelSize: Type.bodyLarge.size

        Behavior on opacity { NumberAnimation { duration: Motion.standard.duration; easing.type: Easing.OutCubic } }

        onAccepted: {
            if (root.fileModel && root.fileModel.navigateToInput(pathInput.text)) {
                root.editing = false
            }
        }
        onActiveFocusChanged: if (!activeFocus) root.editing = false
        Keys.onEscapePressed: root.editing = false
        Keys.onShortcutOverride: (event) => {
            event.accepted = event.key === Qt.Key_Return
                || event.key === Qt.Key_Enter
                || event.key === Qt.Key_Escape
        }
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Tab && root.fileModel) {
                pathInput.text = root.fileModel.completePath(pathInput.text)
                pathInput.cursorPosition = pathInput.text.length
                event.accepted = true
            }
        }
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

        // Debounced (round-2 item 25): every query now spawns a recursive
        // walk of the current directory, which per-keystroke would be
        // wasteful on big trees. closeSearch() still clears immediately.
        onTextChanged: _searchDebounce.restart()
        Keys.onEscapePressed: root.closeSearch()
        Keys.onShortcutOverride: (event) => {
            event.accepted = event.key === Qt.Key_Escape
        }

        Timer {
            id: _searchDebounce
            interval: 200
            onTriggered: if (root.fileModel) root.fileModel.setSearchQuery(searchInput.text)
        }

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
