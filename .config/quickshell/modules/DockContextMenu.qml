import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../"

// Right-click menu for a dock icon: jump to any open window of that app,
// pin/unpin it, or close every window it has open. A real PopupWindow (its
// own floating surface) rather than crammed into the dock's own window, so
// its height can vary freely with the number of open windows.
PopupWindow {
    id: popup
    property var entry: null
    property var anchorItem: null
    required property var dockRoot

    readonly property var toplevels: entry ? entry.toplevels : []
    readonly property int rowHeight: 40
    readonly property int thumbWidth: 46
    readonly property int thumbHeight: 28

    visible: entry !== null && anchorItem !== null

    // PopupWindow's own `grabFocus` dismiss-on-outside-click forces
    // `visible` false itself, which fights the plain binding above --
    // HyprlandFocusGrab instead just *detects* the outside click and
    // leaves closing the menu to us, so `visible` can stay a normal
    // binding driven only by entry/anchorItem.
    HyprlandFocusGrab {
        id: focusGrab
        windows: [popup]
        onCleared: popup.dockRoot.closeMenu()
    }
    onVisibleChanged: {
        // Requesting the grab in the same instant the window becomes
        // visible loses the race with the compositor actually mapping it
        // (the grab silently fails to activate) -- a beat of delay is
        // enough for it to land reliably.
        if (visible) grabDelay.start();
        else focusGrab.active = false;
    }
    Timer {
        id: grabDelay
        interval: 30
        onTriggered: focusGrab.active = popup.visible
    }

    color: "transparent"
    implicitWidth: 232
    implicitHeight: content.implicitHeight + 16

    anchor.window: anchorItem ? anchorItem.QsWindow.window : null
    anchor.item: anchorItem
    anchor.edges: Edges.Top
    anchor.gravity: Edges.Top
    anchor.margins.bottom: 8

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: Theme.mantle
        border.width: 1
        border.color: Theme.alpha(Theme.lavender, 0.35)
    }

    Column {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 8
        spacing: 2

        Text {
            width: parent.width
            text: popup.entry ? popup.entry.name : ""
            color: Theme.subtext0
            font.family: Theme.fontFamily
            font.pixelSize: 10
            font.bold: true
            elide: Text.ElideRight
            bottomPadding: 4
        }

        Repeater {
            model: popup.toplevels
            delegate: Rectangle {
                id: windowRow
                required property var modelData
                width: content.width
                height: popup.rowHeight
                radius: 6
                color: windowMouse.containsMouse ? Theme.alpha(Theme.surface0, 0.8) : "transparent"

                Rectangle {
                    id: thumb
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    width: popup.thumbWidth
                    height: popup.thumbHeight
                    radius: 4
                    clip: true
                    color: Theme.surface0

                    // Genuinely live per-window capture (Hyprland's
                    // hyprland-toplevel-export-v1 via captureSource
                    // accepting a Wayland toplevel handle directly), so
                    // this is correct even for a window on a different,
                    // inactive workspace -- not a whole-monitor crop.
                    ScreencopyView {
                        id: shot
                        visible: hasContent
                        captureSource: windowRow.modelData.wayland || null
                        live: true
                        // See DockPreview.qml's identical block for why:
                        // render near-native and let layer.smooth do one
                        // properly-filtered downscale, rather than have
                        // ScreencopyView's own (non-mipmapped, since it's
                        // a live per-frame texture) minification alias
                        // text into blocky noise.
                        width: hasContent ? sourceSize.width : popup.thumbWidth
                        height: hasContent ? sourceSize.height : popup.thumbHeight
                        scale: hasContent
                            ? Math.min(popup.thumbWidth / sourceSize.width, popup.thumbHeight / sourceSize.height)
                            : 1
                        transformOrigin: Item.TopLeft
                        layer.enabled: true
                        layer.smooth: true
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: thumb.right
                    anchors.right: parent.right
                    anchors.leftMargin: 8
                    anchors.rightMargin: 6
                    elide: Text.ElideRight
                    text: windowRow.modelData.title || "(untitled)"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }

                MouseArea {
                    id: windowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (windowRow.modelData.wayland) windowRow.modelData.wayland.activate();
                        popup.dockRoot.closeMenu();
                    }
                }
            }
        }

        Rectangle {
            visible: popup.toplevels.length > 0
            width: content.width
            height: 1
            color: Theme.alpha(Theme.subtext0, 0.2)
        }

        Rectangle {
            visible: popup.entry && (popup.entry.execCommand || popup.entry.desktopEntry)
            width: content.width
            height: popup.rowHeight
            radius: 6
            color: newWindowMouse.containsMouse ? Theme.alpha(Theme.surface0, 0.8) : "transparent"

            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 6
                text: "New Window"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }

            MouseArea {
                id: newWindowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (popup.anchorItem) popup.anchorItem.launchNew();
                    popup.dockRoot.closeMenu();
                }
            }
        }

        Rectangle {
            width: content.width
            height: popup.rowHeight
            radius: 6
            color: pinMouse.containsMouse ? Theme.alpha(Theme.surface0, 0.8) : "transparent"

            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 6
                text: (popup.entry && popup.entry.pinned) ? "Unpin from Dock" : "Pin to Dock"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }

            MouseArea {
                id: pinMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (!popup.entry) return;
                    if (popup.entry.pinned) popup.dockRoot.unpinApp(popup.entry.pinId);
                    else popup.dockRoot.pinApp(popup.entry.appIdKey);
                    popup.dockRoot.closeMenu();
                }
            }
        }

        Rectangle {
            visible: popup.toplevels.length > 0
            width: content.width
            height: popup.rowHeight
            radius: 6
            color: closeMouse.containsMouse ? Theme.alpha(Theme.red, 0.25) : "transparent"

            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 6
                text: "Close All Windows"
                color: Theme.red
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }

            MouseArea {
                id: closeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    var tps = popup.toplevels;
                    for (var i = 0; i < tps.length; i++) {
                        if (tps[i].wayland) tps[i].wayland.close();
                    }
                    popup.dockRoot.closeMenu();
                }
            }
        }
    }
}
