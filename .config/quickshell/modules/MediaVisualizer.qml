import QtQuick
import "../"

// Audio spectrum visualizer for the currently playing track, flanking the
// clock on its right. Bars grow symmetrically from the vertical center
// (macOS/waybar style) rather than from a bottom baseline. Collapses to
// zero width and fades out whenever playback isn't actively running
// (paused, stopped, or no player).
Item {
    id: root
    readonly property bool active: MediaState.isPlaying

    implicitWidth: active ? Theme.mediaSquareSize : 0
    implicitHeight: Theme.mediaSquareSize
    opacity: active ? 1 : 0
    clip: true

    Behavior on implicitWidth {
        NumberAnimation { duration: Theme.animMed; easing.type: Theme.easeOutExpo }
    }
    Behavior on opacity {
        NumberAnimation { duration: Theme.animMed }
    }

    Row {
        anchors.centerIn: parent
        spacing: Theme.visualizerBarSpacing

        Repeater {
            model: Theme.visualizerBarCount

            Rectangle {
                id: bar
                required property int index
                readonly property real level: {
                    var levels = MediaState.levels;
                    return index < levels.length ? Math.max(0, Math.min(100, levels[index])) : 0;
                }

                width: Theme.visualizerBarWidth
                radius: width / 2
                color: Theme.lavender
                anchors.verticalCenter: parent.verticalCenter
                height: Math.max(width, Theme.mediaSquareSize * (level / 100))

                Behavior on height {
                    NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                }
            }
        }
    }
}
