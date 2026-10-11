//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import "singletons"

ShellRoot {
    Variants {
        model: Quickshell.screens.length > 0 ? [Quickshell.screens[0]] : []
        delegate: Component {
            Scope {
                id: scope
                required property var modelData
                Strut { modelData: scope.modelData }
                Island { screen: scope.modelData }
            }
        }
    }

    Lock { id: lockScreen }

    IpcHandler {
        target: "ddmm"
        function ping(): string { return "pong"; }
        function open(): void { Ui.pinned = true; }
        function close(): void { Ui.close(); }
        function toggle(): void { Ui.toggle(); }
        function home(): void { if (Ui.spotlight || Ui.walls || Ui.powerMenu || Ui.flashOn || Ui.osdOn || Date.now() - Ui.stamp < 900) return; Ui.openPage("home"); }
        function homeToggle(): void { Ui.openPage("home"); }
        function page(n: int): void { Ui.setPage(n); Ui.pinned = true; }
        function launcher(text: string): void { Ui.openSpotlight(text); }
        function wallpaper(): void { Ui.toggleWalls(); }
        function power(): void { Ui.togglePowerMenu(); }
        function media(): void { Ui.openPage("media"); }
        function lock(): void { lockScreen.lockNow(); }
        function lockscreen(): void { lockScreen.lockNow(); }
        function lockdemo(text: string): void { lockScreen.demoPw = text; lockScreen.showDemo(); }
        function osd(kind: string): void { if (kind === "bright") { Brightness.refresh(); Ui.showOsd("bright", Brightness.value); } }
    }
}
