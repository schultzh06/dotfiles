import QtQuick
import Quickshell
import "../"

Pill {
    id: root
    interactive: false
    horizontalPadding: 11

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    tooltipText: Qt.formatDateTime(clock.date, "dddd, MMMM d yyyy — hh:mm")

    Text {
        id: label
        font.family: Theme.fontFamily
        font.pixelSize: 12
        font.weight: Font.DemiBold
        font.features: ({ "tnum": 1 })
        color: Theme.text
        text: Qt.formatDateTime(clock.date, "hh:mm")
    }

    SequentialAnimation {
        id: tick
        NumberAnimation { target: label; property: "scale"; to: 1.12; duration: 120; easing.type: Easing.OutCubic }
        NumberAnimation { target: label; property: "scale"; to: 1.0; duration: 220; easing.type: Theme.easeOutBack }
    }
    Connections {
        target: clock
        function onDateChanged() { tick.restart(); }
    }
}
