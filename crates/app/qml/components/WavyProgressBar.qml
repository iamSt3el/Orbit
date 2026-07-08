import QtQuick
import com.orbit.app 1.0

// M3 Expressive circular progress indicator with an optional wavy
// (sinusoidal) arc — Material 3's 2025 update introduced wavy progress
// indicators as an alternative to plain arcs. Adapted from the quickshell
// project's circular progress bar component.
Item {
    id: root

    property real progress: 0.6
    property real thickness: 4
    property real radius: Math.min(width, height) / 2 - thickness
    property color trackColor: Color.scheme.secondaryContainer
    property color progressColor: Color.scheme.primary
    property real gap: 0

    property bool wavy: true
    property bool animateWave: true
    property real waveAmplitudeMultiplier: wavy ? 0.5 : 0
    property real waveFrequency: 20
    property real waveFps: 60

    // Dedicated phase tracker to maintain visual position when animation is paused.
    property real wavePhase: 0

    Behavior on waveAmplitudeMultiplier {
        NumberAnimation { duration: 100; easing.type: Easing.OutQuad }
    }

    Behavior on progress {
        NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true

        readonly property real centerX: width / 2
        readonly property real centerY: height / 2
        readonly property real startAngle: (-Math.PI / 2) - 0.1
        readonly property real endAngle: startAngle + (2 * Math.PI * root.progress)

        onEndAngleChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()

            ctx.lineWidth = root.thickness
            ctx.lineCap = "round"

            const r = root.radius
            const cx = centerX
            const cy = centerY

            const amplitude = root.thickness * root.waveAmplitudeMultiplier
            const phase = root.wavePhase

            // --- Track (background arc) ---
            const trackStart = endAngle
            const trackEnd = (Math.PI / 2 + Math.PI) - root.gap

            if (amplitude > 0 && trackEnd > trackStart) {
                const steps = Math.max(1, Math.round(Math.abs(trackEnd - trackStart) / 0.02))
                ctx.beginPath()
                for (let i = 0; i <= steps; i++) {
                    const angle = trackStart + (trackEnd - trackStart) * i / steps
                    const waveR = r + amplitude * Math.sin(root.waveFrequency * (angle - startAngle) + phase)
                    const x = cx + waveR * Math.cos(angle)
                    const y = cy + waveR * Math.sin(angle)
                    if (i === 0) ctx.moveTo(x, y)
                    else ctx.lineTo(x, y)
                }
                ctx.strokeStyle = root.trackColor
                ctx.stroke()
            } else {
                ctx.beginPath()
                ctx.arc(cx, cy, r, trackStart, trackEnd, false)
                ctx.strokeStyle = root.trackColor
                ctx.stroke()
            }

            // --- Progress arc ---
            if (root.progress > 0) {
                const start = startAngle
                const arcSpan = endAngle - startAngle
                const effectiveGap = Math.min(root.gap, arcSpan * 0.5)
                const end = endAngle - effectiveGap

                if (amplitude > 0 && end > start) {
                    const steps = Math.max(1, Math.round(Math.abs(end - start) / 0.02))
                    ctx.beginPath()
                    for (let i = 0; i <= steps; i++) {
                        const angle = start + (end - start) * i / steps
                        const waveR = r + amplitude * Math.sin(root.waveFrequency * (angle - startAngle) + phase)
                        const x = cx + waveR * Math.cos(angle)
                        const y = cy + waveR * Math.sin(angle)
                        if (i === 0) ctx.moveTo(x, y)
                        else ctx.lineTo(x, y)
                    }
                    ctx.strokeStyle = root.progressColor
                    ctx.stroke()
                } else {
                    ctx.beginPath()
                    ctx.arc(cx, cy, r, start, end, false)
                    ctx.strokeStyle = root.progressColor
                    ctx.stroke()
                }
            }
        }

        Timer {
            interval: 1000 / root.waveFps
            running: root.animateWave
            repeat: root.wavy
            onTriggered: {
                root.wavePhase += (1000 / root.waveFps) / 400.0
                canvas.requestPaint()
            }
        }
    }
}
