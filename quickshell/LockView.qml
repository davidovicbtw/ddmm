import QtQuick
import "singletons"

// Picks the lock screen style (setting lockStyle): "apple" (LockApple) or "island" (LockIsland).
Item {
    id: w
    property string wallpaper: ""
    property string shot: ""
    property string user: ""
    property bool busy: false
    property bool demo: false
    property string password: ""
    onPasswordChanged: if (vl.item && vl.item.password !== password) vl.item.password = password
    signal submit(string password)
    signal dismissed()
    signal gone()
    function fail() { if (vl.item) vl.item.fail(); }
    function leave() { if (vl.item) vl.item.leave(); }

    readonly property bool island: Config.lockStyle === "island"
    Loader {
        id: vl
        anchors.fill: parent
        focus: true
        sourceComponent: w.island ? islandC : appleC
        onLoaded: { item.password = w.password; item.forceActiveFocus(); }
    }
    Component { id: appleC; LockApple {
        wallpaper: w.wallpaper; shot: w.shot; user: w.user; busy: w.busy; demo: w.demo
        onSubmit: pw => w.submit(pw); onDismissed: w.dismissed(); onGone: w.gone()
    } }
    Component { id: islandC; LockIsland {
        wallpaper: w.wallpaper; shot: w.shot; user: w.user; busy: w.busy; demo: w.demo
        onSubmit: pw => w.submit(pw); onDismissed: w.dismissed(); onGone: w.gone()
    } }
}
