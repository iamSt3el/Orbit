import QtQuick
import com.filemanager.app 1.0

// A small floating M3 snackbar shown while a background file operation
// (copy/move) is running. There's no real byte-level progress to report
// (fm_core::ops::copy/move_entry don't stream progress), so the wavy
// progress bar shows a classic indeterminate spinner: a fixed short arc
// rotating continuously, rather than a filling percentage.
Rectangle {
    id: root

    property bool active: false
    property string label: ""

    anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
    y: parent ? parent.height - height - 20 : 0
    z: 3000

    visible: opacity > 0
    opacity: active ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    width: _row.implicitWidth + 28
    height: 48
    radius: Shape.full
    color: Color.scheme.inverseSurface

    Row {
        id: _row
        anchors.centerIn: parent
        spacing: 12

        WavyProgressBar {
            id: spinner
            width: 22
            height: 22
            anchors.verticalCenter: parent.verticalCenter
            thickness: 3
            progress: 0.25
            trackColor: Qt.alpha(Color.scheme.inverseOnSurface, 0.25)
            progressColor: Color.scheme.inverseOnSurface
            animateWave: root.active

            RotationAnimation on rotation {
                running: root.active
                loops: Animation.Infinite
                from: 0
                to: 360
                duration: 900
            }
        }

        Text {
            text: root.label
            color: Color.scheme.inverseOnSurface
            font.family: Type.bodyLarge.family
            font.pixelSize: Type.bodyLarge.size
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
