import QtQuick
import "../"

Pill {
    id: root
    interactive: false
    horizontalPadding: 8

    readonly property real temp: SysStats.cpuTempC
    readonly property color tempColor: temp < 60
        ? Theme.mix(Theme.teal, Theme.yellow, Math.max(0, temp - 45) / 15)
        : Theme.mix(Theme.yellow, Theme.red, Math.min(1, (temp - 60) / 25))

    tooltipText: "CPU package temperature"

    Text {
        font.family: Theme.iconFontFamily
        font.pixelSize: 12
        text: ""
        color: root.tempColor
        Behavior on color { ColorAnimation { duration: Theme.animSlow } }
    }

    Text {
        font.family: Theme.fontFamily
        font.pixelSize: 11
        font.features: ({ "tnum": 1 })
        color: Theme.subtext1
        text: Math.round(root.temp) + "°"
    }
}
