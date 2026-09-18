import QtQuick
import Quickshell.Wayland
import "../"

// One window's placeholder inside an Expo workspace card, positioned and
// sized by the caller (Expo.qml) to match the window's real scaled-down
// on-screen geometry -- this component just renders whatever box it's
// given, it doesn't know about tile grids.
//
// Live capture history: an earlier attempt used a continuous
// `ScreencopyView { live: true }` per tile and crashed the whole shell
// three times in one session, every time correlated with closing some
// window shortly after Expo had been open -- a Wayland "error in client
// communication" protocol violation, not a QML error. The real trigger
// wasn't a stale reference on the closed window's own tile (that was
// already null-guarded, see `title` below): Expo's Repeaters are bound to
// plain JS arrays (workspaceRows / the per-card windows list), and QtQuick
// gives plain-array models no element identity to diff against, so
// *any* change to Hyprland.toplevels -- one window closing anywhere --
// reassigns those arrays wholesale and tears down and recreates *every*
// tile across *every* workspace in the same tick, all at once. That's a
// lot of simultaneous live-stream teardown/recreate churn landing right
// when a toplevel is disappearing, which is exactly the situation that
// tripped the protocol error.
//
// Fix: capture a single still frame (`live: false`, the ScreencopyView
// default) instead of a continuous stream. A one-shot capture has no
// persistent request that a subsequent close can race, and per the
// hyprland-toplevel-export-v1 protocol the frame object is destroyed
// right after the ready/failed event anyway -- there's nothing left
// in flight moments later for a close to corrupt. Since any toplevel
// change already rebuilds every tile from scratch (see above), the
// still frame naturally refreshes on basically every workspace change
// while Expo is open, which reads as "live" in practice without an
// open-ended stream.
Item {
    id: tile
    required property var toplevel

    // `toplevel` can go null out from under a live delegate: closing a
    // window updates Hyprland.toplevels, which rebuilds Expo.qml's
    // workspaceGroups, which replaces this Repeater's whole model -- if
    // that lands while this item is still finishing removal, `toplevel`
    // reads as null for a beat.
    readonly property string title: (tile.toplevel && tile.toplevel.title) || ""
    // Same null-guard, and also gated on ExpoState.shown so nothing here
    // ever holds a capture source while the overview itself is closed --
    // belt and suspenders on top of Expo.qml already discarding every
    // tile (and this property along with it) the instant it hides.
    readonly property var captureHandle: (ExpoState.shown && tile.toplevel && tile.toplevel.wayland) || null

    Rectangle {
        anchors.fill: parent
        radius: 4
        clip: true
        color: Theme.surface0

        ScreencopyView {
            id: shot
            visible: hasContent
            captureSource: tile.captureHandle
            paintCursor: false
            // Render near the window's actual (DPI-scaled) resolution and
            // let `layer.smooth` do one properly-filtered downscale to fit
            // the tile, instead of `anchors.fill: parent` -- ScreencopyView
            // has no smooth/fillMode property of its own, so stretching it
            // straight to the tiny tile size downsampled in a single
            // unfiltered step, and on a HiDPI output (eDP-1 at ~1.667
            // scale) the captured frame has proportionally more source
            // pixels to cram into the same small box, which is exactly
            // what made the previews look worse there specifically. Same
            // fix DockPreview.qml and DockContextMenu.qml already use.
            width: hasContent ? sourceSize.width : tile.width
            height: hasContent ? sourceSize.height : tile.height
            scale: hasContent
                ? Math.min(tile.width / sourceSize.width, tile.height / sourceSize.height)
                : 1
            transformOrigin: Item.TopLeft
            layer.enabled: true
            layer.smooth: true
        }

        Text {
            visible: !shot.hasContent && tile.height > 40
            anchors.centerIn: parent
            text: tile.title ? tile.title.charAt(0).toUpperCase() : "?"
            color: Theme.subtext1
            font.family: Theme.fontFamily
            font.pixelSize: Math.min(28, tile.height * 0.4)
            font.bold: true
        }

        // Title bar: always shown (not just as a no-content fallback --
        // that hid it the moment a real screenshot loaded, which is most
        // of the time now that previews actually work). A scrim behind the
        // text keeps it legible over arbitrary, unpredictable window
        // content rather than relying on Theme.subtext0 alone to read
        // against whatever's captured underneath.
        Rectangle {
            visible: tile.height > 40 && tile.width > 60
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 18
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: Theme.alpha(Theme.crust, 0.75) }
            }

            Text {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 4
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: tile.title
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 10
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 4
        color: "transparent"
        border.width: mouse.containsMouse ? 2 : 1
        border.color: mouse.containsMouse ? Theme.accent : Theme.alpha(Theme.crust, 0.6)
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (tile.toplevel && tile.toplevel.wayland) tile.toplevel.wayland.activate();
            ExpoState.hide();
        }
    }
}
