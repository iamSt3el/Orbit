import QtQuick
import com.filemanager.app 1.0

Item {
    id: root

    property var fileModel
    property real centerOffsetX: 0

    signal actionRequested(string actionId)
    signal closed

    anchors.fill: parent
    visible: false
    z: 3000

    property int cursor: 0

    function open() {
        visible = true
        input.text = ""
        root.cursor = 0
        _transition.enter()
        input.forceActiveFocus()
    }

    function close() {
        _transition.exit()
    }

    ModalTransition {
        id: _transition
        card: card
        scrim: _scrim
        onExited: {
            root.visible = false
            root.closed()
        }
    }

    readonly property var _actions: [
        { icon: "create_new_folder", label: "New folder", hint: "", id: "newFolder" },
        { icon: "note_add", label: "New file", hint: "", id: "newFile" },
        { icon: "tab", label: "New tab", hint: "Ctrl+T", id: "newTab" },
        { icon: "preview", label: "Toggle preview pane", hint: "F9", id: "togglePreview" },
        { icon: "terminal", label: "Open terminal here", hint: "", id: "terminal" },
        { icon: "settings", label: "Settings", hint: "", id: "settings" },
        { icon: "edit_note", label: "Edit path", hint: "Ctrl+L", id: "editPath" },
        { icon: "grid_view", label: "Toggle list / grid view", hint: "", id: "toggleView" },
        { icon: "visibility", label: "Toggle hidden files", hint: "", id: "toggleHidden" },
        { icon: "content_paste", label: "Paste here", hint: "Ctrl+V", id: "paste" },
        { icon: "select_all", label: "Select all", hint: "Ctrl+A", id: "selectAll" },
        { icon: "undo", label: "Undo", hint: "Ctrl+Z", id: "undo" },
        { icon: "redo", label: "Redo", hint: "Ctrl+Shift+Z", id: "redo" },
        { icon: "monitoring", label: "Disk usage of this folder", hint: "", id: "diskUsage" }
    ]

    readonly property var _destinations: {
        if (!root.fileModel) {
            return []
        }
        var out = [
            { icon: "home", label: "Go to Home", path: root.fileModel.homePath },
            { icon: "download", label: "Go to Downloads", path: root.fileModel.downloadsPath },
            { icon: "description", label: "Go to Documents", path: root.fileModel.documentsPath },
            { icon: "delete", label: "Go to Trash", path: root.fileModel.trashPath }
        ]
        var pins = root.fileModel.pinnedFoldersJoined.split("\n")
        for (var i = 0; i < pins.length; i++) {
            if (pins[i].length > 0) {
                out.push({
                    icon: "keep",
                    label: "Go to " + pins[i].substring(pins[i].lastIndexOf("/") + 1),
                    path: pins[i]
                })
            }
        }
        return out
    }

    readonly property var filtered: {
        var q = input.text.trim()
        var out = []
        if (q.startsWith("/") || q.startsWith("~")) {
            out.push({ icon: "arrow_forward", label: "Go to " + q, goInput: q })
        }
        var all = root._actions.concat(root._destinations)
        var ql = q.toLowerCase()
        var scored = []
        for (var i = 0; i < all.length; i++) {
            if (ql.length === 0) {
                scored.push({ c: all[i], s: i })
            } else {
                var idx = all[i].label.toLowerCase().indexOf(ql)
                if (idx >= 0) {
                    scored.push({ c: all[i], s: idx * 100 + i })
                }
            }
        }
        scored.sort((a, b) => a.s - b.s)
        return out.concat(scored.map((e) => e.c)).slice(0, 10)
    }

    onFilteredChanged: root.cursor = Math.max(0, Math.min(root.cursor, root.filtered.length - 1))

    function runCurrent() {
        if (root.filtered.length === 0) {
            return
        }
        var cmd = root.filtered[root.cursor]
        if (cmd.goInput !== undefined) {
            root.fileModel.navigateToInput(cmd.goInput)
        } else if (cmd.path !== undefined) {
            root.fileModel.navigate(cmd.path)
        } else {
            root.actionRequested(cmd.id)
        }
        root.close()
    }

    Rectangle {
        id: _scrim
        anchors.fill: parent
        color: Color.scheme.surface
        opacity: 0.4

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.AllButtons
            onClicked: root.close()
            onWheel: (wheel) => { wheel.accepted = true }
        }
    }

    Rectangle {
        id: card
        width: Math.min(560, root.width - 80)
        height: _column.implicitHeight + 16
        radius: Shape.extraLarge
        color: Elevation.surfaceAt(3)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: root.centerOffsetX
        y: 90

        Accessible.role: Accessible.Dialog
        Accessible.name: "Command palette"

        Column {
            id: _column
            width: parent.width - 16
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 8
            spacing: 4

            Item {
                width: parent.width
                height: 48

                Icon {
                    id: _searchIcon
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    content: "search"
                    iconSize: 20
                    color: Color.scheme.surfaceVariantText
                }

                TextInput {
                    id: input
                    anchors.left: _searchIcon.right
                    anchors.leftMargin: 12
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    clip: true
                    color: Color.scheme.surfaceText
                    font.family: Type.bodyLarge.family
                    font.pixelSize: Type.bodyLarge.size

                    Keys.onShortcutOverride: (event) => {
                        event.accepted = event.key === Qt.Key_Return
                            || event.key === Qt.Key_Enter
                            || event.key === Qt.Key_Escape
                    }
                    Keys.onEscapePressed: root.close()
                    Keys.onReturnPressed: root.runCurrent()
                    Keys.onEnterPressed: root.runCurrent()
                    Keys.onDownPressed: root.cursor = Math.min(root.filtered.length - 1, root.cursor + 1)
                    Keys.onUpPressed: root.cursor = Math.max(0, root.cursor - 1)
                    onTextChanged: root.cursor = 0

                    Text {
                        visible: input.text.length === 0
                        text: "Type a command, folder, or path…"
                        color: Color.scheme.surfaceVariantText
                        font: input.font
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Color.scheme.outlineVariant
                visible: root.filtered.length > 0
            }

            Repeater {
                model: root.filtered

                delegate: Rectangle {
                    id: resultRow
                    required property var modelData
                    required property int index
                    readonly property bool active: index === root.cursor
                    width: _column.width
                    height: 44
                    radius: Shape.medium
                    color: active ? Color.scheme.secondaryContainer
                        : (_rowArea.containsMouse ? Elevation.surfaceAt(1) : "transparent")

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.right: _hintText.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12

                        Icon {
                            content: resultRow.modelData.icon
                            iconSize: 20
                            color: resultRow.active
                                ? Color.scheme.secondaryContainerText
                                : Color.scheme.surfaceVariantText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: resultRow.modelData.label
                            elide: Text.ElideMiddle
                            width: Math.min(implicitWidth, _column.width - 140)
                            color: resultRow.active
                                ? Color.scheme.secondaryContainerText
                                : Color.scheme.surfaceText
                            font.family: Type.bodyLarge.family
                            font.pixelSize: Type.bodyLarge.size
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Text {
                        id: _hintText
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: resultRow.modelData.hint !== undefined ? resultRow.modelData.hint : ""
                        color: Color.scheme.surfaceVariantText
                        font.family: Type.labelMedium.family
                        font.pixelSize: Type.labelMedium.size
                    }

                    MouseArea {
                        id: _rowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.cursor = resultRow.index
                            root.runCurrent()
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: 8
            }
        }
    }
}
