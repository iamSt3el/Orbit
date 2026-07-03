pragma Singleton
import QtQuick

QtObject {
    // M3 baseline + emphasized type scale (Roboto). Sizes in px (1sp == 1px here).
    readonly property QtObject displayLarge: QtObject {
        readonly property string family: "Roboto"
        readonly property int weight: Font.Normal
        readonly property int size: 57
    }
    readonly property QtObject displayMedium: QtObject {
        readonly property string family: "Roboto"
        readonly property int weight: Font.Normal
        readonly property int size: 45
    }
    readonly property QtObject displaySmall: QtObject {
        readonly property string family: "Roboto"
        readonly property int weight: Font.Normal
        readonly property int size: 36
    }
    readonly property QtObject headlineLarge: QtObject {
        readonly property string family: "Roboto"
        readonly property int weight: Font.Normal
        readonly property int size: 32
    }
    readonly property QtObject headlineMedium: QtObject {
        readonly property string family: "Roboto"
        readonly property int weight: Font.Normal
        readonly property int size: 28
    }
    readonly property QtObject headlineSmall: QtObject {
        readonly property string family: "Roboto"
        readonly property int weight: Font.Normal
        readonly property int size: 24
    }
    readonly property QtObject titleLarge: QtObject {
        readonly property string family: "Roboto"
        readonly property int weight: Font.Normal
        readonly property int size: 22
    }
    readonly property QtObject titleLargeEmphasized: QtObject {
        readonly property string family: "Roboto"
        readonly property int weight: Font.Bold
        readonly property int size: 22
    }
    readonly property QtObject titleMedium: QtObject {
        readonly property string family: "Roboto"
        readonly property int weight: Font.Medium
        readonly property int size: 16
    }
    readonly property QtObject titleSmall: QtObject {
        readonly property string family: "Roboto"
        readonly property int weight: Font.Medium
        readonly property int size: 14
    }
    readonly property QtObject bodyLarge: QtObject {
        readonly property string family: "Roboto"
        readonly property int weight: Font.Normal
        readonly property int size: 16
    }
    readonly property QtObject bodyMedium: QtObject {
        readonly property string family: "Roboto"
        readonly property int weight: Font.Normal
        readonly property int size: 14
    }
    readonly property QtObject bodySmall: QtObject {
        readonly property string family: "Roboto"
        readonly property int weight: Font.Normal
        readonly property int size: 12
    }
    readonly property QtObject labelLarge: QtObject {
        readonly property string family: "Roboto"
        readonly property int weight: Font.Medium
        readonly property int size: 14
    }
    readonly property QtObject labelMedium: QtObject {
        readonly property string family: "Roboto"
        readonly property int weight: Font.Medium
        readonly property int size: 12
    }
    readonly property QtObject labelSmall: QtObject {
        readonly property string family: "Roboto"
        readonly property int weight: Font.Medium
        readonly property int size: 11
    }
}
