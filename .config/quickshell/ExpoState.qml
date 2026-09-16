pragma Singleton
import QtQuick

// Whether expo mode (all-workspaces overview) is showing. One flag shared
// by every monitor's Expo instance (see shell.qml) so a single keybind
// toggles the whole overview at once -- each instance only ever renders
// its own monitor's workspaces, same split as Bar/Dock.
QtObject {
    property bool shown: false

    function toggle() { shown = !shown; }
    function hide() { shown = false; }
}
