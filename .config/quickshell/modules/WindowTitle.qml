import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import "../"

// Shows the relevant focused-window title for one monitor: the globally
// active window if it's on this screen, otherwise the most recently
// activated window still open on this screen's active workspace, otherwise
// "Desktop". Reacts live to Hyprland's bindable properties -- no polling.
Pill {
    id: root
    required property string screenName
    interactive: false

    readonly property var hyprMonitor: {
        for (var i = 0; i < Hyprland.monitors.values.length; i++) {
            if (Hyprland.monitors.values[i].name === root.screenName) return Hyprland.monitors.values[i];
        }
        return null;
    }
    readonly property var activeWs: hyprMonitor ? hyprMonitor.activeWorkspace : null
    readonly property var wsToplevels: activeWs ? activeWs.toplevels.values : []
    readonly property var focusedHere: {
        for (var i = 0; i < wsToplevels.length; i++) {
            if (wsToplevels[i].activated) return wsToplevels[i];
        }
        return wsToplevels.length > 0 ? wsToplevels[wsToplevels.length - 1] : null;
    }
    readonly property string title: focusedHere ? focusedHere.title : "Desktop"

    // Strips the redundant " - AppName" / " — AppName" branding suffix
    // browsers and editors like to append, so the workspace/document name
    // is what's left to (potentially) get elided. Full, unshortened title
    // is still always available via the tooltip.
    readonly property var _brandingSuffix: /\s+[-—|]\s+(Mozilla Firefox|Firefox|Google Chrome|Chromium|Brave|Zen(?: Browser)?|Visual Studio Code|Code(?:\s*-\s*OSS)?)\s*$/i
    readonly property string displayTitle: root.title.replace(root._brandingSuffix, "")

    onTitleChanged: popAnim.restart()

    idleColor: Theme.alpha(Theme.surface0, 0.55)
    horizontalPadding: 10
    tooltipText: root.title

    SequentialAnimation {
        id: popAnim
        NumberAnimation { target: label; property: "scale"; to: 0.94; duration: 90; easing.type: Easing.OutCubic }
        NumberAnimation { target: label; property: "scale"; to: 1.0; duration: 180; easing.type: Theme.easeOutBack }
    }

    Text {
        id: label
        font.family: Theme.fontFamily
        font.pixelSize: 11
        font.weight: Font.DemiBold
        color: Theme.subtext1
        text: root.displayTitle
        elide: Text.ElideRight
        maximumLineCount: 1
        Layout.maximumWidth: 275
    }
}
