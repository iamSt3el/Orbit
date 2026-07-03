import QtQuick
import com.filemanager.app 1.0

Rectangle {
    id: root

    property var fileModel
    property string currentPath: ""

    width: 220
    color: Color.scheme.surfaceContainerLow

    readonly property var _shortcuts: [
        { label: "Home", icon: "home", path: fileModel ? fileModel.homePath : "" },
        { label: "Downloads", icon: "download", path: fileModel ? fileModel.downloadsPath : "" },
        { label: "Documents", icon: "description", path: fileModel ? fileModel.documentsPath : "" },
        { label: "Trash", icon: "delete", path: fileModel ? fileModel.trashPath : "" }
    ]

    Column {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 2

        Repeater {
            model: root._shortcuts

            delegate: Item {
                required property var modelData

                readonly property bool isActive: modelData.path.length > 0 && modelData.path === root.currentPath

                width: parent.width
                height: 44

                Rectangle {
                    anchors.fill: parent
                    radius: Shape.full
                    color: isActive ? Color.scheme.secondaryContainer : "transparent"

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: Elevation.surfaceAt(1)
                        opacity: !isActive && _area.containsMouse ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12

                        Icon {
                            content: modelData.icon
                            iconSize: 20
                            color: isActive ? Color.scheme.secondaryContainerText : Color.scheme.surfaceVariantText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: modelData.label
                            color: isActive ? Color.scheme.secondaryContainerText : Color.scheme.surfaceText
                            font.family: Type.bodyLarge.family
                            font.pixelSize: Type.bodyLarge.size
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: _area
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData.path.length > 0 && root.fileModel) {
                                root.fileModel.navigate(modelData.path)
                            }
                        }
                    }
                }
            }
        }
    }
}
