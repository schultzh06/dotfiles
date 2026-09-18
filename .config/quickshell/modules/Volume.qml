import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "../"

Pill {
    id: root
    horizontalPadding: 8

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool ready: sink !== null && sink.audio !== null
    readonly property real volume: ready ? sink.audio.volume : 0
    readonly property bool muted: ready && sink.audio.muted
    readonly property int pct: Math.round(volume * 100)

    readonly property string sinkName: ready && sink.name ? sink.name : ""
    readonly property bool isBluetooth: sinkName.startsWith("bluez_output")
    readonly property bool isInternal:  sinkName.startsWith("alsa_output.pci")

    readonly property string iconGlyph: {
        if (!root.ready)      return "\uf026";   // your no-sink glyph
        if (root.muted)       return "\uf026";   // your mute glyph
        if (root.isBluetooth) return "\uf293";   // bluetooth
        if (root.pct < 33)    return "\uf027";
        if (root.pct < 66)    return "\uf027";
        return "\uf028";
    }

    PwObjectTracker { objects: [root.sink] }

    tooltipText: ready ? (sink.description || sink.nickname || sink.name) : "No audio sink"

    onClicked: Quickshell.execDetached(["pavucontrol"])
    onWheelMoved: (delta) => {
        if (!root.ready) return;
        var step = 0.05;
        var next = root.volume + (delta > 0 ? step : -step);
        root.sink.audio.volume = Math.max(0, Math.min(1, next));
    }

    Text {
        id: icon
        font.family: Theme.iconFontFamily
        font.pixelSize: 12
        text: root.iconGlyph
        color: root.muted ? Theme.overlay0 : Theme.subtext1
        Behavior on color { ColorAnimation { duration: Theme.animMed } }

        SequentialAnimation {
            id: mutePulse
            NumberAnimation { target: icon; property: "scale"; to: 1.3; duration: 110 }
            NumberAnimation { target: icon; property: "scale"; to: 1.0; duration: 160; easing.type: Theme.easeOutBack }
        }
        Connections {
            target: root
            function onMutedChanged() { mutePulse.restart(); }
            function onSinkNameChanged() { mutePulse.restart(); }
        }
    }

    Rectangle {
        width: 3
        height: 14
        radius: 1.5
        color: Theme.surface1

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            radius: 1.5
            color: root.muted ? Theme.overlay0 : Theme.accent
            height: parent.height * (root.muted ? 0 : root.pct / 100)
            Behavior on height { NumberAnimation { duration: Theme.animMed; easing.type: Theme.easeOutExpo } }
        }
    }

    Text {
        font.family: Theme.fontFamily
        font.pixelSize: 11
        font.features: ({ "tnum": 1 })
        color: Theme.subtext1
        text: root.muted ? "Muted" : root.pct + "%"
    }
}
