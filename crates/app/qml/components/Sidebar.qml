import QtQuick
import com.filemanager.app 1.0

// Sizing/coloring/animation deliberately mirrors the nav rows in the
// user's quickshell "Nebula" settings app (SettingsContent.qml): 38px row
// height, 18px icon, 8px icon-label spacing, a filled `primary` pill (not
// a lighter tonal tint) on active/hover, and a slight scale bounce.
Rectangle {
    id: root

    property var fileModel
    property string currentPath: ""

    width: 200
    radius: 20
    color: Color.scheme.surfaceContainerHigh

    readonly property var _shortcuts: [
        { label: "Home", icon: "home", path: fileModel ? fileModel.homePath : "" },
        { label: "Downloads", icon: "download", path: fileModel ? fileModel.downloadsPath : "" },
        { label: "Documents", icon: "description", path: fileModel ? fileModel.documentsPath : "" },
        { label: "Trash", icon: "delete", path: fileModel ? fileModel.trashPath : "" }
    ]

    Column {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 0

        Text {
            text: "Places"
            leftPadding: 10
            bottomPadding: 10
            color: Color.scheme.outline
            font.family: Type.labelLarge.family
            font.weight: Type.labelLarge.weight
            font.pixelSize: 12
        }

        Repeater {
            model: root._shortcuts

            delegate: Item {
                id: navItem
                required property var modelData

                readonly property bool isActive: modelData.path.length > 0 && modelData.path === root.currentPath
                readonly property bool highlighted: isActive || _area.containsMouse

                width: parent.width
                implicitHeight: 38

                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: navItem.highlighted ? Color.scheme.primary : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    scale: navItem.highlighted ? 1 : 0.96
                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Icon {
                            content: navItem.modelData.icon
                            iconSize: 18
                            color: navItem.highlighted ? Color.scheme.primaryText : Color.scheme.surfaceVariantText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: navItem.modelData.label
                            color: navItem.highlighted ? Color.scheme.primaryText : Color.scheme.surfaceVariantText
                            font.family: Type.bodyLarge.family
                            font.weight: navItem.isActive ? Font.Bold : Font.Medium
                            font.pixelSize: 15
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: _area
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (navItem.modelData.path.length > 0 && root.fileModel) {
                                root.fileModel.navigate(navItem.modelData.path)
                            }
                        }
                    }
                }
            }
        }
    }
}
