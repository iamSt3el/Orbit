import QtQuick
import "../util/format.js" as Format
import com.filemanager.app 1.0

// Copy/move progress, pinned to the bottom of the sidebar — speed, done
// size, and total size alongside the horizontal wavy progress bar (ported
// from the quickshell music player's scrubber).
Item {
    id: root

    property bool active: false
    property string label: ""
    property real doneBytes: 0
    property real totalBytes: 0
    property string speedLabel: ""

    readonly property real progress: totalBytes > 0 ? Math.min(1, doneBytes / totalBytes) : 0

    visible: opacity > 0
    opacity: active ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    implicitHeight: _column.implicitHeight + 20

    Rectangle {
        anchors.fill: parent
        radius: Shape.medium
        color: Color.scheme.surfaceContainerHighest
    }

    Column {
        id: _column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Text {
            text: root.label
            width: parent.width
            elide: Text.ElideRight
            color: Color.scheme.surfaceText
            font.family: Type.bodyMedium.family
            font.weight: Type.bodyMedium.weight
            font.pixelSize: Type.bodyMedium.size
        }

        LinearWavyProgressBar {
            width: parent.width
            barWidth: parent.width
            barHeight: 4
            progress: root.progress
            animateWave: root.active
            progressColor: Color.scheme.primary
            trackColor: Color.scheme.outlineVariant
        }

        Item {
            width: parent.width
            height: 16

            Text {
                anchors.left: parent.left
                text: Format.formatBytes(root.doneBytes) + " / " + Format.formatBytes(root.totalBytes)
                color: Color.scheme.surfaceVariantText
                font.family: Type.labelLarge.family
                font.pixelSize: 11
            }

            Text {
                anchors.right: parent.right
                text: root.speedLabel
                color: Color.scheme.surfaceVariantText
                font.family: Type.labelLarge.family
                font.pixelSize: 11
            }
        }
    }
}
