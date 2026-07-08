import QtQuick
import "../shapes" as MaterialShapes
import "../shapes/material-shapes.js" as MaterialShapesFn
import com.orbit.app 1.0

// M3 Expressive FAB menu (roadmap item 2): the FAB from Fab.qml, grown a
// toggled action stack. Closed, it renders exactly like the plain FAB;
// open, the add glyph spins 45° into a ×, the body morphs to the cookie
// shape, and labeled action pills spring up above it — farther pills
// travel farther, which reads as a bottom-up stagger. Dismissed by the ×,
// an action, a click anywhere outside (scrim MouseArea below), or Esc —
// Esc is wired in main.qml's existing Cancel Shortcut (a second Shortcut
// on the same sequence here would be ambiguous and break both).
// Deliberately NOT part of anyPopupOpen: it's a FAB, not a modal, same
// precedent as the selection toolbar.
Item {
    id: root

    property var fileModel
    signal newFolderRequested()
    signal newFileRequested()
    signal pasteRequested()

    property bool expanded: false
    // canPaste() is an invokable, not a bindable property — sampled at
    // open time, exactly like ContextMenu does.
    property var _actions: []

    width: 56
    height: 56
    // Above the outside-click scrim below, which is above everything else
    // in fileViewArea.
    z: 20

    function toggle() {
        if (!root.expanded) {
            var acts = [
                { label: "New folder", icon: "create_new_folder", action: "folder" },
                { label: "New file", icon: "note_add", action: "file" }
            ]
            if (root.fileModel && root.fileModel.canPaste()) {
                acts.push({ label: "Paste here", icon: "content_paste", action: "paste" })
            }
            root._actions = acts
        }
        root.expanded = !root.expanded
    }

    function dismiss() {
        root.expanded = false
    }

    // Outside-click scrim: fills the FAB's parent (the file view area)
    // while open. Transparent — M3's FAB menu scrim is optional and a
    // dimmed one would overstate a three-item menu. Reparented so it can
    // cover the whole view area from inside this component.
    MouseArea {
        parent: root.parent
        anchors.fill: parent
        visible: root.expanded
        z: 19
        acceptedButtons: Qt.AllButtons
        hoverEnabled: false
        onClicked: root.dismiss()
    }

    // The action stack, right-aligned above the FAB, top-to-bottom:
    // New folder, New file, Paste here.
    Column {
        id: _stack
        anchors.right: parent.right
        anchors.bottom: parent.top
        anchors.bottomMargin: 12
        spacing: 8

        Repeater {
            model: root._actions

            delegate: Item {
                id: pill
                required property var modelData
                required property int index

                // Disabled (not just transparent) while closed so the
                // exit animation can play without invisible pills
                // catching clicks.
                enabled: root.expanded
                width: _pillRow.implicitWidth + 32
                height: 48
                anchors.right: parent.right

                opacity: root.expanded ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                // Farther items start farther away — the spring makes
                // them arrive later, a stagger without per-item timers.
                transform: Translate {
                    y: root.expanded ? 0 : 24 + (root._actions.length - pill.index) * 12
                    Behavior on y {
                        SpringAnimation {
                            spring: Motion.springBouncy.spring
                            damping: Motion.springBouncy.damping
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Shape.full
                    color: Color.scheme.surfaceContainerHigh

                    Row {
                        id: _pillRow
                        anchors.centerIn: parent
                        spacing: 8

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            content: pill.modelData.icon
                            iconSize: 20
                            color: Color.scheme.primary
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: pill.modelData.label
                            color: Color.scheme.surfaceText
                            font.family: Type.labelLarge.family
                            font.weight: Type.labelLarge.weight
                            font.pixelSize: Type.labelLarge.size
                        }
                    }

                    Ripple {
                        anchors.fill: parent
                        radius: Shape.full
                        hoverColor: Qt.alpha(Color.scheme.primary, 0.08)
                        rippleColor: Qt.alpha(Color.scheme.primary, 0.2)
                        onClicked: {
                            root.dismiss()
                            if (pill.modelData.action === "folder") {
                                root.newFolderRequested()
                            } else if (pill.modelData.action === "file") {
                                root.newFileRequested()
                            } else {
                                root.pasteRequested()
                            }
                        }
                    }
                }
            }
        }
    }

    // The FAB itself — Fab.qml's exact visual (press morph included),
    // plus the expanded state: primary fill, cookie shape, glyph spun
    // into a ×.
    MaterialShapes.ShapeCanvas {
        anchors.fill: parent
        color: root.expanded ? Color.scheme.primary : Color.scheme.primaryContainer
        roundedPolygon: (_area.pressed || root.expanded)
            ? MaterialShapesFn.getCookie4Sided()
            : MaterialShapesFn.getSquare()
    }

    Icon {
        anchors.centerIn: parent
        content: "add"
        iconSize: 24
        color: root.expanded ? Color.scheme.primaryText : Color.scheme.primaryContainerText
        rotation: root.expanded ? 45 : 0
        Behavior on rotation {
            SpringAnimation {
                spring: Motion.springStandard.spring
                damping: Motion.springStandard.damping
            }
        }
    }

    MouseArea {
        id: _area
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggle()
    }
}
