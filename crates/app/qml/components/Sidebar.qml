import QtQuick
import com.filemanager.app 1.0
import "../util/format.js" as Format

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
    signal trashContextMenuRequested(real x, real y)
    signal pinnedContextMenuRequested(real x, real y, string path)

    // Pinned folders (roadmap item 9) — drag a folder anywhere onto the
    // sidebar to pin it. The sidebar stays a non-target for file drops
    // (per the drag-and-drop spec); pinning is a different gesture, so
    // the model-side pinFolder() silently ignores anything that isn't a
    // directory.
    readonly property var pinnedFolders: fileModel && fileModel.pinnedFoldersJoined.length > 0
        ? fileModel.pinnedFoldersJoined.split("\n") : []

    // Mounted volumes (round-2 item 24) — parsed from the model's
    // volumesText, refreshed on a coarse poll (there's no mount watcher).
    readonly property var volumes: {
        if (!fileModel || fileModel.volumesText.length === 0) {
            return []
        }
        var out = []
        var lines = fileModel.volumesText.split("\n")
        for (var i = 0; i < lines.length; i++) {
            var f = lines[i].split("\u001f")
            if (f.length === 5) {
                out.push({
                    label: f[0],
                    mount: f[1],
                    total: Number(f[2]),
                    avail: Number(f[3]),
                    device: f[4]
                })
            }
        }
        return out
    }

    Timer {
        interval: 10000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: if (root.fileModel) root.fileModel.refreshVolumes()
    }

    width: 200
    radius: Shape.largeIncreased
    color: Color.scheme.surfaceContainerHigh

    readonly property var _shortcuts: [
        { label: "Home", icon: "home", path: fileModel ? fileModel.homePath : "" },
        { label: "Downloads", icon: "download", path: fileModel ? fileModel.downloadsPath : "" },
        { label: "Documents", icon: "description", path: fileModel ? fileModel.documentsPath : "" },
        { label: "Trash", icon: "delete", path: fileModel ? fileModel.trashPath : "", isTrash: true }
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
            model: root._shortcuts.concat(root.pinnedFolders.map((p) => ({
                label: p === "/" ? "/" : p.substring(p.lastIndexOf("/") + 1),
                icon: "keep",
                path: p,
                isPinned: true
            })))

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
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: (mouse) => {
                            if (mouse.button === Qt.RightButton) {
                                var scenePos = navItem.mapToItem(null, mouse.x, mouse.y)
                                if (navItem.modelData.isTrash) {
                                    root.trashContextMenuRequested(scenePos.x, scenePos.y)
                                } else if (navItem.modelData.isPinned) {
                                    root.pinnedContextMenuRequested(scenePos.x, scenePos.y, navItem.modelData.path)
                                }
                                return
                            }
                            if (navItem.modelData.path.length > 0 && root.fileModel) {
                                root.fileModel.navigate(navItem.modelData.path)
                            }
                        }
                    }
                }
            }
        }

        Text {
            visible: root.volumes.length > 0
            text: "Storage"
            leftPadding: 10
            topPadding: 14
            bottomPadding: 10
            color: Color.scheme.surfaceVariantText
            font.family: Type.labelMedium.family
            font.weight: Type.labelMedium.weight
            font.pixelSize: Type.labelMedium.size
        }

        // One full-width gauge card per mounted volume. This section IS
        // the devices list too — click navigates to the mount, hover
        // reveals eject — so there's no separate "Devices" section. In
        // flow after Places on purpose: the sidebar's bottom edge belongs
        // to TransferStatus's copy indicator.
        Column {
            visible: root.volumes.length > 0
            width: parent.width
            spacing: 8

            Repeater {
                model: root.volumes

                delegate: Rectangle {
                    id: volCard
                    required property var modelData
                    readonly property real usedBytes: modelData.total - modelData.avail
                    readonly property bool isActive: modelData.mount === root.currentPath

                    width: parent.width
                    height: 88
                    radius: Shape.large
                    color: Elevation.surfaceAt(2)
                    // Active mount reads as a border, not a primary fill —
                    // a fill would fight the gauge's own colors.
                    border.width: volCard.isActive ? 2 : 0
                    border.color: Color.scheme.primary

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12

                        GaugeProgress {
                            width: 64
                            height: 64
                            anchors.verticalCenter: parent.verticalCenter
                            progress: volCard.modelData.total > 0
                                ? volCard.usedBytes / volCard.modelData.total : 0
                            icon: volCard.modelData.mount === "/" ? "hard_drive" : "usb"
                            iconSize: 12
                        }

                        Column {
                            // Fixed width (the eject button floats over the
                            // card's corner instead of sitting in this Row)
                            // so the caption doesn't reflow on hover.
                            width: parent.width - 64 - 12
                            spacing: 3
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                width: parent.width
                                text: volCard.modelData.label
                                elide: Text.ElideRight
                                color: Color.scheme.surfaceText
                                font.family: Type.bodyLarge.family
                                font.weight: Font.Medium
                                font.pixelSize: Type.bodyLarge.size
                            }

                            Text {
                                width: parent.width
                                text: Format.formatBytesPair(volCard.usedBytes, volCard.modelData.total)
                                elide: Text.ElideRight
                                color: Color.scheme.surfaceVariantText
                                font.family: Type.labelMedium.family
                                font.pixelSize: Type.labelMedium.size
                            }
                        }
                    }

                    Item {
                        id: ejectButton
                        width: 24
                        height: 24
                        visible: volCard.modelData.mount !== "/" && _volArea.containsMouse
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 6

                        Rectangle {
                            anchors.fill: parent
                            radius: Shape.full
                            color: Elevation.surfaceAt(3)
                            opacity: _ejectArea.containsMouse ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        }

                        Icon {
                            anchors.centerIn: parent
                            content: "eject"
                            iconSize: 14
                            color: Color.scheme.surfaceVariantText
                        }

                        MouseArea {
                            id: _ejectArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.fileModel.ejectVolume(volCard.modelData.device)
                        }

                        Tooltip {
                            text: "Eject"
                            hovered: _ejectArea.containsMouse
                        }
                    }

                    MouseArea {
                        id: _volArea
                        // Below the eject button in z so eject clicks win.
                        z: -1
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.fileModel) root.fileModel.navigate(volCard.modelData.mount)
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

    // Whole-sidebar drop target for pinning. Behind the rows in z, but
    // that doesn't matter for drops: the rows have no DropAreas of their
    // own, so every text/uri-list drag over the sidebar lands here.
    DropArea {
        id: pinDropArea
        anchors.fill: parent
        keys: ["text/uri-list"]
        onDropped: (drop) => {
            if (!drop.hasUrls || !root.fileModel) {
                return
            }
            drop.acceptProposedAction()
            for (var i = 0; i < drop.urls.length; i++) {
                // decodeURIComponent: QUrl.toString() is percent-encoded —
                // see the matching comment on the file views' DropAreas.
                root.fileModel.pinFolder(decodeURIComponent(drop.urls[i].toString().replace("file://", "")))
            }
        }
    }

    // Drop-hover cue: a soft primary tint + outline while a drag is over
    // the sidebar, matching the folder rows' containsDrag highlight
    // language.
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Qt.alpha(Color.scheme.primary, 0.08)
        border.width: 2
        border.color: Qt.alpha(Color.scheme.primary, 0.5)
        opacity: pinDropArea.containsDrag ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }
}
