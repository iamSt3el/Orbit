import QtQuick
import com.orbit.app 1.0

Item {
    id: root

    property var fileModel
    signal closed

    anchors.fill: parent
    visible: false
    z: 2000

    property real centerOffsetX: 0

    ModalTransition {
        id: _transition
        card: dialog
        scrim: _scrim
        onExited: {
            root.visible = false
            root.closed()
        }
    }

    function open() {
        visible = true
        _transition.enter()
        root.forceActiveFocus()
    }

    function close() {
        _transition.exit()
    }

    Keys.onEscapePressed: root.close()
    Keys.onShortcutOverride: (event) => {
        event.accepted = event.key === Qt.Key_Escape
    }

    Rectangle {
        id: _scrim
        anchors.fill: parent
        color: Color.scheme.surface
        opacity: 0.4

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.AllButtons
            onClicked: root.close()
            onWheel: (wheel) => { wheel.accepted = true }
        }
    }

    Rectangle {
        id: dialog
        Accessible.role: Accessible.Dialog
        Accessible.name: "About Orbit"
        width: 320
        height: _column.implicitHeight + 48
        radius: Shape.extraLarge
        color: Elevation.surfaceAt(3)
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: root.centerOffsetX

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onWheel: (wheel) => { wheel.accepted = true }
        }

        Column {
            id: _column
            anchors.top: parent.top
            anchors.topMargin: 24
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            spacing: 8

            Rectangle {
                width: 72
                height: 72
                radius: Shape.full
                color: Color.scheme.primaryContainer
                anchors.horizontalCenter: parent.horizontalCenter

                Icon {
                    anchors.centerIn: parent
                    content: "orbit"
                    iconSize: 40
                    color: Color.scheme.primaryContainerText
                }
            }

            Item { width: 1; height: 4 }

            Text {
                text: "Orbit"
                anchors.horizontalCenter: parent.horizontalCenter
                color: Color.scheme.surfaceText
                font.family: Type.headlineSmall.family
                font.weight: Font.Bold
                font.pixelSize: Type.headlineSmall.size
            }

            Rectangle {
                width: _versionText.implicitWidth + 20
                height: 24
                radius: Shape.full
                color: Color.scheme.secondaryContainer
                anchors.horizontalCenter: parent.horizontalCenter

                Text {
                    id: _versionText
                    anchors.centerIn: parent
                    text: "v" + (root.fileModel ? root.fileModel.appVersion() : "")
                    color: Color.scheme.secondaryContainerText
                    font.family: Type.labelMedium.family
                    font.weight: Type.labelMedium.weight
                    font.pixelSize: Type.labelMedium.size
                }
            }

            Item { width: 1; height: 6 }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: "A fast, expressive file manager for Linux"
                color: Color.scheme.surfaceVariantText
                font.family: Type.bodyMedium.family
                font.pixelSize: Type.bodyMedium.size
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "Rust · Qt Quick · Material 3 Expressive"
                color: Color.scheme.surfaceVariantText
                font.family: Type.labelMedium.family
                font.weight: Type.labelMedium.weight
                font.pixelSize: Type.labelMedium.size
            }

            Item { width: 1; height: 8 }

            Row {
                anchors.right: parent.right

                Button {
                    variant: "text"
                    text: "Close"
                    onClicked: root.close()
                }
            }
        }
    }
}
