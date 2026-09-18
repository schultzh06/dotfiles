import QtQuick
import "../"

// Small animated area/line graph. `values` is an array of 0..100 samples,
// oldest first. Redraws whenever the data changes; the fill itself eases
// toward new values rather than snapping, via animating an internal copy.
Canvas {
    id: root
    property var values: []
    property color lineColor: Theme.accent
    property color fillColor: Theme.alpha(Theme.accent, 0.25)

    property var _display: []

    onValuesChanged: {
        if (root._display.length === 0) {
            root._display = root.values.slice();
        }
        smoothTimer.restart();
    }

    Timer {
        id: smoothTimer
        interval: 16
        repeat: true
        running: false
        property int ticks: 0
        onTriggered: {
            var changed = false;
            var next = root._display.slice();
            var target = root.values;
            var len = Math.max(next.length, target.length);
            for (var i = 0; i < len; i++) {
                var cur = next[i] !== undefined ? next[i] : (target[i] || 0);
                var tgt = target[i] !== undefined ? target[i] : 0;
                var d = tgt - cur;
                if (Math.abs(d) > 0.3) {
                    next[i] = cur + d * 0.28;
                    changed = true;
                } else {
                    next[i] = tgt;
                }
            }
            root._display = next;
            root.requestPaint();
            ticks++;
            if (!changed || ticks > 60) {
                running = false;
                ticks = 0;
            }
        }
    }

    onPaint: {
        var ctx = getContext("2d");
        ctx.reset();
        var data = root._display;
        if (!data || data.length < 2) return;

        var w = width, h = height;
        var n = data.length;
        var stepX = w / (n - 1);

        ctx.beginPath();
        for (var i = 0; i < n; i++) {
            var x = i * stepX;
            var y = h - (Math.max(0, Math.min(100, data[i])) / 100) * h;
            if (i === 0) ctx.moveTo(x, y);
            else ctx.lineTo(x, y);
        }
        ctx.lineTo(w, h);
        ctx.lineTo(0, h);
        ctx.closePath();
        ctx.fillStyle = root.fillColor;
        ctx.fill();

        ctx.beginPath();
        for (var j = 0; j < n; j++) {
            var xx = j * stepX;
            var yy = h - (Math.max(0, Math.min(100, data[j])) / 100) * h;
            if (j === 0) ctx.moveTo(xx, yy);
            else ctx.lineTo(xx, yy);
        }
        ctx.strokeStyle = root.lineColor;
        ctx.lineWidth = 1.4;
        ctx.stroke();
    }
}
