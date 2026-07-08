import QtQuick
import com.orbit.app 1.0

// M3 Expressive contextual floating toolbar — springs up from the bottom
// edge of the file view while 2+ items are selected, and sinks away when
// the selection drops below that (see docs/superpowers/specs/
// 2026-07-05-expressive-feedback-design.md). A pure consumer of the
// model's selection state: it never changes selection semantics, and it
// is deliberately NOT part of main.qml's anyPopupOpen — shortcuts stay
// live and act on the same selection this toolbar mirrors. Delete goes
// through the confirming dialog path (the signals below), matching the
// context menu rather than the Delete key's immediate trash.
Item {
    id: root

    property var fileModel
    signal deleteRequested(int count)
    signal deletePermanentlyRequested(int count)

    // In Trash, Copy/Cut/Delete make no sense on trashed entries —
    // Restore / Delete Permanently replace them.
    readonly property bool inTrash: fileModel ? fileModel.currentPath === fileModel.trashPath : false
    readonly property bool shown: fileModel ? fileModel.selectionCount >= 2 : false
    readonly property int liveCount: fileModel ? fileModel.selectionCount : 0
    // The label keeps its last >=2 value while the toolbar sinks away,
    // so the exit never flashes "0 selected".
    property int shownCount: 2
    onLiveCountChanged: if (liveCount >= 2) shownCount = liveCount

    width: _row.width + 12
    height: 56
    // Fully hidden = actually gone: opacity alone would leave the
    // MouseAreas hover/click-active in an invisible strip.
    visible: shown || opacity > 0
    opacity: shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    // Spatial spring entrance/exit per the motion rule — the toolbar
    // rests below the view's clipped bottom edge and springs up into
    // place, rather than fading in situ.
    transform: Translate {
        y: root.shown ? 0 : root.height + 24
        Behavior on y {
            SpringAnimation {
                spring: Motion.springStandard.spring
                damping: Motion.springStandard.damping
            }
        }
    }

    // Same hover-circle icon-button pattern as TopAppBar's buttons: the
    // Icon is a sibling of the highlight, not its child, so it doesn't
    // fade with the highlight's opacity.
    component ToolbarButton: Item {
        id: btn
        property string icon: ""
        property string tip: ""
        signal activated()
        width: 44
        height: 44
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
            anchors.fill: parent
            radius: Shape.full
            color: Elevation.surfaceAt(3)
            opacity: _btnArea.containsMouse ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }

        Icon {
            anchors.centerIn: parent
            content: btn.icon
            iconSize: 20
            color: Color.scheme.surfaceText
        }

        MouseArea {
            id: _btnArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.activated()
        }

        Tooltip {
            text: btn.tip
            hovered: _btnArea.containsMouse
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Shape.full
        color: Color.scheme.surfaceContainerHigh
    }

    Row {
        id: _row
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
            anchors.verticalCenter: parent.verticalCenter
            leftPadding: 16
            rightPadding: 10
            text: root.shownCount + " selected"
            color: Color.scheme.surfaceText
            font.family: Type.labelLarge.family
            font.pixelSize: Type.labelLarge.size
            font.weight: Font.Medium
        }

        ToolbarButton { icon: "content_copy"; tip: "Copy"; visible: !root.inTrash; onActivated: root.fileModel.copySelection() }
        ToolbarButton { icon: "content_cut"; tip: "Cut"; visible: !root.inTrash; onActivated: root.fileModel.cutSelection() }
        ToolbarButton { icon: "delete"; tip: "Move to Trash"; visible: !root.inTrash; onActivated: root.deleteRequested(root.liveCount) }
        ToolbarButton { icon: "restore_from_trash"; tip: "Restore"; visible: root.inTrash; onActivated: root.fileModel.restoreSelection() }
        ToolbarButton { icon: "delete_forever"; tip: "Delete permanently"; visible: root.inTrash; onActivated: root.deletePermanentlyRequested(root.liveCount) }

        Rectangle {
            width: 1
            height: 24
            anchors.verticalCenter: parent.verticalCenter
            color: Qt.alpha(Color.scheme.surfaceText, 0.25)
        }

        ToolbarButton { icon: "close"; tip: "Clear selection"; onActivated: root.fileModel.clearSelection() }
    }
}
