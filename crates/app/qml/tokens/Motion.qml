pragma Singleton
import QtQuick

QtObject {
    // Component-level motion: spring physics (QML SpringAnimation), tuned for
    // an M3 Expressive feel. Not a numeric port of Compose's MotionScheme —
    // QML's spring/damping units aren't equivalent to Compose's stiffness/
    // dampingRatio, so these are hand-tuned for the same *character*
    // (snappy, standard = minimal overshoot, bouncy = visible overshoot).
    readonly property QtObject springStandard: QtObject {
        readonly property real spring: 4.0
        readonly property real damping: 0.5
    }
    readonly property QtObject springBouncy: QtObject {
        readonly property real spring: 3.0
        readonly property real damping: 0.25
    }

    // Screen-level transitions: M3 easing/duration pairs (CSS cubic-bezier
    // control points, expressed as QML's single-cubic-segment bezierCurve:
    // [x1, y1, x2, y2, 1, 1]).
    readonly property QtObject standard: QtObject {
        readonly property int duration: 300
        readonly property var bezier: [0.2, 0, 0, 1, 1, 1]
    }
    readonly property QtObject standardDecelerate: QtObject {
        readonly property int duration: 250
        readonly property var bezier: [0, 0, 0, 1, 1, 1]
    }
    readonly property QtObject standardAccelerate: QtObject {
        readonly property int duration: 200
        readonly property var bezier: [0.3, 0, 1, 1, 1, 1]
    }
    readonly property QtObject emphasized: QtObject {
        readonly property int duration: 500
        readonly property var bezier: [0.2, 0, 0, 1, 1, 1]
    }
    readonly property QtObject emphasizedDecelerate: QtObject {
        readonly property int duration: 400
        readonly property var bezier: [0.05, 0.7, 0.1, 1, 1, 1]
    }
    readonly property QtObject emphasizedAccelerate: QtObject {
        readonly property int duration: 200
        readonly property var bezier: [0.3, 0, 0.8, 0.15, 1, 1]
    }
}
