import QtQuick
import Quickshell.Services.UPower
import "../"

Pill {
    id: root
    interactive: false
    horizontalPadding: 8

    readonly property var dev: UPower.displayDevice
    readonly property bool present: dev !== null && dev.ready && dev.isLaptopBattery
    readonly property real pct: present ? dev.percentage * 100 : 0
    readonly property bool charging: present
        && (dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.PendingCharge)
    readonly property bool isCritical: present && !charging && pct <= 10
    readonly property bool isWarning: present && !charging && pct <= 20
    readonly property bool pulsing: charging || isCritical

    visible: present

    readonly property color levelColor: charging
        ? Theme.green
        : (isCritical ? Theme.red : (isWarning ? Theme.yellow : Theme.subtext1))

    readonly property string glyph: {
        if (root.charging) return "";
        if (root.pct > 90) return "";
        if (root.pct > 65) return "";
        if (root.pct > 35) return "";
        if (root.pct > 10) return "";
        return "";
    }

    function formatDuration(seconds) {
        var h = Math.floor(seconds / 3600);
        var m = Math.floor((seconds % 3600) / 60);
        return h > 0 ? (h + "h " + m + "m") : (m + "m");
    }

    tooltipText: {
        if (!present) return "";
        if (dev.state === UPowerDeviceState.FullyCharged) return "Fully charged";
        if (charging && dev.timeToFull > 0) return formatDuration(dev.timeToFull) + " until full";
        if (!charging && dev.timeToEmpty > 0) return formatDuration(dev.timeToEmpty) + " remaining";
        return "";
    }

    Text {
        id: icon
        font.family: Theme.iconFontFamily
        font.pixelSize: 12
        text: root.glyph
        color: root.levelColor
        Behavior on color { ColorAnimation { duration: Theme.animSlow } }

        SequentialAnimation {
            id: pulse
            loops: Animation.Infinite
            NumberAnimation { target: icon; property: "opacity"; to: 0.4; duration: 600; easing.type: Easing.InOutQuad }
            NumberAnimation { target: icon; property: "opacity"; to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
        }
        Connections {
            target: root
            function onPulsingChanged() {
                if (root.pulsing) pulse.start();
                else { pulse.stop(); icon.opacity = 1.0; }
            }
        }
    }

    Text {
        font.family: Theme.fontFamily
        font.pixelSize: 11
        font.features: ({ "tnum": 1 })
        color: Theme.subtext1
        text: Math.round(root.pct) + "%"
    }
}
