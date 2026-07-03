pragma Singleton
import QtQuick
import com.filemanager.app 1.0

QtObject {
    // M3 elevation is communicated via tonal surface tint, not shadows.
    // Percentages are the primary-color overlay strength at each level.
    readonly property var percentages: [0, 0.05, 0.08, 0.11, 0.12, 0.14]

    function surfaceAt(level) {
        var pct = percentages[level] !== undefined ? percentages[level] : 0
        var base = Color.scheme.surface
        var tint = Color.scheme.primary
        return Qt.rgba(
            base.r + (tint.r - base.r) * pct,
            base.g + (tint.g - base.g) * pct,
            base.b + (tint.b - base.b) * pct,
            1.0
        )
    }
}
