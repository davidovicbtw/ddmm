pragma Singleton
import QtQuick
import Quickshell

Singleton {
    readonly property color bg: Qt.rgba(0, 0, 0, Config.opacity)
    readonly property color fg: "#f4f1ea"
    readonly property color dim: Qt.rgba(0.957, 0.945, 0.918, 0.5)
    readonly property color faint: Qt.rgba(0.957, 0.945, 0.918, 0.12)
    readonly property color card: Qt.rgba(0.957, 0.945, 0.918, 0.07)
    readonly property color cardHover: Qt.rgba(0.957, 0.945, 0.918, 0.14)
    readonly property color accent: Config.accent
    readonly property color accentText: "#14110d"
    readonly property color danger: "#ff6b5e"
    readonly property string font: "Geist"
    readonly property string serif: "Instrument Serif"
    readonly property string mono: "Geist Mono"
    readonly property string icons: "JetBrainsMono Nerd Font"
    readonly property int dur: Config.animations ? 420 : 0
    readonly property int durFast: Config.animations ? 160 : 0
}
