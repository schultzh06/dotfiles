//@ pragma UseQApplication
//@ pragma IconTheme Papirus-Dark

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

ShellRoot {
    IpcHandler {
        target: "expo"
        function toggle(): string { ExpoState.toggle(); return "ok"; }
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            anchors { top: true; left: true; right: true }
            implicitHeight: Theme.barHeight + Theme.tooltipReserve
            exclusiveZone: Theme.barHeight
            color: "transparent"
            mask: Region { item: bar }

            Bar {
                id: bar
                anchors { top: parent.top; left: parent.left; right: parent.right }
                screen: modelData
            }
        }
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: dockWindow
            required property var modelData
            screen: modelData
            anchors { bottom: true }
            implicitWidth: dock.restWidth + Theme.dockHorizontalHeadroom * 2
            implicitHeight: dock.hitHeight + Theme.dockMarginBottom
            exclusiveZone: 0
            color: "transparent"
            mask: Region { item: dock.maskItem }

            Dock {
                id: dock
                anchors.fill: parent
                screen: modelData
            }
        }
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            // Bar/Dock each anchor 1-3 edges and set an explicit
            // implicit* size for whichever dimension isn't anchor-
            // stretched; anchoring all 4 edges with no implicit size at
            // all turned out to be an untested combination here -- it
            // mapped (no error, ExpoState.shown read back true) but drew
            // nothing, consistent with the compositor being asked to
            // size a surface with no size hint at all. Binding both
            // dimensions to the screen explicitly sidesteps that.
            implicitWidth: modelData ? modelData.width : 0
            implicitHeight: modelData ? modelData.height : 0
            visible: ExpoState.shown
            exclusiveZone: 0
            color: "transparent"
            // Distinct namespace so hyprland.lua's blur-quickshell layer
            // rule (tuned for the thin, mostly-static bar/dock) doesn't
            // also apply to this full-screen, live-video-heavy overlay --
            // compositor blur on something this size, updating every
            // frame, was a real chunk of the reported lag. PanelWindow has
            // no plain `namespace` property (confirmed: "Cannot assign to
            // non-existent property"); only the WlrLayershell.namespace
            // attached form compiles. A previous attempt also set
            // WlrLayershell.layer alongside it and the surface never
            // mapped -- namespace alone is untested in isolation, so this
            // is being verified via hyprctl layers, not assumed safe.
            WlrLayershell.namespace: "quickshell-expo"
            // Tried WlrKeyboardFocus.Exclusive here for Escape-to-close --
            // reverted. Confirmed by exact timing twice: the shell died
            // with a Wayland "error in client communication" a few
            // minutes after it was added, specifically when closing an
            // unrelated window (a focus-stack change), and again after a
            // second attempt. An exclusive keyboard grab on a layer-shell
            // surface interacting badly with focus changes elsewhere is a
            // known-risky combination; not worth it for a convenience key.
            // See Expo.qml for the matching revert of the Escape handler.
            //
            // OnDemand (for the number-key-to-workspace shortcut) is a
            // different mode, not a retry of the same one -- it plays by
            // the compositor's normal focus-stack rules (participates like
            // any other on-demand surface, e.g. a launcher) rather than
            // Exclusive's forced seat grab that fought focus-stack changes
            // elsewhere. Also, unlike that reverted attempt, this is only
            // ever set while ExpoState.shown -- back to None the instant
            // it hides, so it never holds any special focus mode at rest.
            WlrLayershell.keyboardFocus: ExpoState.shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            Expo {
                anchors.fill: parent
                screen: modelData
            }
        }
    }
}
