import QtQuick
import QtQuick.Layouts
import com.filemanager.app 1.0

// One row's card in a vertically-stacked "grouped card" section — modeled
// on the user's quickshell "Nebula" settings screen (customComponents/
// CustomCard.qml): only a group's outer edges are fully rounded
// (Shape.largeIncreased); the edges where two rows in the same group touch
// are nearly flat (Shape.extraSmall), so a whole section reads as one
// continuous card instead of a stack of separately-rounded rectangles.
// Unlike Nebula's version, which scans sibling items at runtime to detect
// adjacency, position in the group here is just told to us by the
// caller (isFirst/isLast) — almost always a Repeater's index — which is
// simpler and doesn't depend on item ordering tricks.
Rectangle {
    id: root

    property bool isFirst: true
    property bool isLast: true

    // Children placed directly inside GroupCard go into the inner layout.
    default property alias content: _content.data

    Layout.fillWidth: true
    width: parent ? parent.width : implicitWidth
    implicitHeight: _content.implicitHeight + 28

    color: Color.scheme.surfaceContainerHigh
    topLeftRadius: root.isFirst ? Shape.largeIncreased : Shape.extraSmall
    topRightRadius: root.isFirst ? Shape.largeIncreased : Shape.extraSmall
    bottomLeftRadius: root.isLast ? Shape.largeIncreased : Shape.extraSmall
    bottomRightRadius: root.isLast ? Shape.largeIncreased : Shape.extraSmall

    ColumnLayout {
        id: _content
        anchors.fill: parent
        anchors.margins: 14
        spacing: 14
    }
}
