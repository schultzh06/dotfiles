import QtQuick
import Quickshell.Hyprland
import "../"

// Fixed 10-slot workspace switcher for one monitor. Slots never appear or
// disappear (unlike the old waybar buttons) -- they just dim/brighten, which
// keeps the bar from jumping around, while a single pill slides between
// slots (via ListView's native highlight-follows-current-item) with a
// spring animation to show the active one. Urgent workspaces pulse red.
// Clicking any slot (even an empty one) focuses/creates it via Hyprland's
// dispatch IPC -- this build's Hyprland runs a native Lua config, so every
// dispatch call must use `hl.dsp.*` call syntax instead of the plain-text
// `workspace N` form (see ~/.config/waybar/modules.jsonc for the same
// constraint hit there).
Item {
    id: root
    required property string screenName

    readonly property var hyprMonitor: {
        for (var i = 0; i < Hyprland.monitors.values.length; i++) {
            if (Hyprland.monitors.values[i].name === root.screenName) return Hyprland.monitors.values[i];
        }
        return null;
    }
    readonly property int activeId: (hyprMonitor && hyprMonitor.activeWorkspace) ? hyprMonitor.activeWorkspace.id : -1

    readonly property int slotSize: 24
    readonly property int slotSpacing: 3
    readonly property var slotIds: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

    implicitWidth: slotSize * 10 + slotSpacing * 9
    implicitHeight: Theme.barHeight - 6

    ListView {
        id: list
        anchors.fill: parent
        orientation: ListView.Horizontal
        interactive: false
        spacing: root.slotSpacing
        model: root.slotIds
        currentIndex: root.activeId - 1

        highlightFollowsCurrentItem: true
        highlightMoveDuration: -1
        highlight: Rectangle {
            width: root.slotSize
            height: root.slotSize
            radius: Theme.radius - 2
            color: Theme.accent
            opacity: root.activeId >= 1 && root.activeId <= 10 ? 1 : 0
            Behavior on x { SpringAnimation { spring: 3.2; damping: 0.42 } }
            Behavior on opacity { NumberAnimation { duration: Theme.animMed } }
        }

        delegate: Item {
            id: slotItem
            required property int modelData
            readonly property int wsId: modelData

            readonly property var wsObj: {
                var list_ = Hyprland.workspaces.values;
                for (var i = 0; i < list_.length; i++) {
                    var w = list_[i];
                    if (w.id === wsId && w.monitor && w.monitor.name === root.screenName) return w;
                }
                return null;
            }
            readonly property bool exists: wsObj !== null
            readonly property bool isActive: root.activeId === wsId
            readonly property bool isUrgent: wsObj !== null && wsObj.urgent

            width: root.slotSize
            height: root.slotSize

            scale: slotMouse.pressed ? 0.88 : (slotMouse.containsMouse ? 1.08 : 1.0)
            Behavior on scale {
                NumberAnimation { duration: Theme.animFast; easing.type: Theme.easeOutBack }
            }

            Text {
                anchors.centerIn: parent
                text: slotItem.wsId
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.bold: slotItem.isActive
                color: slotItem.isActive
                    ? Theme.base
                    : (slotItem.exists ? Theme.subtext1 : Theme.overlay0)
                opacity: slotItem.exists || slotItem.isActive ? 1.0 : 0.45

                Behavior on color { ColorAnimation { duration: Theme.animMed } }
                Behavior on opacity { NumberAnimation { duration: Theme.animMed } }

                SequentialAnimation on color {
                    running: slotItem.isUrgent && !slotItem.isActive
                    loops: Animation.Infinite
                    ColorAnimation { to: Theme.red; duration: 420 }
                    ColorAnimation { to: Theme.subtext1; duration: 420 }
                }
            }

            MouseArea {
                id: slotMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + slotItem.wsId + " })")
            }
        }
    }
}
