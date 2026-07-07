import QtQuick
import com.filemanager.app 1.0

// A view-options dropdown: hidden-file visibility, sort key/direction, and
// icon size. Mirrors ItemContextMenu.qml's popup mechanics (window-level
// backdrop that swallows all input, positioned card).
Item {
    id: root

    property var fileModel
    property bool showHidden: false
    property string sortKey: "name"
    property bool sortAscending: true
    property string iconSizeLevel: "medium" // "small" | "medium" | "large"

    signal iconSizeSelected(string level)
    // See ContextMenu.qml — lets the Loader wrapping this component tear
    // the instance down once it hides.
    signal closed

    anchors.fill: parent
    visible: false
    z: 1000

    // Otherwise this would always show hardcoded defaults on open, even
    // when the real values (restored from settings.json at startup)
    // differ — e.g. "Show hidden files" reading off when it's actually on.
    Component.onCompleted: {
        if (root.fileModel) {
            root.showHidden = root.fileModel.isShowHidden()
            root.sortKey = root.fileModel.currentSortKey()
            root.sortAscending = root.fileModel.isSortAscending()
            root.iconSizeLevel = root.fileModel.iconSizeLevel
        }
    }

    readonly property var _sortOptions: [
        { key: "name", label: "Name" },
        { key: "size", label: "Size" },
        { key: "modified", label: "Modified" },
        { key: "type", label: "Type" }
    ]

    readonly property var _iconSizeLevels: ["small", "medium", "large", "extraLarge"]

    function popup(x, y) {
        menu.x = Math.min(x, root.width - menu.width)
        menu.y = Math.min(y, root.height - menu.height)
        visible = true
        root.forceActiveFocus()
    }

    function close() {
        visible = false
        root.closed()
    }

    Keys.onEscapePressed: root.close()
    Keys.onShortcutOverride: (event) => {
        event.accepted = event.key === Qt.Key_Escape
    }

    MouseArea {
        // See ItemContextMenu.qml — must accept every button and track
        // hover so nothing underneath can still be interacted with while
        // this menu is open.
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        onClicked: root.close()
        onWheel: (wheel) => { wheel.accepted = true }
    }

    Rectangle {
        id: menu
        width: 260
        height: _content.implicitHeight + 24
        radius: Shape.small
        color: Elevation.surfaceAt(2)

        Column {
            id: _content
            anchors.fill: parent
            anchors.margins: 12
            spacing: 4

            Item {
                width: parent.width
                height: 40

                Text {
                    text: "Show hidden files"
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    color: Color.scheme.surfaceText
                    font.family: Type.bodyLarge.family
                    font.pixelSize: Type.bodyLarge.size
                }

                Rectangle {
                    width: 40
                    height: 22
                    radius: Shape.full
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.showHidden ? Color.scheme.primary : Color.scheme.surfaceContainerHighest
                    border.width: root.showHidden ? 0 : 1
                    border.color: Color.scheme.outline
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Rectangle {
                        width: 16
                        height: 16
                        radius: Shape.full
                        color: Color.scheme.surface
                        anchors.verticalCenter: parent.verticalCenter
                        x: root.showHidden ? parent.width - width - 3 : 3
                        Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.showHidden = !root.showHidden
                        if (root.fileModel) {
                            root.fileModel.setShowHidden(root.showHidden)
                            root.fileModel.saveSettings()
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Color.scheme.outlineVariant
            }

            Text {
                text: "Sort by"
                topPadding: 8
                bottomPadding: 4
                color: Color.scheme.surfaceVariantText
                font.family: Type.labelMedium.family
                font.weight: Type.labelMedium.weight
                font.pixelSize: Type.labelMedium.size
            }

            Repeater {
                model: root._sortOptions

                delegate: Item {
                    id: sortRow
                    required property var modelData
                    readonly property bool active: root.sortKey === modelData.key
                    width: parent.width
                    height: 36

                    Rectangle {
                        anchors.fill: parent
                        radius: Shape.small
                        color: Elevation.surfaceAt(1)
                        opacity: _sortArea.containsMouse ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        Icon {
                            content: sortRow.active ? "radio_button_checked" : "radio_button_unchecked"
                            iconSize: 18
                            color: sortRow.active ? Color.scheme.primary : Color.scheme.surfaceVariantText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: sortRow.modelData.label
                            color: sortRow.active ? Color.scheme.surfaceText : Color.scheme.surfaceVariantText
                            font.family: Type.bodyLarge.family
                            font.pixelSize: Type.bodyLarge.size
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: _sortArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.sortKey = sortRow.modelData.key
                            if (root.fileModel) {
                                root.fileModel.setSortKey(root.sortKey)
                                root.fileModel.saveSettings()
                            }
                        }
                    }
                }
            }

            ButtonGroup {
                width: parent.width
                fillWidth: true
                height: 32
                iconSize: 16
                textSize: 12
                model: [
                    { value: true, icon: "arrow_upward", label: "Ascending" },
                    { value: false, icon: "arrow_downward", label: "Descending" }
                ]
                activeCheck: (value) => value === root.sortAscending
                onSegmentClicked: (value) => {
                    root.sortAscending = value
                    if (root.fileModel) {
                        root.fileModel.setSortAscending(value)
                        root.fileModel.saveSettings()
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Color.scheme.outlineVariant
            }

            Text {
                text: "Icon size"
                topPadding: 8
                bottomPadding: 4
                color: Color.scheme.surfaceVariantText
                font.family: Type.labelMedium.family
                font.weight: Type.labelMedium.weight
                font.pixelSize: Type.labelMedium.size
            }

            M3Slider {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 16
                stepCount: root._iconSizeLevels.length
                stepLabels: ["Small", "Medium", "Large", "XL"]
                currentStep: Math.max(0, root._iconSizeLevels.indexOf(root.iconSizeLevel))
                onStepChanged: (step) => {
                    var level = root._iconSizeLevels[step]
                    root.iconSizeLevel = level
                    root.iconSizeSelected(level)
                }
            }
        }
    }
}
