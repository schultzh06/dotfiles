import QtQuick
import Quickshell
import Quickshell.Widgets
import "../"

// One dock slot. Sizing (width/height/scale) is driven entirely by the
// parent Dock's magnification math via the `scale` property -- this
// component just renders + launches/focuses/quits.
Item {
    id: root
    required property var entry // { pinned, pinId, desktopEntry, name, icon, appIdKey, execCommand, toplevels }
    property real magnify: 1.0

    readonly property var desktopEntry: entry.desktopEntry
    readonly property var toplevels: entry.toplevels || []
    readonly property bool running: toplevels.length > 0
    readonly property string displayIcon: {
        if (entry.icon) return Quickshell.iconPath(entry.icon, true);
        if (entry.appIdKey) return Quickshell.iconPath(entry.appIdKey, true);
        return "";
    }

    property int cycleIndex: 0

    anchors.bottom: parent.bottom
    width: Theme.dockIconSize * magnify
    height: Theme.dockIconSize * magnify + 14

    // No overshoot here on purpose: magnify already tracks the cursor
    // continuously and smoothly, so an overshooting curve would re-fire on
    // every tiny step as the mouse moves and read as jitter rather than a
    // single deliberate pop (that's reserved for onEntered/onExited-style
    // discrete jumps elsewhere, not this continuously-driven value).
    Behavior on width { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
    Behavior on height { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

    // Targets a transform, not iconVisual.y directly -- iconVisual is
    // anchored (anchors.bottom below), and animating an anchored item's own
    // y fights the anchor's binding on that same property: it "wins" the
    // first time, then leaves y stuck wherever the animation last set it
    // (0, i.e. the top of the parent) once the anchor binding is broken,
    // silently killing the bounce after that. A transform sits outside the
    // anchor system entirely, so it can't conflict with it.
    SequentialAnimation {
        id: bounce
        NumberAnimation { target: bounceTranslate; property: "y"; to: -16; duration: 160; easing.type: Easing.OutQuad }
        NumberAnimation { target: bounceTranslate; property: "y"; to: 0; duration: 260; easing.type: Easing.OutBounce }
    }

    Item {
        id: iconVisual
        width: root.width
        height: Theme.dockIconSize * root.magnify
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        transform: Translate { id: bounceTranslate }

        Rectangle {
            visible: root.displayIcon.length === 0
            anchors.fill: parent
            radius: 10
            color: Theme.surface1
            Text {
                anchors.centerIn: parent
                text: (entry.name || entry.appIdKey || "?").charAt(0).toUpperCase()
                color: Theme.subtext1
                font.family: Theme.fontFamily
                font.pixelSize: parent.height * 0.4
                font.bold: true
            }
        }

        IconImage {
            visible: root.displayIcon.length > 0
            anchors.fill: parent
            source: root.displayIcon
            smooth: true
        }
    }

    Row {
        anchors.top: iconVisual.bottom
        anchors.topMargin: 3
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 3
        Repeater {
            model: Math.min(root.toplevels.length, 3)
            Rectangle {
                width: 4; height: 4; radius: 2
                color: Theme.accent
            }
        }
    }

    // Always launches a fresh instance regardless of whether one is
    // already running -- middle-click and the context menu's "New Window"
    // both want this unconditional behavior, unlike primaryAction() below
    // which activates/cycles existing windows when there are any.
    function launchNew() {
        if (entry.execCommand) {
            // Explicit workingDirectory, not left to inherit whatever cwd
            // quickshell itself happened to be started from (that's what
            // caused every launch to open in ~/.config/quickshell after a
            // manual `quickshell -p .../shell.qml` from that directory --
            // child processes inherit their parent's cwd by default).
            Quickshell.execDetached({ command: entry.execCommand, workingDirectory: Quickshell.env("HOME") });
            bounce.start();
        } else if (desktopEntry) {
            desktopEntry.execute();
            bounce.start();
        }
    }

    // Hyprland's own toplevel objects don't expose activate()/close()
    // themselves -- those live on the generic wlr-foreign-toplevel-
    // management object each one wraps, reachable via `.wayland`.
    function primaryAction() {
        // Some pins (e.g. Yazi) want a fresh instance on every click rather
        // than focusing/cycling whatever's already open -- a "quick tool"
        // you generally want at your current directory, not an old one.
        if (!running || entry.alwaysNew) {
            launchNew();
            return;
        }
        // A toplevel can be "running" (present in this list) with a null
        // `.wayland` -- Dock.qml's rebuildEntries() deliberately keeps a
        // window grouped by its `lastIpcObject.class` even before its
        // foreign-toplevel handle has resolved, so it doesn't miss a
        // just-opened window for a whole poll tick. Cycling straight to
        // that one and bailing when `handle` is null used to just do
        // nothing on click, with no fallback -- try every window in the
        // list before giving up, and only then fall back to a fresh
        // instance instead of silently swallowing the click.
        for (var i = 0; i < toplevels.length; i++) {
            cycleIndex = (cycleIndex + 1) % toplevels.length;
            var handle = toplevels[cycleIndex].wayland;
            if (handle) { handle.activate(); return; }
        }
        launchNew();
    }
}
