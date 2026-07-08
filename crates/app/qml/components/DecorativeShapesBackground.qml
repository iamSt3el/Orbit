import QtQuick
import "../shapes" as MaterialShapes
import "../shapes/material-shapes.js" as MaterialShapesFn
import com.orbit.app 1.0

Item {
    anchors.fill: parent

    MaterialShapes.ShapeCanvas {
        width: 260
        height: 260
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: -80
        anchors.topMargin: -80
        color: Qt.alpha(Color.scheme.primary, 0.05)
        roundedPolygon: MaterialShapesFn.getCookie9Sided()
    }

    MaterialShapes.ShapeCanvas {
        width: 220
        height: 220
        x: parent.width * 0.3
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -70
        color: Qt.alpha(Color.scheme.primary, 0.05)
        roundedPolygon: MaterialShapesFn.getPentagon()
    }

    MaterialShapes.ShapeCanvas {
        width: 300
        height: 300
        x: parent.width * 0.52
        y: parent.height * 0.38
        color: Qt.alpha(Color.scheme.primary, 0.04)
        roundedPolygon: MaterialShapesFn.getSunny()
    }

    MaterialShapes.ShapeCanvas {
        width: 180
        height: 180
        x: parent.width * 0.32
        y: parent.height * 0.16
        color: Qt.alpha(Color.scheme.primary, 0.04)
        roundedPolygon: MaterialShapesFn.getClover4Leaf()
    }

    MaterialShapes.ShapeCanvas {
        width: 160
        height: 160
        x: parent.width * 0.78
        y: parent.height * 0.68
        color: Qt.alpha(Color.scheme.primary, 0.04)
        roundedPolygon: MaterialShapesFn.getGem()
    }
}
