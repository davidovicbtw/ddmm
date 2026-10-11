pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property real value: 1
    property bool available: false

    function set(v) {
        value = Math.max(0.02, Math.min(1, v));
        setProc.command = ["brightnessctl", "-q", "set", Math.round(value * 100) + "%"];
        setProc.running = true;
    }
    function refresh() { getProc.running = true; }
    Process {
        id: getProc
        command: ["brightnessctl", "-m"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split(",");
                if (f.length >= 4) { root.available = true; root.value = parseInt(f[3]) / 100; }
            }
        }
    }
    Process { id: setProc }
}
