import QtQuick
import com.filemanager.app 1.0

// Sizing/coloring/animation deliberately mirrors the nav rows in the
// user's quickshell "Nebula" settings app (SettingsContent.qml): 38px row
// height, 18px icon, 8px icon-label spacing, a filled `primary` pill (not
// a lighter tonal tint) on the active row, and a slight scale bounce.
// Inactive rows show no hover feedback at all — only selection state.
Rectangle {
    id: root

    property var fileModel
    property string currentPath: ""
    signal settingsRequested

    width: 200
    radius: Shape.largeIncreased
    color: Color.scheme.surfaceContainerHigh

    readonly property var _shortcuts: [
        { label: "Home", icon: "home", path: fileModel ? fileModel.homePath : "" },
        { label: "Downloads", icon: "download", path: fileModel ? fileModel.downloadsPath : "" },
        { label: "Documents", icon: "description", path: fileModel ? fileModel.documentsPath : "" },
        { label: "Trash", icon: "delete", path: fileModel ? fileModel.trashPath : "" }
    ]

    Column {
        // Anchored to the top (not anchors.fill) so it doesn't contest
        // space with TransferStatus, which is independently pinned to the
        // bottom below — the shortcuts list is short and fixed, so the
        // leftover space between them is just empty, not a layout fight.
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 10
        spacing: 0

        // App title + settings entry point — the sidebar's equivalent of
        // Nebula's "Nebula / v0.2.0-beta" header.
        Item {
            width: parent.width
            height: 44

            Text {
                text: "Files"
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                color: Color.scheme.surfaceText
                font.family: Type.titleLarge.family
                font.weight: Font.Bold
                font.pixelSize: Type.titleLarge.size
            }

            Item {
                id: settingsButton
                width: 32
                height: 32
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    anchors.fill: parent
                    radius: Shape.full
                    color: Elevation.surfaceAt(3)
                    opacity: _settingsArea.containsMouse ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                }

                Icon {
                    anchors.centerIn: parent
                    content: "settings"
                    iconSize: 18
                    color: Color.scheme.surfaceVariantText
                }

                MouseArea {
                    id: _settingsArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.settingsRequested()
                }

                Tooltip {
                    text: "Settings"
                    hovered: _settingsArea.containsMouse
                }
            }
        }

        Text {
            text: "Places"
            leftPadding: 10
            topPadding: 8
            bottomPadding: 10
            // surfaceVariantText (on-surface-variant), not outline — outline
            // is for borders/boundaries per the M3 spec, not text.
            color: Color.scheme.surfaceVariantText
            font.family: Type.labelMedium.family
            font.weight: Type.labelMedium.weight
            font.pixelSize: Type.labelMedium.size
        }

        Repeater {
            model: root._shortcuts

            delegate: Item {
                id: navItem
                required property var modelData

                readonly property bool isActive: modelData.path.length > 0 && modelData.path === root.currentPath
                // Only the active (selected) row is highlighted — no hover
                // feedback on the others.
                readonly property bool highlighted: isActive

                width: parent.width
                implicitHeight: 38

                Rectangle {
                    anchors.fill: parent
                    radius: Shape.medium
                    color: navItem.highlighted ? Color.scheme.primary : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    scale: navItem.highlighted ? 1 : 0.96
                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Icon {
                            content: navItem.modelData.icon
                            iconSize: 18
                            color: navItem.highlighted ? Color.scheme.primaryText : Color.scheme.surfaceVariantText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: navItem.modelData.label
                            color: navItem.highlighted ? Color.scheme.primaryText : Color.scheme.surfaceVariantText
                            font.family: Type.bodyLarge.family
                            font.weight: navItem.isActive ? Font.Bold : Font.Medium
                            font.pixelSize: Type.bodyLarge.size
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: _area
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (navItem.modelData.path.length > 0 && root.fileModel) {
                                root.fileModel.navigate(navItem.modelData.path)
                            }
                        }
                    }
                }
            }
        }
    }

    TransferStatus {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 10
        active: root.fileModel ? root.fileModel.isBusy : false
        label: root.fileModel ? root.fileModel.busyLabel : ""
        doneBytes: root.fileModel ? root.fileModel.transferDoneBytes : 0
        totalBytes: root.fileModel ? root.fileModel.transferTotalBytes : 0
        speedLabel: root.fileModel ? root.fileModel.transferSpeedLabel : ""
    }
}
