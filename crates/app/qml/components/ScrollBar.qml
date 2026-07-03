import QtQuick
import com.filemanager.app 1.0

// A minimal custom scrollbar (no Qt Quick Controls, per this project's
// design system convention) for any Flickable-derived view (ListView,
// GridView). Click anywhere on the track, or drag, to jump/scroll.
Item {
    id: root

    property Flickable flickable
    width: 10

    readonly property bool _canScroll: flickable && flickable.contentHeight > flickable.height
    visible: _canScroll
    opacity: _canScroll && (_track.containsMouse || _track.pressed) ? 1 : 0.5
    Behavior on opacity { NumberAnimation { duration: 150 } }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius: width / 2
        color: Color.scheme.outlineVariant
        opacity: 0.3
    }

    Rectangle {
        id: thumb
        width: parent.width - 4
        anchors.horizontalCenter: parent.horizontalCenter
        radius: width / 2
        color: _track.pressed ? Color.scheme.primary : Color.scheme.outline

        Behavior on color { ColorAnimation { duration: 100 } }

        y: root._canScroll
            ? (root.flickable.contentY / (root.flickable.contentHeight - root.flickable.height)) * (root.height - height)
            : 0
        height: root._canScroll
            ? Math.max(32, root.height * (root.flickable.height / root.flickable.contentHeight))
            : root.height
    }

    MouseArea {
        id: _track
        anchors.fill: parent
        hoverEnabled: true

        function scrollToY(y) {
            if (!root._canScroll) {
                return
            }
            var maxScroll = root.flickable.contentHeight - root.flickable.height
            var usableTrack = root.height - thumb.height
            var ratio = Math.max(0, Math.min(1, (y - thumb.height / 2) / usableTrack))
            root.flickable.contentY = ratio * maxScroll
        }

        onPressed: (mouse) => scrollToY(mouse.y)
        onPositionChanged: (mouse) => { if (pressed) scrollToY(mouse.y) }
    }
}
