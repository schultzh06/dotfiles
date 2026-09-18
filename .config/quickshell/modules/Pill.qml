import QtQuick
import QtQuick.Layouts
import "../"

// Reusable hoverable/clickable rounded pill. Put content in a Row via the
// default `content` alias; the pill sizes itself to fit.
Item {
    id: root

    default property alias content: row.data
    property bool interactive: true
    property color idleColor: "transparent"
    property color hoverColor: Theme.alpha(Theme.surface0, 0.8)
    property real horizontalPadding: Theme.pillPadding
    property string tooltipText: ""

    signal clicked(var mouse)
    signal rightClicked(var mouse)
    signal wheelMoved(int delta)

    readonly property bool hovered: mouseArea.containsMouse

    implicitWidth: row.implicitWidth + horizontalPadding * 2
    implicitHeight: Theme.barHeight - 6

    Behavior on implicitWidth {
        NumberAnimation { duration: Theme.animMed; easing.type: Theme.easeOutExpo }
    }

    scale: mouseArea.pressed && interactive ? 0.92 : 1.0
    Behavior on scale {
        NumberAnimation { duration: Theme.animFast; easing.type: Theme.easeOutBack }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: root.interactive && root.hovered ? root.hoverColor : root.idleColor
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    Item {
        // Clips content to the pill's own (currently animating) bounds, so
        // when a wider replacement (e.g. a longer window title) lands, it
        // reveals through the growing pill instead of spilling out past its
        // background while the width Behavior above is still catching up.
        anchors.fill: parent
        clip: true

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 6
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: root.interactive ? (Qt.LeftButton | Qt.RightButton | Qt.MiddleButton) : Qt.NoButton
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) root.rightClicked(mouse);
            else root.clicked(mouse);
        }
        onWheel: (wheel) => root.wheelMoved(wheel.angleDelta.y)
    }

    Timer {
        id: tooltipDelay
        interval: 450
        onTriggered: tooltip.opacity = 1
    }
    onHoveredChanged: {
        if (root.hovered && root.tooltipText.length > 0) {
            tooltipDelay.start();
        } else {
            tooltipDelay.stop();
            tooltip.opacity = 0;
        }
    }

    Rectangle {
        id: tooltip
        opacity: 0
        visible: opacity > 0
        z: 1000
        radius: 10
        color: Theme.mantle
        border.width: 1
        border.color: Theme.alpha(Theme.accent, 0.35)
        anchors.top: parent.bottom
        anchors.topMargin: 6
        anchors.right: parent.right
        implicitWidth: tooltipLabel.implicitWidth + 16
        implicitHeight: tooltipLabel.implicitHeight + 10

        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

        Text {
            id: tooltipLabel
            anchors.centerIn: parent
            text: root.tooltipText
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 11
            wrapMode: Text.NoWrap
        }
    }
}
