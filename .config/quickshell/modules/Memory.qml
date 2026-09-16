import QtQuick
import "../"

Pill {
    id: root
    interactive: false
    horizontalPadding: 8

    readonly property real pct: SysStats.memPercent
    readonly property color loadColor: pct < 55
        ? Theme.mix(Theme.subtext1, Theme.yellow, Math.max(0, pct - 35) / 30)
        : Theme.mix(Theme.yellow, Theme.red, Math.min(1, (pct - 55) / 35))

    tooltipText: SysStats.memUsedGB.toFixed(1) + " GB / " + SysStats.memTotalGB.toFixed(1) + " GB used"

    Text {
        font.family: Theme.iconFontFamily
        font.pixelSize: 12
        text: ""
        color: root.loadColor
        Behavior on color { ColorAnimation { duration: Theme.animSlow } }
    }

    Sparkline {
        width: 26
        height: 14
        values: SysStats.memHistory
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
