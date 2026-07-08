import QtQuick
import "../util/format.js" as Format
import com.orbit.app 1.0

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
    property bool cancellable: false

    signal cancelRequested

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

        Item {
            width: parent.width
            height: 20

            Text {
                anchors.left: parent.left
                anchors.right: _cancelButton.visible ? _cancelButton.left : parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.label
                elide: Text.ElideRight
                color: Color.scheme.surfaceText
                font.family: Type.bodyMedium.family
                font.weight: Type.bodyMedium.weight
                font.pixelSize: Type.bodyMedium.size
            }

            Item {
                id: _cancelButton
                width: 20
                height: 20
                visible: root.cancellable
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    anchors.fill: parent
                    radius: Shape.full
                    color: Elevation.surfaceAt(4)
                    opacity: _cancelArea.containsMouse ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                }

                Icon {
                    anchors.centerIn: parent
                    content: "close"
                    iconSize: 14
                    color: Color.scheme.surfaceVariantText
                }

                MouseArea {
                    id: _cancelArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.cancelRequested()
                }

                Tooltip {
                    text: "Cancel"
                    hovered: _cancelArea.containsMouse
                }
            }
        }

        LinearWavyProgressBar {
            width: parent.width
            barWidth: parent.width
            barHeight: 4
            progress: root.totalBytes > 0 ? root.progress : 1
            animateWave: root.active
            progressColor: Color.scheme.primary
            trackColor: Color.scheme.outlineVariant
        }

        Item {
            width: parent.width
            height: 16
            visible: root.totalBytes > 0

            Text {
                anchors.left: parent.left
                text: Format.formatBytes(root.doneBytes) + " / " + Format.formatBytes(root.totalBytes)
                color: Color.scheme.surfaceVariantText
                font.family: Type.bodySmall.family
                font.weight: Type.bodySmall.weight
                font.pixelSize: Type.bodySmall.size
            }

            Text {
                anchors.right: parent.right
                text: root.speedLabel
                color: Color.scheme.surfaceVariantText
                font.family: Type.bodySmall.family
                font.weight: Type.bodySmall.weight
                font.pixelSize: Type.bodySmall.size
            }
        }
    }
}
