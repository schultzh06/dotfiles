import QtQuick
import QtQuick.Window
import QtQuick.Effects
import "../"

Item {
    id: root

    // Now shows whenever something is playing — fallback covers the no-art case.
    readonly property bool active: MediaState.isPlaying
    readonly property string artUrl: MediaState.trackArtUrl
    readonly property real dpr: Screen.devicePixelRatio
    readonly property int artMargin: 1
    readonly property int artSize: Theme.mediaSquareSize - 2 * artMargin

    property bool showA: true
    readonly property var backImage: showA ? imgB : imgA

    implicitWidth: active ? artSize : 0
    implicitHeight: Theme.mediaSquareSize
    opacity: active ? 1 : 0
    clip: true

    Behavior on implicitWidth {
        NumberAnimation { duration: Theme.animMed; easing.type: Theme.easeOutExpo }
    }
    Behavior on opacity {
        NumberAnimation { duration: Theme.animMed }
    }

    onArtUrlChanged: {
        if (artUrl.length === 0) return;
        if (backImage.source == artUrl && backImage.status === Image.Ready) {
            showA = !showA;                 // already decoded, just swap
        } else {
            backImage.source = artUrl;      // swap happens in onStatusChanged
        }
    }

    component ArtLayer: Image {
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        mipmap: true
        anchors.fill: parent
        sourceSize.width: Math.ceil(root.artSize * root.dpr)
        sourceSize.height: Math.ceil(root.artSize * root.dpr)

        Behavior on opacity {
            NumberAnimation { duration: Theme.animMed; easing.type: Easing.InOutQuad }
        }
        Behavior on scale {
            NumberAnimation { duration: Theme.animMed; easing.type: Theme.easeOutExpo }
        }
    }

    Item {
        id: artStack
        anchors.centerIn: parent
        width: root.artSize
        height: root.artSize
        visible: false
        layer.enabled: true
        layer.smooth: true

        // Fallback sits underneath both images.
        Rectangle {
            anchors.fill: parent
            color: Theme.surface1
            Text {
                anchors.centerIn: parent
                font.family: Theme.iconFontFamily
                font.pixelSize: Math.round(root.artSize * 0.5)
                color: Theme.overlay0
                text: "\uf001"        // music note — verify against your font
            }
        }

        ArtLayer {
            id: imgA
            opacity: root.showA && status === Image.Ready ? 1 : 0
            scale: root.showA ? 1.0 : 1.06
            onStatusChanged: if (status === Image.Ready && root.backImage === imgA) root.showA = true
        }

        ArtLayer {
            id: imgB
            opacity: !root.showA && status === Image.Ready ? 1 : 0
            scale: !root.showA ? 1.0 : 1.06
            onStatusChanged: if (status === Image.Ready && root.backImage === imgB) root.showA = false
        }
    }

    Rectangle {
        id: mask
        anchors.centerIn: parent
        width: root.artSize
        height: root.artSize
        radius: Theme.radius - 3
        antialiasing: true
        visible: false
        layer.enabled: true
        layer.smooth: true
    }

    MultiEffect {
        anchors.centerIn: parent
        width: root.artSize
        height: root.artSize
        source: artStack
        maskEnabled: true
        maskSource: mask
    }
}
