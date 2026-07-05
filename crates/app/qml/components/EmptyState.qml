import QtQuick
import "../shapes" as MaterialShapes
import "../shapes/material-shapes.js" as MaterialShapesFn
import com.filemanager.app 1.0

// Expressive empty state for a contentless view (see docs/superpowers/
// specs/2026-07-05-navigation-and-states-design.md): a large soft
// catalog shape + one line of text, echoing DecorativeShapesBackground's
// language. Three variants, first match wins: active search ("No
// matches"), Trash ("Trash is empty"), plain empty folder — which also
// offers a tonal New folder button. Visibility is main.qml's job (it
// owns the isListing/count logic); this component only renders. The
// root Item is sized to its content and has no MouseArea, so clicks
// outside the button fall through to the background (context menu,
// empty-space drops).
Item {
    id: root

    property var fileModel
    signal newFolderRequested()

    readonly property bool searchVariant: fileModel ? fileModel.searchActive : false
    readonly property bool trashVariant: fileModel
        ? (!searchVariant && fileModel.currentPath === fileModel.trashPath)
        : false

    readonly property string title: searchVariant ? "No matches"
        : trashVariant ? "Trash is empty"
        : "This folder is empty"
    readonly property string body: searchVariant ? "Nothing here matches your search."
        : trashVariant ? "Deleted items land here before they're gone for good."
        : "Drop files here or create something."

    width: _column.width
    height: _column.height

    // Screen-level entrance (a state appearing), so bezier — not spring.
    onVisibleChanged: if (visible) _entrance.restart()

    ParallelAnimation {
        id: _entrance
        NumberAnimation {
            target: _column
            property: "opacity"
            from: 0
            to: 1
            duration: Motion.standardDecelerate.duration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.standardDecelerate.bezier
        }
        NumberAnimation {
            target: _column
            property: "scale"
            from: 0.92
            to: 1
            duration: Motion.standardDecelerate.duration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.standardDecelerate.bezier
        }
    }

    Column {
        id: _column
        spacing: 8

        MaterialShapes.ShapeCanvas {
            width: 160
            height: 160
            anchors.horizontalCenter: parent.horizontalCenter
            color: Qt.alpha(Color.scheme.primary, 0.10)
            roundedPolygon: MaterialShapesFn.getCookie12Sided()
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.title
            color: Color.scheme.surfaceText
            font.family: Type.titleLarge.family
            font.weight: Type.titleLarge.weight
            font.pixelSize: Type.titleLarge.size
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.body
            color: Qt.alpha(Color.scheme.surfaceText, 0.7)
            font.family: Type.bodyMedium.family
            font.pixelSize: Type.bodyMedium.size
        }

        // Breathing room between text and button.
        Item { width: 1; height: 8; visible: !root.searchVariant && !root.trashVariant }

        Button {
            visible: !root.searchVariant && !root.trashVariant
            anchors.horizontalCenter: parent.horizontalCenter
            variant: "tonal"
            text: "New folder"
            icon: "create_new_folder"
            onClicked: root.newFolderRequested()
        }
    }
}
