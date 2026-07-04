import QtQuick
import "../shapes" as MaterialShapes
import "../shapes/material-shapes.js" as MaterialShapesFn
import com.filemanager.app 1.0

// A small corner badge on a file/folder's icon, layered on top of the
// row/tile's existing flat selection tint (added by the multi-select
// feature — see FileListItem.qml/FileGridItem.qml's `selected`-bound
// Rectangle). Purely binary on `selected`, not blended with hover — a
// hover-preview opacity was tried first and it meant clicking to
// deselect only faded the badge to a lingering half-opacity outline
// (since the row was still hovered right after the click) instead of
// making it disappear outright. Selected, it morphs (via the same
// ShapeCanvas/MatrialShapes primitive ShapeLoader.qml uses) into a
// filled gem shape with a checkmark on top. A gem (not a many-lobed
// cookie/burst shape) was chosen because a busier polygon's lobes blur
// together at this badge's small (20x20 typical) size.
Item {
    id: root

    property bool selected: false

    signal toggleRequested

    opacity: root.selected ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

    MaterialShapes.ShapeCanvas {
        anchors.fill: parent
        color: root.selected ? Color.scheme.primary : "transparent"
        borderWidth: root.selected ? 0 : 1.5
        borderColor: Color.scheme.outline
        roundedPolygon: root.selected ? MaterialShapesFn.getGem() : MaterialShapesFn.getCircle()
    }

    Icon {
        anchors.centerIn: parent
        content: "check"
        iconSize: 12
        color: Color.scheme.primaryText
        opacity: root.selected ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggleRequested()
    }
}
