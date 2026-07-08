import QtQuick
import com.orbit.app 1.0

// M3 Expressive horizontal wavy progress indicator — ported from the
// user's quickshell music player's playback scrubber
// (modules/customComponents/CustomProgressBar.qml, the "sperm" progress
// bar), adapted to a plain Item since this project doesn't use Qt Quick
// Controls (the original subclasses ProgressBar).
Item {
    id: root

    property real progress: 0 // 0-1
    property real barWidth: 200
    property real barHeight: 4
    property real gap: 4
    property color progressColor: Color.scheme.primary
    property color trackColor: Color.scheme.secondaryContainer

    property bool wavy: true
    property bool animateWave: true
    property real waveAmplitudeMultiplier: wavy ? 0.5 : 0
    property real waveFrequency: 8
    property real waveFps: 60

    implicitWidth: barWidth
    implicitHeight: barHeight

    Behavior on waveAmplitudeMultiplier {
        NumberAnimation { duration: 100; easing.type: Easing.OutQuad }
    }
    Behavior on progress {
        NumberAnimation { duration: 100; easing.type: Easing.OutQuad }
    }

    // The wavy fill (0..progress). The remaining track is a plain flat
    // Rectangle below, matching the reference: only the "already played"
    // portion of the original scrubber wiggles.
    Canvas {
        id: wavyFill
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        // Taller than the bar itself so the wave has room to swing without
        // clipping — matches the reference's `parent.height * 6`.
        height: parent.height * 6
        antialiasing: true

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            var fillWidth = root.progress * width
            var amplitude = root.barHeight * root.waveAmplitudeMultiplier
            var frequency = root.waveFrequency
            // Wall-clock phase, not a persisted property — matches the
            // reference exactly; the wave keeps traveling at a constant
            // rate rather than a rate tied to redraws.
            var phase = Date.now() / 400.0
            var centerY = height / 2
            var half = root.barHeight / 2

            ctx.strokeStyle = root.progressColor
            ctx.lineWidth = root.barHeight
            ctx.lineCap = "round"
            ctx.beginPath()
            for (var x = half; x <= fillWidth; x += 1) {
                var waveY = centerY + amplitude * Math.sin(frequency * 2 * Math.PI * x / width + phase)
                if (x === half) {
                    ctx.moveTo(x, waveY)
                } else {
                    ctx.lineTo(x, waveY)
                }
            }
            ctx.stroke()
        }

        Connections {
            target: root
            function onProgressChanged() { wavyFill.requestPaint() }
            function onProgressColorChanged() { wavyFill.requestPaint() }
            function onBarHeightChanged() { wavyFill.requestPaint() }
        }

        Timer {
            interval: 1000 / root.waveFps
            running: root.animateWave
            repeat: root.wavy
            onTriggered: wavyFill.requestPaint()
        }
    }

    Rectangle {
        // Remaining track, to the right of the progress fill.
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, (1 - root.progress) * parent.width - root.gap)
        height: root.barHeight
        radius: root.barHeight / 2
        color: root.trackColor
    }

    Rectangle {
        // Trailing "stop point" dot at the far right edge, matching the
        // M3 Expressive linear indicator and the reference component.
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: root.gap
        height: root.gap
        radius: root.gap / 2
        color: root.progressColor
    }
}
