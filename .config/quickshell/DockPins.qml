pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Shared pinned-apps state for the dock, persisted to dock-pins.json next
// to this file. Singleton so every monitor's Dock instance sees the same
// pins and stays in sync when one of them pins/unpins something.
QtObject {
    id: root

    // Plain `{id}` entries resolve through a normal .desktop file; entries
    // with `exec` are custom launchers matched by window class instead
    // (yazi has no .desktop entry of its own -- see
    // ~/.config/hypr/hyprland.lua's "yazi-float" floating-window rule and
    // the mod+E keybind it mirrors).
    readonly property var defaultPinnedApps: [
        { id: "kitty" },
        { id: "brave-browser" },
        { id: "code" },
        { id: "com.anthropic.Claude" },
        { id: "yazi", matchClass: "yazi-float", name: "Yazi", icon: "system-file-manager", exec: ["kitty", "--class", "yazi-float", "-e", "yazi"], alwaysNew: true },
        { id: "obsidian" }
    ]
    property var pinnedApps: defaultPinnedApps

    property FileView pinsFile: FileView {
        path: Quickshell.shellPath("dock-pins.json")
        preload: true
        watchChanges: false
        printErrors: false
    }
    property Connections pinsFileWatcher: Connections {
        target: root.pinsFile
        function onLoadedOrAsyncChanged() {
            if (!root.pinsFile.loaded) return;
            try {
                var parsed = JSON.parse(root.pinsFile.text());
                if (Array.isArray(parsed) && parsed.length > 0) root.pinnedApps = parsed;
            } catch (e) {
                // no saved pins yet -- keep defaultPinnedApps
            }
        }
    }

    function save() { root.pinsFile.setText(JSON.stringify(root.pinnedApps)); }

    function pin(appIdKey) {
        var apps = root.pinnedApps.slice();
        apps.push({ id: appIdKey });
        root.pinnedApps = apps;
        root.save();
    }

    function unpin(pinId) {
        root.pinnedApps = root.pinnedApps.filter(function (p) { return p.id !== pinId; });
        root.save();
    }
}
