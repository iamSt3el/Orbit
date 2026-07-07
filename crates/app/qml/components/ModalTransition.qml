import QtQuick
import com.filemanager.app 1.0

Item {
    id: root
    visible: false

    property Item card
    property Item scrim
    property real scrimOpacity: 0.4

    signal exited

    function enter() {
        exitAnim.stop()
        enterAnim.stop()
        if (root.card) {
            root.card.scale = 0.92
            root.card.opacity = 0
        }
        if (root.scrim) {
            root.scrim.opacity = 0
        }
        enterAnim.restart()
    }

    function exit() {
        if (exitAnim.running) {
            return
        }
        enterAnim.stop()
        exitAnim.restart()
    }

    ParallelAnimation {
        id: enterAnim
        NumberAnimation { target: root.card; property: "scale"; to: 1; duration: Motion.emphasizedDecelerate.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.emphasizedDecelerate.bezier }
        NumberAnimation { target: root.card; property: "opacity"; to: 1; duration: Motion.standard.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.standard.bezier }
        NumberAnimation { target: root.scrim; property: "opacity"; to: root.scrimOpacity; duration: Motion.standard.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.standard.bezier }
    }

    SequentialAnimation {
        id: exitAnim
        ParallelAnimation {
            NumberAnimation { target: root.card; property: "scale"; to: 0.92; duration: Motion.emphasizedAccelerate.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.emphasizedAccelerate.bezier }
            NumberAnimation { target: root.card; property: "opacity"; to: 0; duration: Motion.emphasizedAccelerate.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.emphasizedAccelerate.bezier }
            NumberAnimation { target: root.scrim; property: "opacity"; to: 0; duration: Motion.emphasizedAccelerate.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.emphasizedAccelerate.bezier }
        }
        ScriptAction { script: root.exited() }
    }
}
