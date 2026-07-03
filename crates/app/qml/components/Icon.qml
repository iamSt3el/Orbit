import QtQuick

Text {
    id: root
    property real iconSize: 16
    property real fill: 1
    property real truncatedFill: Math.round(fill * 100) / 100
    property real weightAxis: 500

    Behavior on fill { NumberAnimation { duration: 200 } }

    property string content: ""
    text: content
    antialiasing: true
    renderType: Text.NativeRendering

    font {
        hintingPreference: Font.PreferFullHinting
        family: "Material Symbols Rounded"
        pixelSize: iconSize
        variableAxes: {
            "FILL": truncatedFill,
            "opsz": iconSize,
            "wght": weightAxis,
        }
    }
}
