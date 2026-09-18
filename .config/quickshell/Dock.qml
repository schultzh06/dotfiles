import QtQuick
import Quickshell
import Quickshell.Hyprland
import "./modules" as Modules

// macOS-style dock: pinned apps + running apps, icon magnification that
// follows the cursor, and auto-hide that only kicks in once a window on the
// active workspace actually overlaps the dock's footprint (matching real
// macOS behavior, not a dumb always-hidden panel).
//
// Instantiated once per screen (see shell.qml) -- pinned state lives in the
// DockPins singleton so every monitor's dock stays in sync.
Item {
    id: root
    required property var screen
    readonly property string screenName: screen ? screen.name : ""

    property alias maskItem: restArea

    property var dockEntries: []
    // Signature of the last-committed dockEntries, so rebuildEntries()
    // below can skip reassigning it when nothing actually changed --
    // reassigning tears down and recreates every DockIcon delegate (a
    // plain JS-array model gets no finer-grained diffing), which would
    // silently invalidate previewAnchorItem/contextMenuAnchorItem (both
    // hold a reference to a specific delegate instance) on every 400ms
    // poll tick even when the dock's contents hadn't actually changed.
    property string _entriesSignature: ""
    property real trackMouseX: -1
    property bool hoveredZone: false
    property bool windowOverlaps: false
    // Grace period after the cursor leaves: keeps the dock up for a beat
    // instead of hiding the instant the mouse strays off it.
    property bool pendingHide: false
    // The right-click menu and hover preview are separate popup windows --
    // moving onto either takes the cursor out of the dock's own hit area
    // (hoveredZone would go false), so keep the dock up unconditionally
    // the whole time either is open rather than letting it hide out from
    // under them.
    readonly property bool shown: hoveredZone || !windowOverlaps || pendingHide || contextMenuEntry !== null || previewEntry !== null

    Timer {
        id: hideGraceTimer
        interval: 250
        onTriggered: root.pendingHide = false
    }
    onHoveredZoneChanged: {
        if (hoveredZone) {
            hideGraceTimer.stop();
            root.pendingHide = false;
        } else if (root.windowOverlaps) {
            root.pendingHide = true;
            hideGraceTimer.restart();
        }
    }

    property var contextMenuEntry: null
    property var contextMenuAnchorItem: null
    // Tracked separately by index (not just via contextMenuAnchorItem)
    // because it's what drives forcing that one icon to full magnification
    // while its menu is open -- see magnifyFor() -- so the user can always
    // tell which icon the open menu belongs to, even after the cursor has
    // moved off the dock entirely and onto the menu itself.
    property int contextMenuIndex: -1

    function closeMenu() {
        root.contextMenuEntry = null;
        root.contextMenuAnchorItem = null;
        root.contextMenuIndex = -1;
    }

    // Hover preview: shows a strip of live per-window thumbnails before
    // you click, for apps with open windows.
    //
    // hoveredIconIndex is the raw, live "which icon is the cursor over
    // right now" (-1 if none), updated unconditionally from every
    // onEntered/onPositionChanged -- QML's property system already
    // no-ops a reassignment to the same value, so there's no need to
    // hand-roll an "did it actually change" check here (an earlier
    // version did that manually and was the actual bug: it compared
    // against its own not-yet-updated value in a way that could get
    // stuck, so hovering a second icon after the first successful
    // preview silently stopped re-triggering anything).
    //
    // settledIconIndex only catches up to hoveredIconIndex after it's
    // held still for a beat (see the two timers below), and previewEntry/
    // previewAnchorItem are plain derived bindings off settledIconIndex --
    // not imperatively assigned anywhere -- so they can never go stale or
    // get stuck: they always reflect whatever settledIconIndex currently
    // is, recomputed automatically.
    property int hoveredIconIndex: -1
    property int settledIconIndex: -1
    // Reference count, not a plain bool: the popup's background area and
    // each card's own MouseArea overlap (a card sits on top of the
    // background), so moving from the background onto a card delivers
    // the new area's enter and the old one's exit as two independent
    // events with no guaranteed order. With a plain "last write wins"
    // bool, whichever happened to arrive second decided the outcome --
    // observed in practice as enter-then-exit, which left it stuck on
    // "not hovered" while the cursor was still very much on the popup,
    // and the close timer fired out from under it. A count that every
    // area increments/decrements nets out to the same right answer
    // (still > 0) regardless of which order the two events land in.
    property int previewPopupHoverCount: 0
    readonly property bool previewPopupHovered: previewPopupHoverCount > 0

    readonly property var settledIcon: root.settledIconIndex >= 0 ? iconRepeater.itemAt(root.settledIconIndex) : null
    readonly property var previewEntry: {
        var icon = root.settledIcon;
        if (!icon || !icon.entry || icon.entry.isLauncher || icon.toplevels.length === 0) return null;
        return icon.entry;
    }
    readonly property var previewAnchorItem: root.previewEntry ? root.settledIcon : null

    function closePreview() {
        previewShowTimer.stop();
        previewHideTimer.stop();
        root.hoveredIconIndex = -1;
        root.settledIconIndex = -1;
        root.previewPopupHoverCount = 0;
    }

    // Called by DockPreview.qml's own hover areas (background + each
    // card) so moving the cursor from the icon up onto the popup (which
    // briefly leaves the dock's restArea) doesn't get treated as "the
    // user looked away".
    function notePreviewHover(hovered) {
        root.previewPopupHoverCount = Math.max(0, root.previewPopupHoverCount + (hovered ? 1 : -1));
        if (root.previewPopupHovered) previewHideTimer.stop();
        else if (root.hoveredIconIndex < 0) previewHideTimer.restart();
    }

    Timer {
        id: previewShowTimer
        interval: 450
        onTriggered: root.settledIconIndex = root.hoveredIconIndex
    }
    Timer {
        id: previewHideTimer
        interval: 300
        onTriggered: root.settledIconIndex = -1
    }
    onHoveredIconIndexChanged: {
        previewShowTimer.stop();
        previewHideTimer.stop();
        if (hoveredIconIndex >= 0) {
            // Switching straight from one icon to another while a preview
            // is already up should feel like browsing, not like opening a
            // fresh preview each time -- only the very first trigger (from
            // no preview at all) needs the settle delay, so scrubbing
            // across icons on the way to one you actually want doesn't
            // flash a preview for each one along the way.
            if (root.settledIconIndex >= 0) root.settledIconIndex = hoveredIconIndex;
            else previewShowTimer.restart();
        } else if (!root.previewPopupHovered) {
            previewHideTimer.restart();
        }
    }

    // Shared by the click handler and hover tracking below: exact
    // geometry hit-test against each icon's real current position (not a
    // fixed resting-grid formula -- see onClicked's own comment for why
    // that matters once any icon is magnified).
    function iconIndexAt(x, y) {
        var pt = mouseArea.mapToItem(iconRow, x, y);
        for (var i = 0; i < iconRepeater.count; i++) {
            var candidate = iconRepeater.itemAt(i);
            if (candidate && pt.x >= candidate.x && pt.x < candidate.x + candidate.width) return i;
        }
        return -1;
    }

    readonly property var hyprMonitor: {
        for (var i = 0; i < Hyprland.monitors.values.length; i++) {
            if (Hyprland.monitors.values[i].name === root.screenName) return Hyprland.monitors.values[i];
        }
        return null;
    }

    function desktopEntryFor(id) {
        return DesktopEntries.byId(id + ".desktop")
            || DesktopEntries.heuristicLookup(id)
            || null;
    }

    function pinApp(appIdKey) { DockPins.pin(appIdKey); }
    function unpinApp(pinId) { DockPins.unpin(pinId); }

    // Some windows share a class with others that conceptually belong to a
    // different group, or vice versa:
    // - "kitty-float" (mod+shift+Q, a plain floating terminal) should just
    //   fold into the regular kitty group, not get its own icon.
    // - Yazi run inside any kitty variant sets its window title to
    //   "Yazi: <path>" regardless of class -- catch that and group it with
    //   the dedicated Yazi entry even when it wasn't launched via the
    //   yazi-float keybind.
    function effectiveGroupKey(rawClass, title) {
        var c = (rawClass || "").toLowerCase();
        var isYazi = title && /^yazi:/i.test(title);
        if (isYazi && (c === "kitty" || c === "kitty-float" || c === "yazi-float")) return "yazi-float";
        if (c === "kitty-float") return "kitty";
        return c;
    }

    function rebuildEntries() {
        var running = {};
        var list = Hyprland.toplevels.values;
        for (var i = 0; i < list.length; i++) {
            var t = list[i];
            var rawClass = (t.wayland && t.wayland.appId) ? t.wayland.appId
                : ((t.lastIpcObject && t.lastIpcObject.class) || "");
            if (!rawClass) continue;
            var key = root.effectiveGroupKey(rawClass, t.title);
            if (!key) continue;
            if (!running[key]) running[key] = [];
            running[key].push(t);
        }

        var pinnedApps = DockPins.pinnedApps;
        var entries = [];
        // Always-first, permanent launcher icon -- not a real app, never
        // has toplevels, so it rides the existing DockIcon/click machinery
        // for free (running is always false, so primaryAction() already
        // falls through to launchNew(), which already knows how to run
        // execCommand). isLauncher just tells the click handler and the
        // context menu to leave it alone. Reuses the exact toggle command
        // hyprland.lua's own menu keybind uses, so behavior matches.
        entries.push({
            pinned: false,
            pinId: null,
            isLauncher: true,
            desktopEntry: null,
            name: "Application Launcher",
            icon: "distributor-logo-archlinux",
            appIdKey: "__launcher__",
            execCommand: ["sh", "-c", "pkill wofi || wofi --show drun"],
            alwaysNew: true,
            toplevels: []
        });
        var used = {};
        for (var p = 0; p < pinnedApps.length; p++) {
            var pd = pinnedApps[p];
            var entry = pd.exec ? null : root.desktopEntryFor(pd.id);
            var matchKey = (pd.matchClass || pd.id).toLowerCase();
            var actualKey = null;
            for (var k in running) {
                var wmClass = entry && entry.startupClass ? entry.startupClass.toLowerCase() : "";
                if (k === matchKey || (wmClass && k === wmClass)) { actualKey = k; break; }
            }
            entries.push({
                pinned: true,
                pinId: pd.id,
                desktopEntry: entry,
                name: pd.name || (entry ? entry.name : pd.id),
                icon: pd.icon || (entry ? entry.icon : ""),
                appIdKey: actualKey || matchKey,
                execCommand: pd.exec || null,
                alwaysNew: pd.alwaysNew === true,
                toplevels: actualKey ? running[actualKey] : []
            });
            if (actualKey) used[actualKey] = true;
        }
        for (var k2 in running) {
            if (used[k2]) continue;
            var e2 = root.desktopEntryFor(k2);
            entries.push({
                pinned: false,
                pinId: null,
                desktopEntry: e2,
                name: e2 ? e2.name : k2,
                icon: e2 ? e2.icon : "",
                appIdKey: k2,
                execCommand: null,
                alwaysNew: false,
                toplevels: running[k2]
            });
        }
        // Cheap identity-based signature: toplevel objects are the same
        // long-lived HyprlandToplevel instances across calls (Hyprland
        // doesn't recreate them), so their default toString() is stable
        // per-object and differs between distinct objects -- enough to
        // detect "the same windows in the same apps" without needing a
        // dedicated stable id field.
        var sigParts = [];
        for (var e = 0; e < entries.length; e++) {
            var en = entries[e];
            sigParts.push(en.appIdKey + "|" + en.pinned + "|" + en.icon + "|" + en.name + "|" + en.toplevels.join(","));
        }
        var signature = sigParts.join(";;");
        if (signature === root._entriesSignature) return;
        root._entriesSignature = signature;
        root.dockEntries = entries;
    }

    function rectsOverlap(ax, ay, aw, ah, bx, by, bw, bh) {
        return ax < bx + bw && ax + aw > bx && ay < by + bh && ay + ah > by;
    }

    function updateOverlap() {
        if (!hyprMonitor || !hyprMonitor.activeWorkspace) { root.windowOverlaps = false; return; }
        // HyprlandMonitor.width/height mirror hyprctl's raw (physical)
        // monitor resolution, but window geometry from lastIpcObject.at/
        // size is in logical (scale-adjusted) compositor-layout space --
        // same space monitor x/y offsets already use. On a 1:1 scale
        // monitor (like DP-2) those are identical and this bug is
        // invisible; on eDP-1 (scale ~1.667) skipping the conversion put
        // the comparison rect entirely outside where windows actually
        // report their position, so it could never "overlap" anything.
        var monW = hyprMonitor.width / hyprMonitor.scale;
        var monH = hyprMonitor.height / hyprMonitor.scale;

        // Always checked against the dock's full shown-state footprint,
        // never the current (possibly shrunk-to-a-strip) hit area -- this
        // decides whether the dock *would* have something behind it, which
        // must not depend on whether it's currently shown or hidden.
        var dockW = root.restWidth;
        var dockH = root.hitHeight + Theme.dockMarginBottom;
        var dockX = hyprMonitor.x + (monW - dockW) / 2;
        var dockY = hyprMonitor.y + monH - dockH;

        var list = hyprMonitor.activeWorkspace.toplevels.values;
        for (var i = 0; i < list.length; i++) {
            var geo = list[i].lastIpcObject;
            if (!geo || !geo.at || !geo.size) continue;
            if (root.rectsOverlap(geo.at[0], geo.at[1], geo.size[0], geo.size[1], dockX, dockY, dockW, dockH)) {
                root.windowOverlaps = true;
                return;
            }
        }
        root.windowOverlaps = false;
    }

    Connections {
        target: Hyprland.toplevels
        function onValuesChanged() { root.rebuildEntries(); }
    }
    Connections {
        target: DockPins
        function onPinnedAppsChanged() { root.rebuildEntries(); }
    }
    Component.onCompleted: root.rebuildEntries()

    // Shape of the falloff only (0..1), not the magnification itself --
    // used as a weight for distributing a fixed growth budget below.
    function influenceWeight(distance) {
        if (distance >= Theme.dockInfluenceRadius) return 0;
        var t = 1 - distance / Theme.dockInfluenceRadius;
        return t * t;
    }

    // Total extra width (beyond resting size) available to hand out across
    // the whole row at any one time. Handing out a *fixed* budget rather
    // than letting each icon grow independently means the row's total
    // content width never changes as the cursor moves -- only how that
    // fixed amount of growth is distributed across nearby icons does. That
    // keeps the whole row (which Row centers as a unit) from continuously
    // resizing/recentering while scrubbing across it, which is what reads
    // as "bouncy". One icon isolated with no neighbors nearby still gets
    // the full budget, i.e. still reaches Theme.dockMaxScale exactly.
    readonly property real magnifyBudget: Theme.dockIconSize * (Theme.dockMaxScale - 1)

    function magnifyFor(index) {
        if (index === root.contextMenuIndex) return Theme.dockMaxScale;
        if (root.trackMouseX < 0) return 1.0;
        var n = dockEntries.length;
        var weight = 0;
        var sumWeights = 0;
        for (var i = 0; i < n; i++) {
            var restCenter = i * (Theme.dockIconSize + Theme.dockIconSpacing) + Theme.dockIconSize / 2;
            var w = root.influenceWeight(Math.abs(root.trackMouseX - restCenter));
            if (i === index) weight = w;
            sumWeights += w;
        }
        if (sumWeights <= 0) return 1.0;
        return 1 + (root.magnifyBudget * weight / sumWeights) / Theme.dockIconSize;
    }

    // Constant by construction: resting row width plus the one fixed
    // growth budget above, regardless of where (or whether) the cursor is
    // hovering -- see magnifyFor().
    readonly property real hoveredRowWidth: {
        var n = dockEntries.length;
        return n * Theme.dockIconSize + Math.max(0, n - 1) * Theme.dockIconSpacing + root.magnifyBudget;
    }

    Timer {
        interval: 400
        running: true
        repeat: true
        triggeredOnStart: true
        // rebuildEntries() here (not just on Hyprland.toplevels.values
        // changing) matters: Hyprland creates a new toplevel's QML object
        // pre-emptively on the openwindow event, before its class/appId is
        // known -- that only gets filled in by this refreshToplevels()
        // call querying `hyprctl clients -j`, and it's filled in *on the
        // existing object* rather than by replacing the toplevels array, so
        // it never fires values-changed on its own. Without an explicit
        // rebuild here, a just-opened window's icon could stay stale
        // indefinitely, until some unrelated open/close happened to trigger
        // one. This bounds that lag to one tick instead.
        onTriggered: { Hyprland.refreshToplevels(); root.updateOverlap(); root.rebuildEntries(); }
    }

    readonly property int restWidth: Math.max(Theme.dockIconSize, dockEntries.length * Theme.dockIconSize
        + Math.max(0, dockEntries.length - 1) * Theme.dockIconSpacing) + Theme.dockPadding * 2
    // Fixed height sized for icons at their *resting* size only -- never
    // changes, so the background pill only ever moves (show/hide), never
    // resizes. Magnified icons overflow past its top edge, macOS-style,
    // rather than the pill growing to swallow them.
    readonly property int restHeight: Theme.dockIconSize + 24 + Theme.dockPadding
    // The interactive/hit area is taller than the pill itself -- it has to
    // cover the full height a magnified icon can reach so the overflowing
    // part stays hoverable/clickable, even though nothing is drawn there.
    readonly property int hitHeight: Math.round(Theme.dockIconSize * Theme.dockMaxScale) + 24 + Theme.dockPadding

    onShownChanged: if (!shown) { root.closeMenu(); root.closePreview(); }

    // Hit region: dock-sized while shown (so magnification/clicks work over
    // its full visual extent, overflow included), shrunk to a thin strip at
    // the very bottom edge while hidden so it isn't just eating a huge slab
    // of the screen -- that strip is what makes edge-hover reveal work.
    Item {
        id: restArea
        // Mirrors dockVisual's own width switch exactly (same condition,
        // same expression) so this item's left/right edges stay pinned to
        // dockVisual's at all times -- both are horizontalCenter-anchored
        // to the same parent, so matching widths keeps them edge-aligned.
        // This matters for two things: (1) the magnified row can otherwise
        // visually overhang past this hit area's old fixed restWidth,
        // making the outer icons impossible to hover/click; (2)
        // trackMouseX below assumes "mouse.x - Theme.dockPadding" lands in
        // iconRow's own coordinate frame, which is only true when this
        // item's left edge coincides with dockVisual/iconRow's -- true at
        // rest, but not during magnification when this stayed frozen at
        // restWidth while dockVisual grew and recentered around it.
        width: (root.hoveredZone || root.contextMenuIndex >= 0) ? (root.hoveredRowWidth + Theme.dockPadding * 2) : root.restWidth
        height: root.shown ? (root.hitHeight + Theme.dockMarginBottom) : Theme.dockRevealStripHeight
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom

        Behavior on height { NumberAnimation { duration: Theme.animFast } }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onEntered: {
                root.hoveredZone = true;
                root.hoveredIconIndex = root.iconIndexAt(mouseArea.mouseX, mouseArea.mouseY);
            }
            onExited: {
                root.hoveredZone = false;
                root.trackMouseX = -1;
                root.hoveredIconIndex = -1;
            }
            onPositionChanged: (mouse) => {
                root.trackMouseX = mouse.x - Theme.dockPadding;
                root.hoveredIconIndex = root.iconIndexAt(mouse.x, mouse.y);
            }
            onClicked: (mouse) => {
                // Hit-test against each icon's actual current geometry
                // rather than a fixed resting-grid formula: once any icon
                // is magnified, later icons no longer sit at uniform
                // (iconSize + spacing) intervals, so the old formula's
                // guess drifted from what's on screen -- clicks landed on
                // the wrong icon (or none) depending on cursor position,
                // which is what read as the dock being unreliable to click.
                var idx = root.iconIndexAt(mouse.x, mouse.y);
                if (idx < 0) return;
                var icon = iconRepeater.itemAt(idx);
                if (!icon) return;
                root.closePreview();
                if (icon.entry && icon.entry.isLauncher) {
                    // Permanent launcher slot: no windows, no context menu,
                    // no pin/unpin -- any left click just (re)opens wofi.
                    if (mouse.button === Qt.LeftButton) icon.launchNew();
                    return;
                }
                if (mouse.button === Qt.RightButton
                    || (mouse.button === Qt.LeftButton && icon.toplevels.length > 1)) {
                    // Multiple windows: a plain left click used to cycle to
                    // "the next one", which in practice meant an arbitrary
                    // window got focused instead of the one you wanted --
                    // show the picker instead of guessing.
                    root.contextMenuEntry = icon.entry;
                    root.contextMenuAnchorItem = icon;
                    root.contextMenuIndex = idx;
                } else if (mouse.button === Qt.MiddleButton) {
                    icon.launchNew();
                } else {
                    icon.primaryAction();
                }
            }
        }
    }

    Item {
        id: dockVisual
        width: (root.hoveredZone || root.contextMenuIndex >= 0) ? (root.hoveredRowWidth + Theme.dockPadding * 2) : root.restWidth
        height: root.restHeight
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.shown ? (parent.height - height - Theme.dockMarginBottom) : parent.height
        opacity: root.shown ? 1 : 0

        Behavior on width { NumberAnimation { duration: Theme.animMed; easing.type: Theme.easeOutExpo } }
        Behavior on y { NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easeOutExpo } }
        Behavior on opacity { NumberAnimation { duration: Theme.animMed } }

        // Gradient "border": Rectangle.border.color can't be a gradient, so
        // this is a ring trick -- an outer rounded rect filled with the same
        // horizontal fade used for the bar's bottom edge (transparent ->
        // accent -> transparent), with an inset rect of the dock's normal
        // fill color drawn on top, leaving only a border.width-wide ring of
        // the gradient visible around the edge.
        Rectangle {
            id: dockBorderGlow
            anchors.fill: parent
            anchors.topMargin: 6
            anchors.bottomMargin: 6
            radius: Theme.radius + 8
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Theme.alpha(Theme.accent, 0.0) }
                GradientStop { position: 0.5; color: Theme.alpha(Theme.accent, 0.38) }
                GradientStop { position: 1.0; color: Theme.alpha(Theme.accent, 0.0) }
            }
        }

        Rectangle {
            anchors.fill: dockBorderGlow
            anchors.margins: 2
            radius: Math.max(0, dockBorderGlow.radius - 2)
            color: Theme.alpha(Theme.base, 0.5)
        }

        Row {
            id: iconRow
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.dockPadding
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.dockIconSpacing
            height: Theme.dockIconSize * Theme.dockMaxScale + 14

            Repeater {
                id: iconRepeater
                model: root.dockEntries
                delegate: Modules.DockIcon {
                    required property var modelData
                    required property int index
                    entry: modelData
                    magnify: root.magnifyFor(index)
                }
            }
        }
    }

    Modules.DockContextMenu {
        entry: root.contextMenuEntry
        anchorItem: root.contextMenuAnchorItem
        dockRoot: root
    }

    Modules.DockPreview {
        entry: root.previewEntry
        anchorItem: root.previewAnchorItem
        dockRoot: root
    }
}
