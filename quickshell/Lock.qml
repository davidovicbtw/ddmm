import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import "singletons"

// Session lock (ext-session-lock) with the ddmm look. `demo` shows the same UI in a
// normal overlay window instead (for testing; still authenticates through PAM).
Scope {
    id: root
    property bool demo: false
    property string demoPw: ""
    property string wallpaper: ""
    property string message: ""
    property bool busy: false
    property bool unlocking: false
    readonly property string user: Quickshell.env("USER")
    readonly property bool active: lockLoader.active || demo

    // restore the saved wallpaper when the shell starts (awww-daemon forgets it on restart)
    Process {
        running: true
        command: ["sh", "-c", 'f=$(cat ~/.config/ddmm/wallpaper 2>/dev/null); [ -f "$f" ] || exit 0; for i in 1 2 3 4 5 6 7 8 9 10; do awww img "$f" --transition-type none 2>/dev/null && exit 0; sleep 0.5; done']
    }

    function lockNow() {
        if (active || lockLoader.active) return;
        unlocking = false; message = "";
        wpFile.reload();
        wpQuery.running = true;      // lock starts once the current wallpaper is known
    }
    Process {
        id: wpQuery
        command: ["awww", "query"]
        stdout: StdioCollector {
            onStreamFinished: { const m = text.match(/image: (\/\S.*)/); if (m) root.wallpaper = m[1].trim(); }
        }
        onExited: lockLoader.active = true
    }
    function showDemo() { if (!active) { unlocking = false; message = ""; wpFile.reload(); demo = true; } }
    function finish() { if (!demo) Sounds.play("service-login"); if (lockLoader.item) lockLoader.item.locked = false; demo = false; busy = false; unlocking = false; message = ""; }

    FileView {
        id: wpFile
        path: Quickshell.env("HOME") + "/.config/ddmm/wallpaper"
        printErrors: false
        onLoaded: root.wallpaper = text().trim()
    }

    property string pending: ""
    property int failTick: 0
    PamContext {
        id: pam
        config: "hyprlock"
        user: root.user
        onPamMessage: { if (responseRequired) respond(root.pending); }
        onCompleted: result => {
            root.pending = "";
            root.busy = false;
            if (result === PamResult.Success) root.unlocking = true;
            else root.failTick++;
        }
        onError: { root.busy = false; root.failTick++; }
    }
    function tryPassword(pw) {
        if (busy || unlocking || pw.length === 0) return;
        busy = true; pending = pw;
        if (pam.active) pam.abort();
        pam.start();
    }

    // destroy the lock a moment after it was unlocked; tearing the surface down in the
    // same tick as the unlock aborts quickshell and leaves the session locked
    Timer { id: lockTeardown; interval: 400; running: !root.unlocking && lockLoader.item && !lockLoader.item.locked; onTriggered: lockLoader.active = false }

    Loader {
        id: lockLoader
        active: false
        sourceComponent: WlSessionLock {
            id: lock
            locked: true
            WlSessionLockSurface {
                color: "#050506"
                LockView {
                    id: view
                    anchors.fill: parent
                    wallpaper: root.wallpaper
                    user: root.user
                    busy: root.busy
                    onSubmit: pw => root.tryPassword(pw)
                    onGone: root.finish()
                    Connections { target: root; function onFailTickChanged() { view.fail(); } function onUnlockingChanged() { if (root.unlocking) view.leave(); } }
                }
            }
        }
    }

    Variants {
        model: root.demo ? Quickshell.screens : []
        delegate: PanelWindow {
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "black"
            WlrLayershell.namespace: "ddmm-lock-demo"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            LockView {
                id: dview
                anchors.fill: parent
                demo: true
                Component.onCompleted: password = root.demoPw
                wallpaper: root.wallpaper
                user: root.user
                busy: root.busy
                onSubmit: pw => root.tryPassword(pw)
                onDismissed: dview.leave()
                onGone: root.finish()
                Connections { target: root; function onFailTickChanged() { dview.fail(); } function onUnlockingChanged() { if (root.unlocking) dview.leave(); } }
            }
        }
    }
}
