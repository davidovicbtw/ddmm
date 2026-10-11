import QtQuick
import Quickshell
import Quickshell.Wayland
import "singletons"

// Invisible strip that keeps tiled windows below the island instead of underneath it.
PanelWindow {
    required property var modelData
    screen: modelData
    anchors { top: true; left: true; right: true }
    implicitHeight: Config.topGap * 2 + Config.idleHeight
    exclusiveZone: Config.topGap * 2 + Config.idleHeight
    color: "transparent"
    mask: Region {}
    WlrLayershell.namespace: "ddmm-strut"
}
