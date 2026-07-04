import QtQuick
import "../shapes" as MaterialShapes
import "../shapes/material-shapes.js" as MaterialShapesFn
import com.filemanager.app 1.0

// A standard (non-extended) M3 FAB for the single most common creation
// action — "New folder". Floats over the file view, fixed on screen
// regardless of scroll position (main.qml places it as a sibling of the
// ListView/GridView Loader, not inside it). Its press/release shape morph
// uses the vendored MatrialShapes polygon-morph engine via ShapeCanvas —
// the same primitive ShapeLoader.qml already uses for the busy spinner —
// a genuine catalog-shape morph, not just a corner-radius spring like
// Button.qml's press state.
Item {
    id: root

    signal clicked

    width: 56
    height: 56

    MaterialShapes.ShapeCanvas {
        anchors.fill: parent
        color: Color.scheme.primaryContainer
        // Idle: a softly rounded square — the closest MatrialShapes
        // catalog match to M3's baseline "large" FAB shape token (not a
        // plain circle). Pressed: the classic square-to-cookie flourish
        // associated with M3 Expressive FABs.
        roundedPolygon: _area.pressed ? MaterialShapesFn.getCookie4Sided() : MaterialShapesFn.getSquare()
    }

    Icon {
        anchors.centerIn: parent
        content: "add"
        iconSize: 24
        color: Color.scheme.primaryContainerText
    }

    MouseArea {
        id: _area
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
