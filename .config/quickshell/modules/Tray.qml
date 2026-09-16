import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import "../"

Row {
    id: root
    spacing: 4
    readonly property int size: 16

    Repeater {
        model: SystemTray.items

        delegate: Item {
            id: trayItem
            required property var modelData
            width: root.size
            height: root.size
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined

            opacity: 0
            Component.onCompleted: appear.start()
            NumberAnimation {
                id: appear
                target: trayItem
                property: "opacity"
                to: 1
                duration: Theme.animMed
            }

            readonly property string tooltipText: {
                var t = trayItem.modelData.tooltipTitle;
                return t && t.length > 0 ? t : (trayItem.modelData.title || trayItem.modelData.id);
            }

            IconImage {
                id: icon
                anchors.fill: parent
                source: trayItem.modelData.icon
                smooth: true
                scale: mouse.pressed ? 0.82 : (mouse.containsMouse ? 1.12 : 1.0)
                Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easeOutBack } }
            }

            QsMenuAnchor {
                id: menuAnchor
                menu: trayItem.modelData.menu
                anchor.item: trayItem
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                onClicked: (m) => {
                    var item = trayItem.modelData;
                    if (m.button === Qt.RightButton) {
                        if (item.hasMenu) menuAnchor.open();
                        else item.secondaryActivate();
                    } else if (m.button === Qt.MiddleButton) {
                        item.secondaryActivate();
                    } else {
                        if (item.onlyMenu && item.hasMenu) menuAnchor.open();
                        else item.activate();
                    }
                }
                onWheel: (w) => trayItem.modelData.scroll(w.angleDelta.y, false)
            }

            Timer {
                id: tooltipDelay
                interval: 450
                onTriggered: tooltip.opacity = 1
            }
            Connections {
                target: mouse
                function onContainsMouseChanged() {
                    if (mouse.containsMouse) tooltipDelay.start();
                    else { tooltipDelay.stop(); tooltip.opacity = 0; }
                }
            }

            Rectangle {
                id: tooltip
                opacity: 0
                visible: opacity > 0
                z: 1000
                radius: 10
                color: Theme.mantle
                border.width: 1
                border.color: Theme.alpha(Theme.lavender, 0.35)
                anchors.top: parent.bottom
                anchors.topMargin: 6
                anchors.right: parent.right
                implicitWidth: tooltipLabel.implicitWidth + 16
                implicitHeight: tooltipLabel.implicitHeight + 10

                Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

                Text {
                    id: tooltipLabel
                    anchors.centerIn: parent
                    text: trayItem.tooltipText
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    wrapMode: Text.NoWrap
                }
            }
        }
    }
}
