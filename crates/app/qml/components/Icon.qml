import QtQuick

Text {
    id: root
    property real iconSize: 16
    property real fill: 0
    property real truncatedFill: Math.round(fill * 100) / 100

    property string content: ""
    text: content

    font {
        hintingPreference: Font.PreferFullHinting
        family: "Material Symbols Rounded"
        pixelSize: iconSize
        weight: Font.Normal + (Font.DemiBold - Font.Normal) * fill
        variableAxes: {
            "FILL": truncatedFill,
            "opsz": iconSize,
        }
    }
}
