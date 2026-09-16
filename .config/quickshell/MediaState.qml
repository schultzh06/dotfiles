pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// Shared now-playing state for every screen's Bar. One Mpris lookup and one
// cava process serve all monitors -- cava reads the same system audio
// regardless of which screen's bar is drawing it, so each Bar instance must
// not spawn its own (that would run N redundant analyzers).
QtObject {
    id: root

    readonly property var _players: Mpris.players.values

    // Prefer whichever player is actually playing; fall back to the first
    // known player so pausing doesn't instantly yank the art away.
    readonly property var activePlayer: {
        for (var i = 0; i < _players.length; i++) {
            if (_players[i].isPlaying) return _players[i];
        }
        return _players.length > 0 ? _players[0] : null;
    }

    readonly property bool hasMedia: activePlayer !== null
    readonly property bool isPlaying: activePlayer !== null && activePlayer.isPlaying
    readonly property string trackTitle: activePlayer ? activePlayer.trackTitle : ""
    readonly property string trackArtist: activePlayer ? activePlayer.trackArtist : ""
    readonly property string trackArtUrl: activePlayer ? activePlayer.trackArtUrl : ""

    readonly property int barCount: Theme.visualizerBarCount
    property var levels: new Array(barCount).fill(0)

    onIsPlayingChanged: {
        if (!isPlaying) root.levels = new Array(root.barCount).fill(0);
    }

    property Process cava: Process {
        running: root.isPlaying
        command: ["cava", "-p", Quickshell.shellPath("cava/cava.conf")]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                var parts = data.split(";").filter(p => p.length > 0).map(Number);
                if (parts.length === root.barCount) root.levels = parts;
            }
        }
    }
}
