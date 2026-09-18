pragma Singleton
import QtQuick

// Catppuccin Mocha, matching ~/.config/waybar/style.css, plus the animation
// constants shared across every bar module.
QtObject {
    readonly property color base: "#1e1e2e"
    readonly property color mantle: "#181825"
    readonly property color crust: "#11111b"
    readonly property color surface0: "#313244"
    readonly property color surface1: "#45475a"
    readonly property color surface2: "#585b70"
    readonly property color overlay0: "#6c7086"
    readonly property color subtext0: "#a6adc8"
    readonly property color subtext1: "#bac2de"
    readonly property color text: "#cdd6f4"
    readonly property color lavender: "#b4befe"
    readonly property color blue: "#89b4fa"
    readonly property color teal: "#94e2d5"
    readonly property color green: "#a6e3a1"
    readonly property color yellow: "#f9e2af"
    readonly property color peach: "#fab387"
    readonly property color red: "#f38ba8"
    readonly property color mauve: "#cba6f7"
    readonly property color rosewater: "#f5e0dc"

    // Single accent used throughout the bar/dock -- change this to switch
    // the whole setup's accent color (e.g. lavender vs peach) in one place.
    readonly property color accent: rosewater

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    // Blend two colors linearly, t in [0,1].
    function mix(c1, c2, t) {
        return Qt.rgba(
            c1.r + (c2.r - c1.r) * t,
            c1.g + (c2.g - c1.g) * t,
            c1.b + (c2.b - c1.b) * t,
            c1.a + (c2.a - c1.a) * t
        );
    }

    readonly property string fontFamily: "Inter"
    readonly property string iconFontFamily: "Symbols Nerd Font"

    readonly property int barHeight: 34
    readonly property int radius: 8
    readonly property int pillPadding: 9
    // Extra vertical room below the visible bar, reserved in the panel
    // window (but not in the layer-shell exclusive zone) so tooltips have
    // somewhere to actually paint -- a wlr-layer-shell surface can't render
    // pixels outside its own buffer, so without this the tooltip Rectangles
    // would be clipped out of existence the instant they cross the bar's
    // bottom edge.
    readonly property int tooltipReserve: 60

    readonly property int animFast: 140
    readonly property int animMed: 260
    readonly property int animSlow: 420

    readonly property int easeOutExpo: Easing.OutExpo
    readonly property int easeOutBack: Easing.OutBack
    readonly property int easeOutCubic: Easing.OutCubic

    // Dock
    readonly property int dockIconSize: 44
    readonly property int dockIconSpacing: 10
    readonly property real dockMaxScale: 1.7
    readonly property int dockInfluenceRadius: 92
    readonly property int dockMarginBottom: 10
    readonly property int dockPadding: 10
    // How tall the edge-hover reveal trigger is while the dock is hidden --
    // deliberately tiny so it doesn't eat a chunk of the screen; the full
    // dock-sized hit area only exists while it's actually shown.
    readonly property int dockRevealStripHeight: 4
    // Same idea, horizontally: several icons near the cursor can be
    // magnified at once (their influence radii overlap), which widens the
    // row well beyond its resting width. Reserve enough on each side for
    // ~3 icons at full magnification simultaneously -- generous on purpose,
    // it's just reserved window space, not rendered content.
    readonly property int dockHorizontalHeadroom: Math.round(dockIconSize * (dockMaxScale - 1) * 3)

    // Expo (workspace overview) mode. Each workspace card is a scaled-down
    // replica of the monitor itself -- windows sit at their real on-screen
    // position/size (scaled), not in a uniform icon grid -- so every card
    // is this same width regardless of how many windows it holds.
    readonly property int expoPreviewWidth: 300
    readonly property int expoWorkspaceSpacing: 32
    readonly property int expoWorkspacePadding: 14
    readonly property real expoScrimAlpha: 0.55

    // Now-playing widgets flanking the center clock. Art and visualizer are
    // the same size so the cluster stays visually symmetric around the clock.
    readonly property int mediaSquareSize: barHeight - 6
    readonly property int mediaClusterSpacing: 8
    readonly property int visualizerBarCount: 5
    readonly property real visualizerBarWidth: 3
    readonly property real visualizerBarSpacing: 3
}
