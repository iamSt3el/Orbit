import QtQuick
import "../shapes" as MaterialShapes
import "../shapes/material-shapes.js" as MaterialShapesFn
import com.filemanager.app 1.0

// Purely ambient texture behind the file list/grid — two large, low-opacity
// M3 shapes bleeding off opposite corners. Static (no morph, no animation):
// this is background decoration, not an interactive element, and the
// parent's `clip: true` crops the off-corner bleed. No MouseArea, so it
// can never intercept clicks or drag-select over the empty area behind it.
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
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: -60
        anchors.bottomMargin: -60
        color: Qt.alpha(Color.scheme.primary, 0.05)
        roundedPolygon: MaterialShapesFn.getPentagon()
    }
}
