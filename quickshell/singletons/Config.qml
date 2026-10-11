pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Settings live in ~/.config/ddmm/settings.json (edited by the `ddmm` CLI).
Singleton {
    id: root
    property string accent: adapter.accent
    property real opacity: adapter.opacity
    property int idleWidth: adapter.idleWidth
    property int idleHeight: adapter.idleHeight
    property int openWidth: adapter.openWidth
    property int openHeight: adapter.openHeight
    property int topGap: adapter.topGap
    property int closeDelay: adapter.closeDelay
    property bool clock24: adapter.clock24
    property bool seconds: adapter.seconds
    property bool animations: adapter.animations
    property bool notifications: adapter.notifications
    property string terminal: adapter.terminal
    property string search: adapter.search
    property string wallDir: adapter.wallDir
    property bool invertScroll: adapter.invertScroll
    property int swipeDistance: adapter.swipeDistance
    property bool liveActivities: adapter.liveActivities
    property bool sounds: adapter.sounds
    property real soundVolume: adapter.soundVolume

    FileView {
        path: Quickshell.env("HOME") + "/.config/ddmm/settings.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        adapter: JsonAdapter {
            id: adapter
            property string accent: "#ff8a4c"
            property real opacity: 1.0
            property int idleWidth: 96
            property int idleHeight: 30
            property int openWidth: 680
            property int openHeight: 340
            property int topGap: 6
            property int closeDelay: 250
            property bool clock24: true
            property bool seconds: false
            property bool animations: true
            property bool notifications: true
            property string terminal: "kitty"
            property string search: "https://www.google.com/search?q="
            property string wallDir: "~/Pictures/Wallpapers"
            property bool invertScroll: false
            property int swipeDistance: 110
            property bool liveActivities: true
            property bool sounds: true
            property real soundVolume: 0.6
        }
    }
}
