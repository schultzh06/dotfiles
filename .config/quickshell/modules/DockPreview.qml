import QtQuick
import Quickshell
import Quickshell.Wayland
import "../"

// Hover preview for a dock icon with open windows: a strip of live
// per-window thumbnails so you can see which window you're about to pick
// before clicking, rather than guessing from a title alone. Genuinely
// live and correct regardless of which workspace a window is actually
// on -- ScreencopyView.captureSource accepts a Wayland toplevel handle
// directly (Hyprland's hyprland-toplevel-export-v1 protocol under the
// hood), not just a whole-monitor capture, so there's no cropping/
// staleness trick needed here (verified against a window sitting on an
// inactive workspace before this was written).
//
// Structurally a lighter cousin of DockContextMenu.qml: same PopupWindow
// + anchor.item pattern, but dismissed via hover tracking (coordinated
// with Dock.qml's previewEntry/previewAnchorItem/notePreviewHover) rather
// than HyprlandFocusGrab, since nothing here needs outside-click dismiss.
PopupWindow {
    id: popup
    property var entry: null
    property var anchorItem: null
    required property var dockRoot

    readonly property var toplevels: entry ? entry.toplevels : []
    readonly property int thumbWidth: 160
    readonly property int thumbHeight: 100
    readonly property int cardSpacing: 10
    readonly property int cardPadding: 8
    // Sized for a fixed max card count rather than toplevels.length: the
    // popup's horizontal centering on its anchor icon is computed once,
    // at the same moment `visible`/`entry` flip -- when implicitWidth was
    // *also* derived from toplevels.length, that positioning calc and the
    // width settling into its real value raced (QML doesn't guarantee
    // sibling binding evaluation order within one update), and it lost
    // often enough to consistently land the popup centered on the whole
    // dock/screen instead of the icon. A width that's already at its
    // final value before this component is ever shown sidesteps the race
    // entirely -- same reason DockContextMenu.qml's fixed implicitWidth
    // (232, never content-dependent) never had this problem despite its
    // *height* varying with window count without issue: height only
    // changes how far the popup extends upward from a fixed-edge anchor,
    // not the anchor-relative point itself, so it isn't in that race.
    readonly property int maxSizedCards: 4
    // The *visible* box, sized to the actual card count -- unlike
    // implicitWidth below (kept constant for positioning stability, see
    // its comment), this is fine to vary with content: it only affects
    // what's drawn inside the fixed-size surface, not where that surface
    // gets positioned.
    readonly property int contentWidth: Math.max(1, toplevels.length) * thumbWidth
        + Math.max(0, toplevels.length - 1) * cardSpacing + cardPadding * 2
    readonly property int contentHeight: thumbHeight + 36 + cardPadding * 2

    visible: entry !== null && anchorItem !== null

    color: "transparent"
    implicitWidth: maxSizedCards * thumbWidth + (maxSizedCards - 1) * cardSpacing + cardPadding * 2
    implicitHeight: contentHeight

    anchor.window: anchorItem ? anchorItem.QsWindow.window : null
    anchor.item: anchorItem
    anchor.edges: Edges.Top
    anchor.gravity: Edges.Top
    // No gap to the anchor icon (DockContextMenu uses 8px, but that's
    // only ever crossed by an outside click landing anywhere, never by a
    // cursor that has to physically travel through it): this popup and
    // the dock's own surface are two independent Wayland surfaces, and
    // a real gap between them is a dead zone neither one owns -- moving
    // the cursor from the icon up into the preview crossed it, which read
    // as "left everything" and started the close timer before the cursor
    // ever registered as entering the popup. Zero margin keeps them
    // edge-adjacent (the dock's own hit region already extends above the
    // icon's current top in most cases, since it's sized for max
    // magnification) so there's always something under the cursor.
    anchor.margins.bottom: 0

    Rectangle {
        id: bg
        anchors.centerIn: parent
        width: popup.contentWidth
        height: popup.contentHeight
        radius: 10
        color: Theme.mantle
        border.width: 1
        border.color: Theme.alpha(Theme.lavender, 0.35)

        MouseArea {
            // Keeps the preview open while the cursor is on the popup
            // itself (moving from the icon up onto it briefly leaves the
            // dock's own hit area) -- mirrors how the dock keeps itself
            // shown while its context menu is open. Each card's own
            // MouseArea below reports the same thing on enter/exit: a
            // MouseArea covered by another hoverEnabled MouseArea in
            // front of it stops receiving hover for that covered region,
            // so without the cards also reporting in, moving onto any
            // thumbnail read as "left the popup" and closed it out from
            // under the cursor after the hide grace period.
            anchors.fill: parent
            hoverEnabled: true
            onEntered: popup.dockRoot.notePreviewHover(true)
            onExited: popup.dockRoot.notePreviewHover(false)
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: popup.cardSpacing

        Repeater {
            model: popup.toplevels
            delegate: Column {
                id: card
                required property var modelData
                spacing: 4

                Item {
                    width: popup.thumbWidth
                    height: popup.thumbHeight

                    Rectangle {
                        anchors.fill: parent
                        radius: 6
                        clip: true
                        color: Theme.surface0

                        ScreencopyView {
                            id: shot
                            visible: hasContent
                            captureSource: card.modelData.wayland || null
                            live: true
                            // Render near the window's actual resolution and
                            // let `layer.smooth` do one properly-filtered
                            // downscale to fit the thumbnail box, instead of
                            // asking ScreencopyView to render directly at the
                            // tiny target size: its own internal minification
                            // of a live (per-frame-updated) texture isn't
                            // mipmapped -- expensive to regenerate every
                            // frame -- so shrinking it directly produced
                            // genuinely aliased/blocky text, not a soft blur.
                            // constraintSize doesn't help here regardless: it
                            // only ever constrained *implicit* size, which
                            // this was already overriding via anchors.fill.
                            width: hasContent ? sourceSize.width : popup.thumbWidth
                            height: hasContent ? sourceSize.height : popup.thumbHeight
                            scale: hasContent
                                ? Math.min(popup.thumbWidth / sourceSize.width, popup.thumbHeight / sourceSize.height)
                                : 1
                            transformOrigin: Item.TopLeft
                            layer.enabled: true
                            layer.smooth: true
                        }

                        Text {
                            visible: !shot.hasContent
                            anchors.centerIn: parent
                            text: (card.modelData.title || "?").charAt(0).toUpperCase()
                            color: Theme.subtext1
                            font.family: Theme.fontFamily
                            font.pixelSize: 28
                            font.bold: true
                        }
                    }

                    // Separate, unclipped sibling drawn after the thumbnail
                    // -- a border on the same Rectangle as the live capture
                    // gets painted over by it (children paint on top of
                    // their parent's own border), which hid the border
                    // under the thumbnail instead of framing it.
                    Rectangle {
                        anchors.fill: parent
                        radius: 6
                        color: "transparent"
                        border.width: cardMouse.containsMouse ? 1 : 0
                        border.color: Theme.lavender
                    }

                    MouseArea {
                        id: cardMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: popup.dockRoot.notePreviewHover(true)
                        onExited: popup.dockRoot.notePreviewHover(false)
                        onClicked: {
                            if (card.modelData.wayland) card.modelData.wayland.activate();
                            popup.dockRoot.closePreview();
                        }
                    }
                }

                Text {
                    width: popup.thumbWidth
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: card.modelData.title || "(untitled)"
                    color: Theme.subtext0
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }
            }
        }
    }
}
