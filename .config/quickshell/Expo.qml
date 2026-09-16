import QtQuick
import Quickshell
import Quickshell.Hyprland
import "./modules" as Modules

// Workspace overview ("expo mode"): every workspace on this monitor as a
// scaled-down replica of the monitor itself, windows drawn at their real
// on-screen position and size (like Cinnamon's Expo) rather than a uniform
// icon grid -- so a workspace with a lot of windows just shows a busier
// mini-desktop instead of blowing up the layout. Cards are laid out in a
// centered, wrapping grid. Instantiated once per screen (see shell.qml),
// same split as Bar/Dock -- toggled all together via the shared ExpoState
// singleton, but each instance only ever renders its own monitor's
// workspaces (Hyprland workspaces belong to one monitor at a time, there's
// nothing to merge).
Item {
    id: root
    required property var screen
    readonly property string screenName: screen ? screen.name : ""

    readonly property var hyprMonitor: {
        for (var i = 0; i < Hyprland.monitors.values.length; i++) {
            if (Hyprland.monitors.values[i].name === root.screenName) return Hyprland.monitors.values[i];
        }
        return null;
    }

    property var workspaceGroups: []
    // Signature of the last-committed workspaceGroups, so rebuildGroups()
    // can skip reassigning it when nothing actually changed -- same trick
    // as Dock.qml's _entriesSignature, and for the same reason: Dock's own
    // 400ms poll timer calls Hyprland.refreshToplevels() unconditionally,
    // which re-fires Hyprland.toplevels.valuesChanged (and so this file's
    // Connections below) even when no window actually changed. Without
    // this, that meant reassigning workspaceGroups every 400ms while the
    // overview was open, which tears down and recreates every card/tile
    // delegate -- restarting every ScreencopyView's capture from scratch
    // each time, a real chunk of the reported lag.
    property string _groupsSignature: ""

    // Bin-packs workspaceGroups into rows that fit the available width --
    // QtQuick's Flow can wrap, but always left-packs each row, which reads
    // as "stuck in the corner" the moment wrapping kicks in; grouping into
    // rows ourselves lets each row (and the block as a whole) actually
    // center, via the Item/Row pairing below.
    readonly property var workspaceRows: {
        var rows = [];
        var current = [];
        var currentWidth = 0;
        var maxW = Math.max(1, root.width - 160);
        for (var i = 0; i < workspaceGroups.length; i++) {
            var g = workspaceGroups[i];
            var addWidth = g.cardWidth + (current.length > 0 ? Theme.expoWorkspaceSpacing : 0);
            if (current.length > 0 && currentWidth + addWidth > maxW) {
                rows.push(current);
                current = [];
                currentWidth = 0;
                addWidth = g.cardWidth;
            }
            current.push(g);
            currentWidth += addWidth;
        }
        if (current.length > 0) rows.push(current);
        return rows;
    }

    // Every row-Item below shares this one width (the widest actual row)
    // so the whole block's own anchors.centerIn is tight to real content,
    // and every row -- including a shorter trailing one -- centers under
    // the same midpoint rather than under the (possibly wider) wrap cap.
    readonly property int gridContentWidth: {
        var maxRowW = 0;
        for (var i = 0; i < workspaceRows.length; i++) {
            var w = 0;
            for (var j = 0; j < workspaceRows[i].length; j++) {
                w += workspaceRows[i][j].cardWidth + (j > 0 ? Theme.expoWorkspaceSpacing : 0);
            }
            if (w > maxRowW) maxRowW = w;
        }
        return Math.max(1, maxRowW);
    }

    // Rebuilt explicitly off both `values` signals rather than a plain
    // reactive binding -- Dock.qml's rebuildEntries() hit the same need
    // (see its own Connections to Hyprland.toplevels/DockPins) and a plain
    // binding on nested `.values` reads wasn't trusted there either.
    function rebuildGroups() {
        if (!root.hyprMonitor) { root.workspaceGroups = []; return; }

        // Same physical/logical split as Dock.qml's updateOverlap(): the
        // monitor's own width/height are physical pixels, but window
        // geometry (lastIpcObject.at/size) and the monitor's x/y layout
        // offset are already logical -- divide by scale once here so every
        // window's position/size below lands in the same logical space.
        var monW = root.hyprMonitor.width / root.hyprMonitor.scale;
        var monH = root.hyprMonitor.height / root.hyprMonitor.scale;
        var previewScale = Theme.expoPreviewWidth / monW;
        var previewWidth = Theme.expoPreviewWidth;
        var previewHeight = monH * previewScale;
        var cardWidth = previewWidth + Theme.expoWorkspacePadding * 2;
        var cardHeight = previewHeight + Theme.expoWorkspacePadding * 2 + 26 + 10;

        var list = Hyprland.workspaces.values;
        var groups = [];
        for (var i = 0; i < list.length; i++) {
            var w = list[i];
            if (!w.monitor || w.monitor.name !== root.screenName) continue;

            var toplevels = w.toplevels.values;
            var windows = [];
            for (var j = 0; j < toplevels.length; j++) {
                var t = toplevels[j];
                var geo = t.lastIpcObject;
                if (!geo || !geo.at || !geo.size) continue;
                windows.push({
                    toplevel: t,
                    floating: !!geo.floating,
                    x: (geo.at[0] - root.hyprMonitor.x) * previewScale,
                    y: (geo.at[1] - root.hyprMonitor.y) * previewScale,
                    width: Math.max(3, geo.size[0] * previewScale),
                    height: Math.max(3, geo.size[1] * previewScale)
                });
            }
            // Floating windows drawn last so they land on top of tiled
            // ones, same as they'd actually appear on screen.
            windows.sort(function (a, b) { return (a.floating ? 1 : 0) - (b.floating ? 1 : 0); });

            groups.push({
                id: w.id,
                name: w.name || String(w.id),
                active: root.hyprMonitor.activeWorkspace === w,
                windows: windows,
                previewWidth: previewWidth,
                previewHeight: previewHeight,
                cardWidth: cardWidth,
                cardHeight: cardHeight
            });
        }
        groups.sort(function (a, b) { return a.id - b.id; });

        // Toplevel objects are the same long-lived HyprlandToplevel
        // instances across calls (see Dock.qml's rebuildEntries for the
        // same observation), so their default toString() is stable per-
        // object -- combined with rounded geometry, enough to detect "the
        // same windows in the same places" without a dedicated id field.
        var sigParts = [];
        for (var g = 0; g < groups.length; g++) {
            var grp = groups[g];
            var winSig = grp.windows.map(function (win) {
                return win.toplevel + "@" + Math.round(win.x) + "," + Math.round(win.y)
                    + "," + Math.round(win.width) + "," + Math.round(win.height);
            }).join(",");
            sigParts.push(grp.id + ":" + grp.active + ":" + winSig);
        }
        var signature = sigParts.join(";");
        if (signature === root._groupsSignature) return;
        root._groupsSignature = signature;
        root.workspaceGroups = groups;
    }

    Connections {
        target: Hyprland.toplevels
        function onValuesChanged() { root.rebuildGroups(); }
    }
    Connections {
        target: Hyprland.workspaces
        function onValuesChanged() { root.rebuildGroups(); }
    }
    Connections {
        // Hyprland.monitors populates asynchronously and, at startup,
        // lands *after* the first few toplevels/workspaces events --
        // rebuildGroups() bailed out empty every one of those times (no
        // hyprMonitor yet) and, with no hook on monitors itself, nothing
        // ever asked it to try again once monitors actually arrived. Only
        // a later toplevel/workspace change (opening/closing some window)
        // would have accidentally papered over it.
        target: Hyprland.monitors
        function onValuesChanged() { root.rebuildGroups(); }
    }
    // Lets Keys.onPressed below actually receive events -- the window-level
    // WlrLayershell.keyboardFocus (see shell.qml) only gets the compositor
    // to hand this surface keyboard focus; something inside still needs
    // QML-level active focus to turn that into delivered key events.
    focus: true

    Connections {
        target: ExpoState
        function onShownChanged() {
            if (ExpoState.shown) {
                // Belt and suspenders on top of the Connections above:
                // whatever the cause, don't show a stale or empty
                // overview -- rebuild fresh every time the overlay opens.
                root.rebuildGroups();
                root.forceActiveFocus();
            } else {
                // Tear every tile (and its ScreencopyView) down the
                // instant the overview closes, rather than leaving the
                // _groupsSignature check above keep them cached in the
                // background for next time. This is a real crash fix, not
                // just cleanup: a cached tile still holds a live
                // `captureSource` pointed at its window even while
                // hidden, and if that window closes later -- at any point
                // while Expo just happens to be closed, not necessarily
                // related to it at all from the user's perspective --
                // tearing down that now-dangling reference triggered a
                // Wayland protocol error ("error in client
                // communication") that took the whole shell process down
                // with it (confirmed in the compositor log both times
                // this happened). Rebuilding from scratch on every open
                // is cheap; a lingering capture reference across window
                // closes is not safe.
                root._groupsSignature = "";
                root.workspaceGroups = [];
            }
        }
    }
    Component.onCompleted: root.rebuildGroups()

    // Number-key-to-workspace: press 1-9 (or 0, matching hyprland.lua's own
    // mainMod+[0-9] convention where 0 maps to workspace 10) to jump
    // straight there and dismiss, without having to click a card. Global
    // workspace numbers, not per-monitor -- same `hl.dsp.focus` dispatch
    // the cards' own click handlers already use, so this always lands on
    // the right monitor regardless of which screen's Expo instance caught
    // the keypress.
    Keys.onPressed: (event) => {
        if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9) {
            var n = event.key === Qt.Key_0 ? 10 : (event.key - Qt.Key_0);
            Hyprland.dispatch("hl.dsp.focus({ workspace = " + n + " })");
            ExpoState.hide();
            event.accepted = true;
        }
    }

    // Scrim -- click anywhere empty to dismiss without picking a window.
    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.crust, Theme.expoScrimAlpha)

        MouseArea {
            anchors.fill: parent
            onClicked: ExpoState.hide()
        }
    }

    Column {
        id: overview
        anchors.centerIn: parent
        spacing: Theme.expoWorkspaceSpacing

        Repeater {
            model: root.workspaceRows
            delegate: Item {
                id: rowItem
                required property var modelData
                width: root.gridContentWidth
                height: {
                    var h = 0;
                    for (var i = 0; i < modelData.length; i++) h = Math.max(h, modelData[i].cardHeight);
                    return h;
                }

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.expoWorkspaceSpacing

                    Repeater {
                        model: rowItem.modelData
                        delegate: Column {
                            id: card
                            required property var modelData
                            spacing: 10
                            width: modelData.cardWidth

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: Math.min(cardLabel.implicitWidth + 20, card.width)
                                height: 26
                                radius: 13
                                color: card.modelData.active ? Theme.lavender : Theme.alpha(Theme.surface0, 0.8)

                                Text {
                                    id: cardLabel
                                    anchors.centerIn: parent
                                    width: card.width - 20
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    text: card.modelData.name
                                    color: card.modelData.active ? Theme.base : Theme.subtext1
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    font.bold: card.modelData.active
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Hyprland.dispatch("hl.dsp.focus({ workspace = " + card.modelData.id + " })");
                                        ExpoState.hide();
                                    }
                                }
                            }

                            Rectangle {
                                width: card.modelData.cardWidth
                                height: card.modelData.cardHeight - 26 - 10
                                radius: 10
                                color: Theme.alpha(Theme.mantle, 0.85)
                                border.width: card.modelData.active ? 2 : 1
                                border.color: card.modelData.active ? Theme.lavender : Theme.alpha(Theme.subtext0, 0.25)

                                // Click on the card's own background (not a
                                // window) also jumps to that workspace --
                                // mirrors the label pill.
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        Hyprland.dispatch("hl.dsp.focus({ workspace = " + card.modelData.id + " })");
                                        ExpoState.hide();
                                    }
                                }

                                // The mini-desktop itself: windows below
                                // are positioned at their real on-screen
                                // coordinates scaled into this box, so it
                                // reads as a shrunken screenshot rather
                                // than an icon grid.
                                Item {
                                    id: desktop
                                    anchors.centerIn: parent
                                    width: card.modelData.previewWidth
                                    height: card.modelData.previewHeight
                                    clip: true

                                    Repeater {
                                        model: card.modelData.windows
                                        delegate: Modules.ExpoTile {
                                            required property var modelData
                                            x: modelData.x
                                            y: modelData.y
                                            width: modelData.width
                                            height: modelData.height
                                            toplevel: modelData.toplevel
                                        }
                                    }

                                    Text {
                                        visible: card.modelData.windows.length === 0
                                        anchors.centerIn: parent
                                        text: "Empty"
                                        color: Theme.overlay0
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
