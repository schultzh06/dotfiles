import QtQuick
import "../"

Pill {
    id: root
    interactive: false
    horizontalPadding: 8

    readonly property real pct: SysStats.cpuPercent
    readonly property color loadColor: pct < 55
        ? Theme.mix(Theme.subtext1, Theme.yellow, Math.max(0, pct - 25) / 30)
        : Theme.mix(Theme.yellow, Theme.red, Math.min(1, (pct - 55) / 30))

    tooltipText: "CPU usage: " + Math.round(pct) + "%"

    Text {
        font.family: Theme.iconFontFamily
        font.pixelSize: 12
        text: ""
        color: root.loadColor
        Behavior on color { ColorAnimation { duration: Theme.animSlow } }

        SequentialAnimation on scale {
            running: root.pct > 90
            loops: Animation.Infinite
            NumberAnimation { to: 1.25; duration: 380; easing.type: Easing.OutQuad }
            NumberAnimation { to: 1.0; duration: 380; easing.type: Easing.InQuad }
        }
    }

    Sparkline {
        width: 26
        height: 14
        values: SysStats.cpuHistory
        lineColor: root.loadColor
        fillColor: Theme.alpha(root.loadColor, 0.22)
    }

    Text {
        font.family: Theme.fontFamily
        font.pixelSize: 11
        font.features: ({ "tnum": 1 })
        color: Theme.subtext1
        text: Math.round(root.pct) + "%"
    }
}
