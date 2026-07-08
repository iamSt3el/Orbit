import QtQuick
import com.orbit.app 1.0

// Circular 270° gauge — gap at the bottom, rounded caps, and a floating
// gap between the progress tip and the remaining track. Ported from the
// user's quickshell "Nebula" CustomGaugeProgress (minus its wavy mode);
// icon + percent + "Used" stack in the center, like the Nebula dashboard
// storage cards this is modeled on.
Item {
    id: root

    property real progress: 0
    property real thickness: 4
    property real gaugeRadius: Math.min(width, height) / 2 - thickness
    property color trackColor: Color.scheme.secondaryContainer
    property color progressColor: Color.scheme.primary
    property string icon: ""
    property real iconSize: 16
    // Radians of breathing room between the progress tip and the track.
    property real gap: 0.2

    // 500ms, not the usual 200 — instances start at 0 and bind their real
    // value on completion (see the Sidebar storage cards), so this Behavior
    // doubles as the entrance sweep.
    Behavior on progress {
        NumberAnimation { duration: 500; easing.type: Easing.OutCubic }
    }

    // Smooth primary→error crossfade when a capacity threshold flips the
    // color; the Canvas repaints along the way via on_FillChanged.
    Behavior on progressColor {
        ColorAnimation { duration: 200 }
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true

        readonly property real cx: width / 2
        readonly property real cy: height / 2
        // 270° arc, gap at bottom — starts bottom-left, ends bottom-right.
        readonly property real startAngle: Math.PI * 0.75
        readonly property real totalSpan: Math.PI * 1.5
        readonly property real trackEnd: startAngle + totalSpan
        readonly property real progressEnd:
            startAngle + totalSpan * Math.max(0, Math.min(1, root.progress))

        onProgressEndChanged: requestPaint()

        // Colors are dependencies too — colors.json is hot-reloadable,
        // and a Canvas only repaints when asked.
        readonly property color _track: root.trackColor
        readonly property color _fill: root.progressColor
        on_TrackChanged: requestPaint()
        on_FillChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.lineWidth = root.thickness
            ctx.lineCap = "round"
            const r = root.gaugeRadius

            // The track starts a gap past the progress tip (never more
            // than half the filled span, so tiny fills don't eat it).
            const arcSpan = progressEnd - startAngle
            const effectiveGap = root.progress > 0 ? Math.min(root.gap, arcSpan * 0.5) : 0
            const bgStart = progressEnd + effectiveGap
            if (bgStart < trackEnd) {
                ctx.beginPath()
                ctx.arc(cx, cy, r, bgStart, trackEnd, false)
                ctx.strokeStyle = root.trackColor
                ctx.stroke()
            }

            if (root.progress > 0) {
                ctx.beginPath()
                ctx.arc(cx, cy, r, startAngle, progressEnd - effectiveGap, false)
                ctx.strokeStyle = root.progressColor
                ctx.stroke()
            }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 0

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.icon.length > 0
            content: root.icon
            iconSize: root.iconSize
            color: root.progressColor
        }

        // titleSmall/labelSmall, not the Medium sizes — the whole stack
        // has to fit inside a ~64px circle without poking past the arc.
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Math.round(root.progress * 100) + "%"
            // Follows the arc (not always primary) so a capacity warning
            // recolors the number too.
            color: root.progressColor
            font.family: Type.titleSmall.family
            font.weight: Type.titleSmall.weight
            font.pixelSize: Type.titleSmall.size
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Used"
            color: Color.scheme.surfaceVariantText
            font.family: Type.labelSmall.family
            font.pixelSize: Type.labelSmall.size
        }
    }
}
