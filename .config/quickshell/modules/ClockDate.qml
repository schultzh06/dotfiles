import QtQuick
import Quickshell
import "../"

Pill {
    id: root
    interactive: false
    horizontalPadding: 4

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    tooltipText: Qt.formatDateTime(clock.date, "dddd, MMMM d yyyy")

    Text {
        font.family: Theme.fontFamily
        font.pixelSize: 11
        color: Theme.subtext1
        text: Qt.formatDateTime(clock.date, "ddd MMM d")
    }
}
