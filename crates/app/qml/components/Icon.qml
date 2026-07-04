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
        // The installed "Material Symbols Rounded" family resolves to a
        // static (non-variable) face on this system, so the FILL axis
        // below is a no-op for it — a separately-named static "...Filled"
        // family is what actually renders filled glyphs.
        family: root.truncatedFill >= 0.5 ? "Material Symbols Rounded Filled" : "Material Symbols Rounded"
        pixelSize: iconSize
        variableAxes: {
            "FILL": truncatedFill,
            "opsz": iconSize,
            "wght": weightAxis,
        }
    }
}
