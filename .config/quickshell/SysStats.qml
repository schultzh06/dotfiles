pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Polls scripts/sysstats.sh on a timer and exposes reactive properties plus
// short rolling history buffers used by the sparkline graphs. Centralized
// here (singleton) so multiple monitors' bars share one poller instead of
// each spawning its own.
QtObject {
    id: root

    readonly property int historyLength: 42

    property real cpuPercent: 0
    property var cpuHistory: []

    property real memPercent: 0
    property real memUsedGB: 0
    property real memTotalGB: 0
    property var memHistory: []

    property real cpuTempC: 0

    property string netKind: "offline" // "ethernet" | "wifi" | "offline"
    property string netName: ""
    property string netIface: ""
    property string netAddr: ""

    property var _prevTotal: null
    property var _prevIdle: null

    function _pushHistory(arr, val) {
        var a = arr.slice();
        a.push(val);
        if (a.length > root.historyLength) a.shift();
        return a;
    }

    function _parse(output) {
        var lines = output.split("\n");
        var fields = lines[0].trim().split(/\s+/).map(Number);
        if (fields.length < 11) return;

        var u = fields[0], n = fields[1], s = fields[2], i = fields[3],
            wa = fields[4], irq = fields[5], softirq = fields[6], steal = fields[7];
        var memUsed = fields[8], memTotal = fields[9], temp = fields[10];

        var idle = i + wa;
        var total = u + n + s + i + wa + irq + softirq + steal;

        if (root._prevTotal !== null) {
            var dTotal = total - root._prevTotal;
            var dIdle = idle - root._prevIdle;
            var pct = dTotal > 0 ? 100 * (1 - dIdle / dTotal) : 0;
            pct = Math.max(0, Math.min(100, pct));
            root.cpuPercent = pct;
            root.cpuHistory = root._pushHistory(root.cpuHistory, pct);
        }
        root._prevTotal = total;
        root._prevIdle = idle;

        root.memUsedGB = memUsed;
        root.memTotalGB = memTotal;
        var memPct = memTotal > 0 ? (100 * memUsed / memTotal) : 0;
        root.memPercent = memPct;
        root.memHistory = root._pushHistory(root.memHistory, memPct);

        root.cpuTempC = temp;

        if (lines.length > 1) {
            var net = lines[1].trim().split(/\s+/);
            root.netKind = net[0] || "offline";
            root.netName = net.slice(1).join(" ");
        }
        if (lines.length > 2) {
            var detail = lines[2].trim().split(/\s+/);
            root.netIface = detail[0] === "-" ? "" : (detail[0] || "");
            root.netAddr = detail[1] === "-" ? "" : (detail[1] || "");
        }
    }

    property Process poller: Process {
        id: poller
        command: ["bash", Quickshell.shellPath("scripts/sysstats.sh")]
        stdout: StdioCollector {
            onStreamFinished: root._parse(this.text)
        }
    }

    property Timer timer: Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: poller.running = true
    }
}
