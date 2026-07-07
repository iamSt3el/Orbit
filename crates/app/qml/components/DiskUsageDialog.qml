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

    property var pathStack: []
    readonly property string currentPath: pathStack.length > 0 ? pathStack[pathStack.length - 1] : ""
    property var tiles: []

    function open(path) {
        root.pathStack = [path]
        visible = true
        _transition.enter()
        root.forceActiveFocus()
        root.fileModel.startUsageScan(path)
    }

    function close() {
        if (root.fileModel) {
            root.fileModel.cancelUsageScan()
        }
        _transition.exit()
    }

    function drillInto(name) {
        var stack = root.pathStack.slice()
        stack.push(root.currentPath + "/" + name)
        root.pathStack = stack
        root.fileModel.startUsageScan(root.currentPath)
    }

    function goUp() {
        if (root.pathStack.length <= 1) {
            return
        }
        var stack = root.pathStack.slice()
        stack.pop()
        root.pathStack = stack
        root.fileModel.startUsageScan(root.currentPath)
    }

    function _splitLayout(items, x, y, w, h, out) {
        if (items.length === 0) {
            return
        }
        if (items.length === 1) {
            out.push({ item: items[0], x: x, y: y, w: w, h: h })
            return
        }
        var total = 0
        for (var i = 0; i < items.length; i++) {
            total += items[i].bytes
        }
        var half = 0
        var split = 1
        for (i = 0; i < items.length - 1; i++) {
            half += items[i].bytes
            split = i + 1
            if (half >= total / 2) {
                break
            }
        }
        var first = items.slice(0, split)
        var second = items.slice(split)
        var frac = total > 0 ? half / total : 0.5
        frac = Math.max(0.05, Math.min(0.95, frac))
        if (w >= h) {
            _splitLayout(first, x, y, w * frac, h, out)
            _splitLayout(second, x + w * frac, y, w * (1 - frac), h, out)
        } else {
            _splitLayout(first, x, y, w, h * frac, out)
            _splitLayout(second, x, y + h * frac, w, h * (1 - frac), out)
        }
    }

    function _rebuild() {
        if (!root.fileModel || mapArea.width <= 0) {
            root.tiles = []
            return
        }
        var text = root.fileModel.usageText
        if (text.length === 0) {
            root.tiles = []
            return
        }
        var lines = text.split("\n")
        var items = []
        var otherBytes = 0
        for (var i = 0; i < lines.length; i++) {
            var parts = lines[i].split("\u001f")
            if (parts.length !== 3) {
                continue
            }
            var bytes = Number(parts[1])
            if (items.length >= 40) {
                otherBytes += bytes
                continue
            }
            items.push({ name: parts[0], bytes: Math.max(1, bytes), isDir: parts[2] === "1" })
        }
        if (otherBytes > 0) {
            items.push({ name: "(other)", bytes: Math.max(1, otherBytes), isDir: false })
        }
        var out = []
        _splitLayout(items, 0, 0, mapArea.width, mapArea.height, out)
        root.tiles = out
    }

    Connections {
        target: root.fileModel ? root.fileModel : null
        function onUsageTextChanged() { root._rebuild() }
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
        width: root.width - 260
        height: root.height - 120
        radius: Shape.extraLarge
        color: Elevation.surfaceAt(3)
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: root.centerOffsetX

        Accessible.role: Accessible.Dialog
        Accessible.name: "Disk usage"

        Item {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 16
            height: 40

            Item {
                id: upButton
                width: 32
                height: 32
                anchors.verticalCenter: parent.verticalCenter
                visible: root.pathStack.length > 1

                Rectangle {
                    anchors.fill: parent
                    radius: Shape.full
                    color: Elevation.surfaceAt(4)
                    opacity: _upArea.containsMouse ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                }

                Icon {
                    anchors.centerIn: parent
                    content: "arrow_upward"
                    iconSize: 18
                    color: Color.scheme.surfaceText
                }

                MouseArea {
                    id: _upArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.goUp()
                }
            }

            Text {
                anchors.left: upButton.visible ? upButton.right : parent.left
                anchors.leftMargin: upButton.visible ? 10 : 0
                anchors.right: _spinner.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: root.currentPath
                elide: Text.ElideLeft
                color: Color.scheme.surfaceText
                font.family: Type.titleMedium.family
                font.weight: Type.titleMedium.weight
                font.pixelSize: Type.titleMedium.size
            }

            ShapeLoader {
                id: _spinner
                width: 20
                height: 20
                size: 20
                anchors.right: _closeButton.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                visible: root.fileModel ? root.fileModel.usageScanRunning : false
                running: visible
                color: Color.scheme.primary
            }

            Item {
                id: _closeButton
                width: 32
                height: 32
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    anchors.fill: parent
                    radius: Shape.full
                    color: Elevation.surfaceAt(4)
                    opacity: _closeArea.containsMouse ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                }

                Icon {
                    anchors.centerIn: parent
                    content: "close"
                    iconSize: 18
                    color: Color.scheme.surfaceVariantText
                }

                MouseArea {
                    id: _closeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.close()
                }
            }
        }

        Item {
            id: mapArea
            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 16
            anchors.topMargin: 8
            onWidthChanged: root._rebuild()
            onHeightChanged: root._rebuild()

            Text {
                anchors.centerIn: parent
                visible: root.tiles.length === 0
                text: (root.fileModel && root.fileModel.usageScanRunning) ? "Scanning…" : "Empty folder"
                color: Color.scheme.surfaceVariantText
                font.family: Type.bodyLarge.family
                font.pixelSize: Type.bodyLarge.size
            }

            Repeater {
                model: root.tiles

                delegate: Rectangle {
                    id: tile
                    required property var modelData
                    required property int index
                    readonly property var _fills: [
                        Color.scheme.primaryContainer,
                        Color.scheme.secondaryContainer,
                        Color.scheme.tertiaryContainer
                    ]
                    readonly property var _texts: [
                        Color.scheme.primaryContainerText,
                        Color.scheme.secondaryContainerText,
                        Color.scheme.tertiaryContainerText
                    ]
                    x: modelData.x + 2
                    y: modelData.y + 2
                    width: Math.max(1, modelData.w - 4)
                    height: Math.max(1, modelData.h - 4)
                    radius: Shape.small
                    color: _fills[index % 3]
                    opacity: _tileArea.containsMouse ? 1 : 0.82
                    clip: true

                    Column {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.margins: 8
                        visible: tile.width > 70 && tile.height > 40
                        spacing: 1

                        Text {
                            text: tile.modelData.item.name
                            width: tile.width - 16
                            elide: Text.ElideMiddle
                            color: tile._texts[tile.index % 3]
                            font.family: Type.labelLarge.family
                            font.weight: Type.labelLarge.weight
                            font.pixelSize: Type.labelLarge.size
                        }

                        Text {
                            text: Format.formatBytes(tile.modelData.item.bytes)
                            color: tile._texts[tile.index % 3]
                            opacity: 0.8
                            font.family: Type.labelMedium.family
                            font.pixelSize: Type.labelMedium.size
                        }
                    }

                    MouseArea {
                        id: _tileArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: tile.modelData.item.isDir ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (tile.modelData.item.isDir) {
                                root.drillInto(tile.modelData.item.name)
                            }
                        }
                    }

                    Tooltip {
                        text: tile.modelData.item.name + " · " + Format.formatBytes(tile.modelData.item.bytes)
                        hovered: _tileArea.containsMouse
                    }
                }
            }
        }
    }
}
