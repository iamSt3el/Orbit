import QtQuick
import Qt5Compat.GraphicalEffects
import com.filemanager.app 1.0

// Drop-in interactive overlay: hover tint + M3-style press ripple.
//
//   Rectangle {
//       radius: 12
//       Ripple {
//           anchors.fill: parent
//           radius: parent.radius
//           onClicked: doSomething()
//       }
//   }
Item {
    id: root

    property real radius:            0
    property real topLeftRadius:     radius
    property real topRightRadius:    radius
    property real bottomLeftRadius:  radius
    property real bottomRightRadius: radius

    property color hoverColor:  Qt.alpha(Color.scheme.primary, 0.08)
    property color pressColor:  Qt.alpha(Color.scheme.primary, 0.14)
    property color rippleColor: Qt.alpha(Color.scheme.primary, 0.25)
    property bool  hoverEnabled: true

    readonly property alias containsMouse: _mouse.containsMouse
    readonly property alias pressed:       _mouse.pressed

    signal clicked
    signal rightClicked

    Rectangle {
        anchors.fill: parent
        topLeftRadius:     root.topLeftRadius
        topRightRadius:    root.topRightRadius
        bottomLeftRadius:  root.bottomLeftRadius
        bottomRightRadius: root.bottomRightRadius
        // Constant color, animated opacity — not a Behavior on `color`
        // itself. Animating color from "transparent" to an opaque tint
        // cross-interpolates alpha and RGB together, which visibly flashes
        // through an intermediate near-black state before settling.
        color: root.hoverColor
        opacity: _mouse.containsMouse ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }

    Item {
        id: _rippleClip
        anchors.fill: parent

        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width:              _rippleClip.width
                height:             _rippleClip.height
                topLeftRadius:     root.topLeftRadius
                topRightRadius:    root.topRightRadius
                bottomLeftRadius:  root.bottomLeftRadius
                bottomRightRadius: root.bottomRightRadius
            }
        }

        Rectangle {
            id: _ripple
            width: 0; height: 0
            radius: width / 2
            opacity: 0
            color: root.rippleColor
            transform: Translate { x: -_ripple.width / 2; y: -_ripple.height / 2 }
        }
    }

    SequentialAnimation {
        id: _anim
        property real px: 0; property real py: 0; property real r: 0

        PropertyAction { target: _ripple; property: "x";       value: _anim.px }
        PropertyAction { target: _ripple; property: "y";       value: _anim.py }
        PropertyAction { target: _ripple; property: "width";   value: 0 }
        PropertyAction { target: _ripple; property: "height";  value: 0 }
        PropertyAction { target: _ripple; property: "opacity"; value: 1 }
        NumberAnimation {
            target: _ripple; properties: "width,height"
            to: _anim.r * 2
            duration: Motion.standard.duration
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: _ripple; property: "opacity"; to: 0
            duration: Motion.standardAccelerate.duration
            easing.type: Easing.InOutCubic
        }
    }

    MouseArea {
        id: _mouse
        anchors.fill: parent
        hoverEnabled: root.hoverEnabled
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onPressed: event => {
            const d = (ox, oy) => ox*ox + oy*oy
            _anim.px = event.x; _anim.py = event.y
            _anim.r = Math.sqrt(Math.max(
                d(event.x, event.y), d(event.x, height - event.y),
                d(width - event.x, event.y), d(width - event.x, height - event.y)
            ))
            _anim.restart()
        }

        onClicked: mouse => mouse.button === Qt.RightButton ? root.rightClicked() : root.clicked()
    }
}
