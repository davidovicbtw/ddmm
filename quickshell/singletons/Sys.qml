pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

Singleton {
    id: root
    readonly property var bat: UPower.displayDevice
    readonly property bool hasBattery: bat && bat.isLaptopBattery
    readonly property real percent: bat ? bat.percentage * (bat.percentage <= 1 ? 100 : 1) : 0
    readonly property bool charging: bat ? (bat.state === UPowerDeviceState.Charging || bat.state === UPowerDeviceState.FullyCharged) : false
    // polled only while `watch` is true (island open on the system page)
    property bool watch: false
    property real cpu: 0
    property real ram: 0
    property int temp: 0
    property string profile: "power-saver"
    property bool game: false
    property bool wifi: true
    property string ssid: ""
    property var networks: []           // {ssid, signal, secure, active, known}
    property bool scanning: false
    property string wifiMsg: ""
    // battery life estimate per mode: measured draw (W) while discharging, learned per mode and kept on disk
    property real energyNow: 0          // Wh
    property real energyFull: 0
    property real drawNow: 0            // W, only meaningful while discharging
    property bool discharging: false
    property var learned: ({})          // mode key -> smoothed watts
    property int _samples: 0
    readonly property var modeFactor: ({ saver: 0.75, balanced: 1.0, performance: 1.35, game: 1.7 })
    readonly property string curMode: game ? "game" : ({ "power-saver": "saver", balanced: "balanced", performance: "performance" })[profile] || "balanced"
    function drawFor(m) {
        if (learned[m] > 0) return learned[m];
        const c = learned[curMode];
        if (c > 0) return c / modeFactor[curMode] * modeFactor[m];
        return 8 * modeFactor[m];       // no data yet: guess from a typical laptop
    }
    function hoursFor(m) { return energyNow > 0 ? energyNow / Math.max(1.5, drawFor(m)) : 0; }
    function fmtHours(h) {
        if (!(h > 0)) return "";
        const t = Math.round(h * 60), hh = Math.floor(t / 60), mm = t % 60;
        return hh > 0 ? hh + "h " + (mm < 10 ? "0" : "") + mm + "m" : mm + "m";
    }
    function sampleDraw() {
        if (!discharging || drawNow < 1.5 || drawNow > 80) return;
        const k = curMode, l = Object.assign({}, learned);
        l[k] = l[k] > 0 ? l[k] * 0.85 + drawNow * 0.15 : drawNow;
        learned = l;
        if (++_samples % 10 === 0) run("mkdir -p ~/.config/ddmm; printf '%s' '" + JSON.stringify(l) + "' > ~/.config/ddmm/powerlearn.json");
    }
    Process {
        running: true
        command: ["sh", "-c", "cat ~/.config/ddmm/powerlearn.json 2>/dev/null || echo '{}'"]
        stdout: StdioCollector { onStreamFinished: { try { root.learned = JSON.parse(text.trim() || "{}"); } catch (e) {} } }
    }
    property real _idle: 0
    property real _total: 0

    function run(cmd) { Quickshell.execDetached(["sh", "-c", cmd]); }
    function setWifi(on) { run("nmcli radio wifi " + (on ? "on" : "off")); wifi = on; }
    function scanWifi() { if (scanning) return; scanning = true; scan.running = true; }
    function connectWifi(ssid, pw) {
        wifiMsg = "Connecting to " + ssid + "…";
        conn.command = pw ? ["nmcli", "dev", "wifi", "connect", ssid, "password", pw] : ["nmcli", "dev", "wifi", "connect", ssid];
        conn.running = true;
    }
    function setMode(m) { run("$HOME/.local/bin/ddmm-power " + m); game = m === "game"; if (m !== "game") profile = ({ saver: "power-saver", balanced: "balanced", performance: "performance" })[m]; else profile = "performance"; repoll.restart(); }
    Timer { id: repoll; interval: 900; onTriggered: poll.running = true }   // re-read only after ddmm-power has finished, else the old profile flickers back
    function lock() { run("qs -p $HOME/.config/quickshell/ddmm ipc call ddmm lockscreen"); }

    Timer {
        interval: 2000; running: root.watch; repeat: true; triggeredOnStart: true
        onTriggered: poll.running = true
    }
    Process {
        id: poll
        command: ["sh", "-c", "head -1 /proc/stat; grep -E '^(MemTotal|MemAvailable)' /proc/meminfo; for f in /sys/class/thermal/thermal_zone*/temp; do cat $f; break; done; powerprofilesctl get; test -e ${XDG_RUNTIME_DIR:-/run/user/$UID}/ddmm-game && echo 1 || echo 0; nmcli -t -f WIFI g; b=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -1); echo $(cat $b/power_now $b/energy_now $b/energy_full $b/status 2>/dev/null); nmcli -t -f active,ssid dev wifi | grep '^yes' | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const L = text.trim().split("\n");
                const c = L[0].split(/\s+/).slice(1).map(Number);
                const idle = c[3] + (c[4] || 0), total = c.reduce((a, b) => a + b, 0);
                if (root._total > 0 && total > root._total) root.cpu = 1 - (idle - root._idle) / (total - root._total);
                root._idle = idle; root._total = total;
                const mt = parseInt(L[1].split(/\s+/)[1]), ma = parseInt(L[2].split(/\s+/)[1]);
                root.ram = 1 - ma / mt;
                root.temp = Math.round((parseInt(L[3]) || 0) / 1000);
                root.profile = L[4] || root.profile;
                root.game = L[5] === "1";
                root.wifi = (L[6] || "") === "enabled";
                const B = (L[7] || "").split(" ");
                root.drawNow = (parseInt(B[0]) || 0) / 1e6;
                root.energyNow = (parseInt(B[1]) || 0) / 1e6;
                root.energyFull = (parseInt(B[2]) || 0) / 1e6;
                root.discharging = B[3] === "Discharging";
                root.sampleDraw();
                root.ssid = L[8] ? L[8].split(":")[1] : "";
            }
        }
    }
    Process {
        id: scan
        command: ["sh", "-c", "nmcli -t -f NAME con show; echo @@; nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID dev wifi list --rescan auto"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("\n@@\n");
                const known = (parts[0] || "").split("\n");
                const seen = {}, out = [];
                for (const line of (parts[1] || "").split("\n")) {
                    const m = line.match(/^([^:]*):([^:]*):([^:]*):(.*)$/);
                    if (!m || !m[4]) continue;
                    const ssid = m[4].replace(/\\:/g, ":");
                    const o = { ssid: ssid, signal: parseInt(m[2]) || 0, secure: m[3] !== "" && m[3] !== "--", active: m[1] === "*", known: known.indexOf(ssid) >= 0 };
                    if (seen[ssid] !== undefined) { if (o.active || o.signal > out[seen[ssid]].signal) out[seen[ssid]] = o; continue; }
                    seen[ssid] = out.length; out.push(o);
                }
                out.sort((a, b) => (b.active - a.active) || (b.signal - a.signal));
                root.networks = out;
                root.scanning = false;
            }
        }
    }
    Process {
        id: conn
        stdout: StdioCollector {}
        stderr: StdioCollector { id: connErr }
        onExited: code => {
            root.wifiMsg = code === 0 ? "" : (connErr.text.trim().split("\n")[0] || "Could not connect");
            if (code === 0) Sounds.play("network-connectivity-established");
            root.scanWifi(); poll.running = true;
        }
    }
    Process { id: runner }
}
