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

    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.base, 0.3)
    }

    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 1.5
        color: Theme.alpha(Theme.lavender, 0.3)
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
