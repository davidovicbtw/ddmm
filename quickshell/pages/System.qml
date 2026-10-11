import QtQuick
import Quickshell
import Quickshell.Bluetooth
import "../singletons"

Item {
    id: root
    property bool ownsWheel: false
    readonly property var bt: Bluetooth.defaultAdapter
    property bool wifiOpen: false
    property string pickSsid: ""
    onWifiOpenChanged: { if (wifiOpen) { pickSsid = ""; Sys.wifiMsg = ""; Sys.scanWifi(); } }

    component Stat: Item {
        property string label: ""
        property real value: 0
        property string text: ""
        width: 130; height: 84
        Text { text: parent.text; color: Theme.fg; font.family: Theme.serif; font.pixelSize: 50; font.letterSpacing: -1 }
        Text { y: 56; text: parent.label; color: Theme.dim; font.family: Theme.font; font.pixelSize: 10; font.letterSpacing: 1.8; font.weight: Font.Medium }
        Rectangle { y: 78; width: parent.width - 20; height: 2; radius: 1; color: Theme.faint
            Rectangle { width: parent.width * Math.max(0, Math.min(1, parent.parent.value)); height: 2; radius: 1; color: Theme.fg
                Behavior on width { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } } } }
    }
    component Tile: Item {
        id: t
        property string glyph: ""
        property string label: ""
        property string sub: ""
        property bool on: false
        signal clicked()
        width: 196; height: 62
        Rectangle { anchors.fill: parent; radius: 22; color: t.on ? Theme.fg : (ma.containsMouse ? Theme.cardHover : Theme.card)
            Behavior on color { ColorAnimation { duration: 180 } } }
        Text { x: 20; anchors.verticalCenter: parent.verticalCenter; text: t.glyph; color: t.on ? Theme.accentText : Theme.fg; font.family: Theme.icons; font.pixelSize: 17 }
        Column { x: 52; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 64; spacing: 1
            Text { width: parent.width; elide: Text.ElideRight; text: t.label; color: t.on ? Theme.accentText : Theme.fg; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.Medium }
            Text { width: parent.width; elide: Text.ElideRight; text: t.sub; color: t.on ? Qt.rgba(0, 0, 0, 0.55) : Theme.dim; font.family: Theme.font; font.pixelSize: 11 } }
        scale: ma.pressed ? 0.97 : 1
        Behavior on scale { NumberAnimation { duration: 110 } }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: t.clicked() }
    }

    Row {
        anchors { left: parent.left; right: parent.right; top: parent.top }
        spacing: (width - 4 * 130) / 3
        Stat { label: "PROCESSOR"; value: Sys.cpu; text: Math.round(Sys.cpu * 100) + "%" }
        Stat { label: "MEMORY"; value: Sys.ram; text: Math.round(Sys.ram * 100) + "%" }
        Stat { label: "TEMPERATURE"; value: Sys.temp / 100; text: Sys.temp + "°" }
        Stat { label: Sys.charging ? "CHARGING" : "BATTERY"; value: Sys.percent / 100; text: Sys.hasBattery ? Math.round(Sys.percent) + "%" : "AC" }
    }
    Row {
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; verticalCenterOffset: 22 }
        spacing: (width - 3 * 196) / 2
        Tile { glyph: ""; label: "Wi-Fi"; sub: Sys.wifi ? (Sys.ssid || "On") : "Off"; on: Sys.wifi; onClicked: { if (Sys.wifi) root.wifiOpen = true; else Sys.setWifi(true); } }
        Tile { glyph: ""; label: "Bluetooth"; sub: root.bt && root.bt.enabled ? "On" : "Off"; on: !!root.bt && root.bt.enabled
            onClicked: { if (root.bt) root.bt.enabled = !root.bt.enabled; } }
        Tile { glyph: ""; label: "Do not disturb"; sub: Notifs.dnd ? "On" : "Off"; on: Notifs.dnd; onClicked: Notifs.dnd = !Notifs.dnd }
    }
    Row {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        spacing: 12; height: 24
        Text { anchors.verticalCenter: parent.verticalCenter; width: 22; text: ""; color: Theme.dim; font.family: Theme.icons; font.pixelSize: 14 }
        Item { id: bt2; width: parent.width - 80; height: 24; anchors.verticalCenter: parent.verticalCenter
            Rectangle { anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter } height: 3; radius: 1.5; color: Theme.faint
                Rectangle { width: parent.width * Brightness.value; height: parent.height; radius: 1.5; color: Theme.fg } }
            MouseArea { anchors.fill: parent; enabled: Brightness.available
                onPressed: m => Brightness.set(m.x / bt2.width)
                onPositionChanged: m => { if (pressed) Brightness.set(m.x / bt2.width); } } }
        Text { anchors.verticalCenter: parent.verticalCenter; width: 34; horizontalAlignment: Text.AlignRight; color: Theme.dim; font.family: Theme.mono; font.pixelSize: 11; text: Math.round(Brightness.value * 100) }
    }
    // ---- Wi-Fi network list (covers the page)
    Item {
        id: wifiView
        anchors.fill: parent
        opacity: root.wifiOpen ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 180 } }
        Rectangle { anchors.fill: parent; color: Theme.bg }
        MouseArea { anchors.fill: parent }

        Item {
            id: wh
            width: parent.width; height: 30
            Rectangle { id: back; width: 30; height: 30; radius: 15; color: bma.containsMouse ? Theme.cardHover : Theme.card
                Text { anchors.centerIn: parent; text: "\uf053"; color: Theme.fg; font.family: Theme.icons; font.pixelSize: 12 }
                MouseArea { id: bma; anchors.fill: parent; hoverEnabled: true; onClicked: root.wifiOpen = false } }
            Text { x: 42; anchors.verticalCenter: parent.verticalCenter; text: "Wi-Fi"; color: Theme.fg; font.family: Theme.font; font.pixelSize: 15; font.weight: Font.Medium }
            Text { x: 100; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 260; elide: Text.ElideRight
                text: Sys.scanning ? "Scanning…" : Sys.wifiMsg; color: Theme.dim; font.family: Theme.font; font.pixelSize: 11 }
            Row {
                anchors.right: parent.right; spacing: 8
                Rectangle { width: 30; height: 30; radius: 15; color: rma.containsMouse ? Theme.cardHover : Theme.card
                    Text { anchors.centerIn: parent; text: "\uf021"; color: Theme.fg; font.family: Theme.icons; font.pixelSize: 12 }
                    MouseArea { id: rma; anchors.fill: parent; hoverEnabled: true; onClicked: Sys.scanWifi() } }
                Rectangle { width: 30; height: 30; radius: 15; color: Theme.fg
                    Text { anchors.centerIn: parent; text: "\uf011"; color: Theme.accentText; font.family: Theme.icons; font.pixelSize: 12 }
                    MouseArea { anchors.fill: parent; onClicked: { Sys.setWifi(false); root.wifiOpen = false; } } }
            }
        }
        ListView {
            id: wl
            anchors { left: parent.left; right: parent.right; top: wh.bottom; topMargin: 10; bottom: parent.bottom }
            clip: true; spacing: 4
            boundsBehavior: Flickable.StopAtBounds
            model: Sys.networks
            delegate: Item {
                id: row
                required property var modelData
                readonly property bool picking: root.pickSsid === modelData.ssid
                width: wl.width; height: picking ? 88 : 42
                Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                clip: true
                Rectangle { anchors.fill: parent; radius: 16; color: rowMa.containsMouse ? Theme.cardHover : Theme.card }
                MouseArea { id: rowMa; x: 0; y: 0; width: parent.width; height: 42; hoverEnabled: true
                    onClicked: {
                        if (row.modelData.active) return;
                        if (row.modelData.secure && !row.modelData.known) { root.pickSsid = row.modelData.ssid; pwIn.text = ""; pwIn.forceActiveFocus(); }
                        else Sys.connectWifi(row.modelData.ssid, "");
                    } }
                Text { x: 16; y: 0; height: 42; verticalAlignment: Text.AlignVCenter; text: "\uf1eb"; font.family: Theme.icons; font.pixelSize: 14
                    color: row.modelData.active ? Theme.accent : Theme.fg; opacity: 0.35 + 0.65 * row.modelData.signal / 100 }
                Text { x: 46; y: 0; height: 42; width: parent.width - 150; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
                    text: row.modelData.ssid; color: Theme.fg; font.family: Theme.font; font.pixelSize: 13; font.weight: row.modelData.active ? Font.Medium : Font.Normal }
                Text { anchors { right: parent.right; rightMargin: 16 } y: 0; height: 42; verticalAlignment: Text.AlignVCenter
                    text: (row.modelData.active ? "Connected  " : (row.modelData.known ? "Saved  " : "")) + (row.modelData.secure ? "\uf023" : "")
                    color: row.modelData.active ? Theme.accent : Theme.dim; font.family: Theme.font; font.pixelSize: 11 }
                Rectangle { visible: row.picking; x: 16; y: 48; width: parent.width - 32; height: 30; radius: 15; color: Theme.faint
                    TextInput { id: pwIn; anchors { fill: parent; leftMargin: 14; rightMargin: 14 } verticalAlignment: TextInput.AlignVCenter
                        echoMode: TextInput.Password; color: Theme.fg; font.family: Theme.font; font.pixelSize: 13; clip: true
                        Keys.onReturnPressed: { Sys.connectWifi(row.modelData.ssid, text); root.pickSsid = ""; }
                        Keys.onEscapePressed: root.pickSsid = ""
                        Text { visible: pwIn.text === ""; anchors.verticalCenter: parent.verticalCenter; text: "Password, then Enter"; color: Theme.dim; font: pwIn.font } } }
            }
        }
    }
    Component.onCompleted: Brightness.refresh()
}
