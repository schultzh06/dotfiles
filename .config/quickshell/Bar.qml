import QtQuick
import QtQuick.Layouts
import "./modules" as Modules

Item {
    id: bar
    required property var screen
    readonly property string screenName: screen ? screen.name : ""

    // Fixed to the visible bar height, top-anchored within a taller panel
    // window -- see Theme.tooltipReserve for why the window is taller than
    // this. Only this region is part of the input mask, so the reserved
    // strip below stays click-through for whatever's underneath.
    height: Theme.barHeight

    // Same ring trick as the dock's border (Dock.qml's dockBorderGlow +
    // inset fill): an outer rect filled with the horizontal accent fade,
    // covered by an inset rect of the bar's normal fill, leaving a
    // border.width-wide traced line around the bar instead of a single
    // flat line. Keeps the bar and dock reading as one matching style
    // rather than the bar's old edge-to-edge line, which stretched the
    // same gradient across the full screen width and washed it out.
    //
    // Unlike the dock (a floating pill that never touches the screen
    // edges, and always rounded), the bar is edge-to-edge -- so this
    // only insets top/bottom, not left/right. The gradient's horizontal
    // orientation goes fully transparent at position 0.0/1.0, i.e. at
    // x=0 and x=width; insetting all four sides like the dock does would
    // put a fully-transparent 2px-wide strip the full height of the bar
    // exactly at the true screen edges (not just the corners), showing
    // the desktop through a visible gap along both sides.
    Rectangle {
        id: barBorderGlow
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Theme.alpha(Theme.accent, 0.0) }
            GradientStop { position: 0.5; color: Theme.alpha(Theme.accent, 0.38) }
            GradientStop { position: 1.0; color: Theme.alpha(Theme.accent, 0.0) }
        }
    }

    Rectangle {
        anchors.fill: barBorderGlow
        anchors.topMargin: 2
        anchors.bottomMargin: 2
        color: Theme.alpha(Theme.base, 0.3)
    }

    RowLayout {
        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
        spacing: 6
        Modules.Workspaces { screenName: bar.screenName }
        Modules.WindowTitle { screenName: bar.screenName }
        Modules.Tray { Layout.leftMargin: 6 }
    }

    Modules.ClockTime {
        id: clockTime
        anchors.centerIn: parent
    }

    Modules.MediaArt {
        anchors {
            right: clockTime.left
            rightMargin: Theme.mediaClusterSpacing
            verticalCenter: clockTime.verticalCenter
        }
    }

    Modules.MediaVisualizer {
        anchors {
            left: clockTime.right
            leftMargin: Theme.mediaClusterSpacing
            verticalCenter: clockTime.verticalCenter
        }
    }

    RowLayout {
        anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
        spacing: 2
        Modules.Cpu {}
        Modules.Memory {}
        Modules.Temperature {}
        Modules.Volume {}
        Modules.Network {}
        Modules.Battery {}
        Modules.ClockDate { Layout.leftMargin: 4 }
    }

    opacity: 0
    transform: Translate { id: slideIn; y: -8 }
    Component.onCompleted: entrance.start()
    ParallelAnimation {
        id: entrance
        NumberAnimation { target: bar; property: "opacity"; to: 1; duration: 380; easing.type: Easing.OutCubic }
        NumberAnimation { target: slideIn; property: "y"; to: 0; duration: 380; easing.type: Theme.easeOutExpo }
    }
}
