import QtQuick
import QtQuick.Layouts
import Quickshell
import "../"

Pill {
    id: root
    horizontalPadding: 8

    readonly property string kind: SysStats.netKind
    readonly property string label: kind === "ethernet"
        ? "Ethernet"
        : (kind === "wifi" ? SysStats.netName : "offline")
    readonly property string glyph: kind === "ethernet"
        ? "󰲝"
        : (kind === "wifi" ? "" : "")
    readonly property color statusColor: kind === "offline" ? Theme.red : Theme.subtext1

    onClicked: Quickshell.execDetached(["kitty", "-e", "nmtui"])

    tooltipText: kind === "offline"
        ? "Not connected"
        : SysStats.netIface + (SysStats.netAddr ? " — " + SysStats.netAddr : "")

    Text {
        font.family: Theme.iconFontFamily
        font.pixelSize: 12
        text: root.glyph
        color: root.statusColor
        Behavior on color { ColorAnimation { duration: Theme.animMed } }
    }

    Text {
        font.family: Theme.fontFamily
        font.pixelSize: 11
        color: Theme.subtext1
        text: root.label
        elide: Text.ElideRight
        Layout.maximumWidth: 100
    }
}
