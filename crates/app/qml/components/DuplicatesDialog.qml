import QtQuick
import "../util/format.js" as Format
import com.filemanager.app 1.0

Item {
    id: root

    property var fileModel
    property real centerOffsetX: 0

    signal closed

    anchors.fill: parent
    visible: false
    z: 2000

    property var groups: []

    function open() {
        visible = true
        _transition.enter()
        root.forceActiveFocus()
        root.fileModel.startDuplicateScan()
    }

    function close() {
        if (root.fileModel) {
            root.fileModel.cancelDuplicateScan()
        }
        _transition.exit()
    }

    function _rebuild() {
        if (!root.fileModel || root.fileModel.duplicatesText.length === 0) {
            root.groups = []
            return
        }
        var lines = root.fileModel.duplicatesText.split("\n")
        var out = []
        for (var i = 0; i < lines.length; i++) {
            var parts = lines[i].split("\u001f")
            if (parts.length < 3) {
                continue
            }
            out.push({ size: Number(parts[0]), paths: parts.slice(1) })
        }
        root.groups = out
    }

    function trashOthers(groupIndex) {
        var group = root.groups[groupIndex]
        root.fileModel.trashEntries(group.paths.slice(1).join("\n"))
        var next = root.groups.slice()
        next.splice(groupIndex, 1)
        root.groups = next
    }

    function trashAllDuplicates() {
        var doomed = []
        for (var i = 0; i < root.groups.length; i++) {
            doomed = doomed.concat(root.groups[i].paths.slice(1))
        }
        if (doomed.length > 0) {
            root.fileModel.trashEntries(doomed.join("\n"))
        }
        root.groups = []
    }

    readonly property real wastedBytes: {
        var total = 0
        for (var i = 0; i < groups.length; i++) {
            total += groups[i].size * (groups[i].paths.length - 1)
        }
        return total
    }

    Connections {
        target: root.fileModel ? root.fileModel : null
        function onDuplicatesTextChanged() { root._rebuild() }
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

    Keys.onEscapePressed: root.close()
    Keys.onShortcutOverride: (event) => {
        event.accepted = event.key === Qt.Key_Escape
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
        width: Math.min(620, root.width - 200)
        height: Math.min(root.height - 120, _header.height + 32 + Math.max(120, _list.contentHeight + 20))
        radius: Shape.extraLarge
        color: Elevation.surfaceAt(3)
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: root.centerOffsetX

        Accessible.role: Accessible.Dialog
        Accessible.name: "Duplicate files"

        Column {
            id: _header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 20
            spacing: 6

            Item {
                width: parent.width
                height: 28

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Duplicate files"
                    color: Color.scheme.surfaceText
                    font.family: Type.titleMedium.family
                    font.weight: Type.titleMedium.weight
                    font.pixelSize: Type.titleMedium.size
                }

                ShapeLoader {
                    width: 20
                    height: 20
                    size: 20
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.fileModel ? root.fileModel.duplicateScanRunning : false
                    running: visible
                    color: Color.scheme.primary
                }
            }

            Text {
                width: parent.width
                text: {
                    if (root.fileModel && root.fileModel.duplicateScanRunning) {
                        return "Scanning for identical files…"
                    }
                    if (root.groups.length === 0) {
                        return "No duplicates found."
                    }
                    return root.groups.length + " groups · "
                        + Format.formatBytes(root.wastedBytes) + " wasted"
                }
                color: Color.scheme.surfaceVariantText
                font.family: Type.bodyMedium.family
                font.pixelSize: Type.bodyMedium.size
            }
        }

        ListView {
            id: _list
            anchors.top: _header.bottom
            anchors.topMargin: 10
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: _footer.top
            anchors.leftMargin: 20
            anchors.rightMargin: 12
            anchors.bottomMargin: 8
            clip: true
            spacing: 10
            model: root.groups

            delegate: Rectangle {
                id: groupCard
                required property var modelData
                required property int index
                width: _list.width - 12
                height: _groupColumn.implicitHeight + 20
                radius: Shape.medium
                color: Elevation.surfaceAt(1)

                Column {
                    id: _groupColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 10
                    spacing: 4

                    Item {
                        width: parent.width
                        height: 26

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: groupCard.modelData.paths.length + " × "
                                + Format.formatBytes(groupCard.modelData.size)
                            color: Color.scheme.surfaceText
                            font.family: Type.labelLarge.family
                            font.weight: Type.labelLarge.weight
                            font.pixelSize: Type.labelLarge.size
                        }

                        Button {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            variant: "text"
                            destructive: true
                            text: "Trash others"
                            onClicked: root.trashOthers(groupCard.index)
                        }
                    }

                    Repeater {
                        model: groupCard.modelData.paths

                        delegate: Text {
                            required property string modelData
                            required property int index
                            width: _groupColumn.width
                            elide: Text.ElideMiddle
                            text: (index === 0 ? "✓ " : "   ") + modelData
                                + (index === 0 ? "  (kept, newest)" : "")
                            color: index === 0
                                ? Color.scheme.surfaceText
                                : Color.scheme.surfaceVariantText
                            font.family: Type.bodyMedium.family
                            font.pixelSize: Type.bodyMedium.size
                        }
                    }
                }
            }

            ScrollBar {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                flickable: _list
            }
        }

        Item {
            id: _footer
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 12
            height: 40

            Button {
                anchors.right: _trashAllButton.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                variant: "text"
                text: "Close"
                onClicked: root.close()
            }

            Button {
                id: _trashAllButton
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                variant: "filled"
                destructive: true
                text: "Trash all duplicates"
                enabled: root.groups.length > 0
                opacity: enabled ? 1 : 0.4
                onClicked: root.trashAllDuplicates()
            }
        }
    }
}
