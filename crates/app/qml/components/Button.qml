import QtQuick
import com.filemanager.app 1.0

Item {
    id: root

    property string variant: "filled" // filled | outlined | text | tonal | elevated
    property bool destructive: false
    property string text: ""
    property string icon: ""
    property string tooltip: ""
    signal clicked

    implicitWidth: _row.implicitWidth + 48
    implicitHeight: 40

    readonly property color _containerColor: {
        if (variant === "filled") return root.destructive ? Color.scheme.error : Color.scheme.primary
        if (variant === "tonal") return Color.scheme.secondaryContainer
        if (variant === "elevated") return Elevation.surfaceAt(1)
        return "transparent"
    }
    readonly property color _labelColor: {
        if (variant === "filled") return root.destructive ? Color.scheme.errorText : Color.scheme.primaryText
        if (variant === "tonal") return Color.scheme.secondaryContainerText
        return root.destructive ? Color.scheme.error : Color.scheme.primary
    }

    Rectangle {
        id: _background
        anchors.fill: parent
        radius: pressArea.pressed ? Shape.medium : Shape.full
        color: root._containerColor
        border.width: root.variant === "outlined" ? 1 : 0
        border.color: Color.scheme.outline

        Behavior on radius {
            SpringAnimation {
                spring: Motion.springStandard.spring
                damping: Motion.springStandard.damping
            }
        }

        Ripple {
            id: pressArea
            anchors.fill: parent
            radius: parent.radius
            hoverColor: Qt.alpha(root._labelColor, 0.08)
            rippleColor: Qt.alpha(root._labelColor, 0.2)
            onClicked: root.clicked()
        }

        Tooltip {
            text: root.tooltip
            hovered: pressArea.containsMouse
        }
    }

    Row {
        id: _row
        anchors.centerIn: parent
        spacing: 8

        Icon {
            visible: root.icon.length > 0
            content: root.icon
            iconSize: 18
            color: root._labelColor
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: root.text
            color: root._labelColor
            font.family: Type.labelLarge.family
            font.weight: Type.labelLarge.weight
            font.pixelSize: Type.labelLarge.size
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
