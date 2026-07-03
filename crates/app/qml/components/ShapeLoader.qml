import QtQuick
import "../shapes" as MaterialShapes
import "../shapes/material-shapes.js" as MaterialShapesFn
import com.filemanager.app 1.0

// A small M3 Expressive loading motif: cycles through the MatrialShapes
// catalog, morphing and rotating between each, using the vendored
// polygon-morph engine (see qml/shapes/). Adapted from the quickshell
// project's CustomLoader.qml.
Item {
    id: root

    property color color: Color.scheme.primary
    property real size: 32
    property bool running: true

    width: size
    height: size

    property int _shapeIdx: 0
    property real _rotation: 0
    property real _rotationBase: 0

    property var _shapes: [
        MaterialShapesFn.getCookie12Sided,
        MaterialShapesFn.getSlanted,
        MaterialShapesFn.getCircle,
        MaterialShapesFn.getCookie4Sided,
        MaterialShapesFn.getGem,
        MaterialShapesFn.getPill
    ]

    SequentialAnimation {
        loops: Animation.Infinite
        running: root.running

        ScriptAction {
            script: root._shapeIdx = (root._shapeIdx + 1) % root._shapes.length
        }

        NumberAnimation {
            target: root; property: "_rotation"
            to: root._rotationBase + 180
            duration: 700; easing.type: Easing.OutExpo
        }

        ScriptAction {
            script: root._rotationBase += 180
        }

        PauseAnimation { duration: 100 }
    }

    MaterialShapes.ShapeCanvas {
        anchors.centerIn: parent
        width: root.size
        height: root.size
        color: root.color
        rotation: root._rotation
        roundedPolygon: root._shapes[root._shapeIdx]()
    }
}
