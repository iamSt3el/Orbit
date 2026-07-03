import QtQuick
import com.filemanager.app 1.0

Rectangle {
    id: root

    property string title: ""
    property bool showBackButton: false
    signal backClicked

    height: 64
    color: Elevation.surfaceAt(2)

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        Rectangle {
            width: 40
            height: 40
            radius: Shape.full
            color: Elevation.surfaceAt(3)
            opacity: root.showBackButton && _backArea.containsMouse ? 1 : 0
            anchors.verticalCenter: parent.verticalCenter

            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

            Icon {
                anchors.centerIn: parent
                content: "arrow_back"
                iconSize: 22
                color: Color.scheme.surfaceText
            }

            MouseArea {
                id: _backArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: root.showBackButton
                visible: root.showBackButton
                cursorShape: Qt.PointingHandCursor
                onClicked: root.backClicked()
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            color: Color.scheme.surfaceText
            font.family: Type.titleLargeEmphasized.family
            font.weight: Type.titleLargeEmphasized.weight
            font.pixelSize: Type.titleLargeEmphasized.size
            elide: Text.ElideMiddle
            width: root.width - 100
        }
    }
}
