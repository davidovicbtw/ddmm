import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Bluetooth
import "../singletons"

Item {
    id: root
    property bool ownsWheel: false
    readonly property var bt: Bluetooth.defaultAdapter
    property bool modeOpen: false
    property bool confirmGame: false
    onModeOpenChanged: confirmGame = false
    readonly property var modes: [
        { id: "saver", t: "Power saver", d: "Longest battery life", g: "\uf06c" },
        { id: "balanced", t: "Balanced", d: "Good battery life, good performance", g: "\uf24e" },
        { id: "performance", t: "Performance", d: "Fans spin up, best speed", g: "\uf135" },
        { id: "game", t: "Game", d: "Max performance, animations and blur off", g: "\uf11b" }
    ]
    function modeActive(id) { return id === "game" ? Sys.game : (!Sys.game && Sys.profile === ({ saver: "power-saver", balanced: "balanced", performance: "performance" })[id]); }
    Component.onCompleted: Brightness.refresh()
    SystemClock { id: clk; precision: SystemClock.Minutes }
    readonly property date today: clk.date

    Item {
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        width: parent.width - 290
        Text {
            id: big
            y: -10
            text: Qt.formatTime(root.today, Config.clock24 ? "HH:mm" : "h:mm")
            color: Theme.fg
            font.family: Theme.serif; font.pixelSize: 124; font.letterSpacing: -3
        }
        Text {
            anchors { left: parent.left; leftMargin: 4; top: big.bottom; topMargin: -14 }
            text: Qt.formatDate(root.today, "dddd, d MMMM").toUpperCase()
            color: Theme.dim
            font.family: Theme.font; font.pixelSize: 11; font.letterSpacing: 2.2; font.weight: Font.Medium
        }
        // workspaces: numerals, current one underlined
        Row {
            anchors { left: parent.left; leftMargin: 4; bottom: parent.bottom }
            spacing: 18
            Repeater {
                model: 5
                Item {
                    required property int index
                    readonly property int wid: index + 1
                    readonly property bool focused: !!Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === wid
                    readonly property bool used: !!Hyprland.workspaces.values.find(w => w.id === wid)
                    width: 14; height: 22
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: parent.wid
                        color: parent.focused ? Theme.fg : parent.used ? Theme.dim : Qt.rgba(1, 1, 1, 0.22)
                        font.family: Theme.mono; font.pixelSize: 13
                        Behavior on color { ColorAnimation { duration: 180 } }
                    }
                    Rectangle {
                        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
                        height: 2; radius: 1; color: Theme.accent
                        width: parent.focused ? 14 : 0
                        Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                    }
                    MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = \"" + parent.wid + "\" })") }
                }
            }
        }
    }

    component Tile: Item {
        id: t
        property string glyph: ""
        property string label: ""
        property string sub: ""
        property bool on: false
        signal clicked()
        width: 136; height: 62
        Rectangle { anchors.fill: parent; radius: 20; color: t.on ? Theme.fg : (ma.containsMouse ? Theme.cardHover : Theme.card)
            Behavior on color { ColorAnimation { duration: 180 } } }
        Text { x: 16; y: 12; text: t.glyph; color: t.on ? Theme.accentText : Theme.fg; font.family: Theme.icons; font.pixelSize: 15 }
        Text { x: 16; y: 32; width: parent.width - 28; elide: Text.ElideRight; text: t.label; color: t.on ? Theme.accentText : Theme.fg; font.family: Theme.font; font.pixelSize: 12; font.weight: Font.Medium }
        Text { x: 16; y: 46; width: parent.width - 28; elide: Text.ElideRight; text: t.sub; color: t.on ? Qt.rgba(0, 0, 0, 0.55) : Theme.dim; font.family: Theme.font; font.pixelSize: 10 }
        scale: ma.pressed ? 0.97 : 1
        Behavior on scale { NumberAnimation { duration: 110 } }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: t.clicked() }
    }
    component Slider: Item {
        id: sl
        property string glyph: ""
        property real value: 0
        signal moved(real v)
        width: parent.width; height: 24
        Text { width: 22; anchors.verticalCenter: parent.verticalCenter; text: sl.glyph; color: Theme.dim; font.family: Theme.icons; font.pixelSize: 13 }
        Item { id: track; x: 30; width: parent.width - 30 - 34; height: parent.height
            Rectangle { anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter } height: 3; radius: 1.5; color: Theme.faint
                Rectangle { width: parent.width * Math.max(0, Math.min(1, sl.value)); height: 3; radius: 1.5; color: Theme.fg } }
            MouseArea { anchors.fill: parent
                onPressed: m => sl.moved(m.x / track.width)
                onPositionChanged: m => { if (pressed) sl.moved(m.x / track.width); } } }
        Text { anchors { right: parent.right; verticalCenter: parent.verticalCenter } width: 30; horizontalAlignment: Text.AlignRight
            text: Math.round(sl.value * 100); color: Theme.dim; font.family: Theme.mono; font.pixelSize: 11 }
    }

    // status: wifi, battery, bluetooth, dnd, volume, brightness
    Item {
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
        width: 276
        Grid {
            columns: 2; columnSpacing: 4; rowSpacing: 4
            Tile { glyph: "\uf1eb"; label: "Wi-Fi"; sub: Sys.wifi ? (Sys.ssid || "Not connected") : "Off"; on: Sys.wifi && Sys.ssid !== ""
                onClicked: Ui.setPage(2) }
            Tile { glyph: Sys.charging ? "\uf0e7" : "\uf240"; label: Sys.hasBattery ? Math.round(Sys.percent) + "%" : "AC power"
                sub: (Sys.game ? "Game" : ({ "power-saver": "Power saver", balanced: "Balanced", performance: "Performance" })[Sys.profile] || "") + (Sys.charging ? " · charging" : ""); on: Sys.charging; onClicked: root.modeOpen = true }
            Tile { glyph: "\uf293"; label: "Bluetooth"; sub: root.bt && root.bt.enabled ? "On" : "Off"; on: !!root.bt && root.bt.enabled
                onClicked: { if (root.bt) root.bt.enabled = !root.bt.enabled; } }
            Tile { glyph: "\uf1f6"; label: "Do not disturb"; sub: Notifs.dnd ? "On" : "Off"; on: Notifs.dnd; onClicked: Notifs.dnd = !Notifs.dnd }
        }
        Column {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            spacing: 10
            Slider { glyph: Audio.muted ? "\uf6a9" : "\uf028"; value: Audio.muted ? 0 : Audio.volume; onMoved: v => Audio.setVolume(v) }
            Slider { glyph: "\uf185"; value: Brightness.value; onMoved: v => Brightness.set(v) }
        }
    }
    // ---- power mode picker (covers the page)
    Item {
        id: modeView
        anchors.fill: parent
        opacity: root.modeOpen ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 180 } }
        Rectangle { anchors.fill: parent; color: Theme.bg }
        MouseArea { anchors.fill: parent }
        Item {
            id: mh
            width: parent.width; height: 30
            Rectangle { width: 30; height: 30; radius: 15; color: mbma.containsMouse ? Theme.cardHover : Theme.card
                Text { anchors.centerIn: parent; text: "\uf053"; color: Theme.fg; font.family: Theme.icons; font.pixelSize: 12 }
                MouseArea { id: mbma; anchors.fill: parent; hoverEnabled: true; onClicked: root.modeOpen = false } }
            Text { x: 42; anchors.verticalCenter: parent.verticalCenter; text: "Power mode"; color: Theme.fg; font.family: Theme.font; font.pixelSize: 15; font.weight: Font.Medium }
            Text { anchors { right: parent.right; verticalCenter: parent.verticalCenter } text: Sys.hasBattery ? Math.round(Sys.percent) + "%" + (Sys.charging ? " · charging" : "") : "AC power"
                color: Theme.dim; font.family: Theme.mono; font.pixelSize: 11 }
        }
        Column {
            anchors { left: parent.left; right: parent.right; top: mh.bottom; topMargin: 10 }
            spacing: 4
            Repeater {
                model: root.modes
                Item {
                    id: mr
                    required property var modelData
                    readonly property bool active: root.modeActive(modelData.id)
                    readonly property bool asking: modelData.id === "game" && root.confirmGame
                    width: parent.width; height: 48
                    Rectangle { anchors.fill: parent; radius: 18; color: mr.active ? Theme.fg : (mma.containsMouse ? Theme.cardHover : Theme.card)
                        Behavior on color { ColorAnimation { duration: 160 } } }
                    MouseArea { id: mma; anchors.fill: parent; hoverEnabled: true; enabled: !mr.asking
                        onClicked: {
                            if (mr.modelData.id === "game" && !mr.active) root.confirmGame = true;
                            else { root.confirmGame = false; Sys.setMode(mr.modelData.id); }
                        } }
                    Text { x: 22; anchors.verticalCenter: parent.verticalCenter; width: 22; text: mr.modelData.g; color: mr.active ? Theme.accentText : Theme.fg; font.family: Theme.icons; font.pixelSize: 17 }
                    Column { x: 62; anchors.verticalCenter: parent.verticalCenter; spacing: 2; visible: !mr.asking
                        Text { text: mr.modelData.t; color: mr.active ? Theme.accentText : Theme.fg; font.family: Theme.font; font.pixelSize: 14; font.weight: Font.Medium }
                        Text { text: mr.modelData.d; color: mr.active ? Qt.rgba(0, 0, 0, 0.55) : Theme.dim; font.family: Theme.font; font.pixelSize: 11 } }
                    Text { visible: mr.active; anchors { right: parent.right; rightMargin: 22; verticalCenter: parent.verticalCenter } text: "\uf00c"; color: Theme.accentText; font.family: Theme.icons; font.pixelSize: 14 }
                    // game confirmation
                    Row { visible: mr.asking; x: 62; anchors.verticalCenter: parent.verticalCenter; spacing: 12
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "Switch to Game mode?"; color: Theme.fg; font.family: Theme.font; font.pixelSize: 14; font.weight: Font.Medium } }
                    Row { visible: mr.asking; anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter } spacing: 8
                        Rectangle { width: 70; height: 32; radius: 16; color: cma.containsMouse ? Theme.cardHover : Theme.faint
                            Text { anchors.centerIn: parent; text: "Cancel"; color: Theme.fg; font.family: Theme.font; font.pixelSize: 12 }
                            MouseArea { id: cma; anchors.fill: parent; hoverEnabled: true; onClicked: root.confirmGame = false } }
                        Rectangle { width: 70; height: 32; radius: 16; color: Theme.accent
                            Text { anchors.centerIn: parent; text: "Enable"; color: Theme.accentText; font.family: Theme.font; font.pixelSize: 12; font.weight: Font.Medium }
                            MouseArea { anchors.fill: parent; onClicked: { root.confirmGame = false; Sys.setMode("game"); } } }
                    }
                }
            }
        }
    }
}
