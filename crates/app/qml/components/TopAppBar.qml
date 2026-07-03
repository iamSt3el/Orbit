import QtQuick
import com.filemanager.app 1.0

Rectangle {
    id: root

    property string title: ""

    height: 64
    color: Elevation.surfaceAt(2)

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        text: root.title
        color: Color.scheme.surfaceText
        font.family: Type.titleLargeEmphasized.family
        font.weight: Type.titleLargeEmphasized.weight
        font.pixelSize: Type.titleLargeEmphasized.size
        elide: Text.ElideMiddle
        width: parent.width - 32
    }
}
