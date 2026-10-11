import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import "../singletons"

Item {
    id: root
    property bool ownsWheel: false
    readonly property var player: Mpris.players.values.find(x => x.isPlaying) || Mpris.players.values[0] || null
    readonly property bool playing: !!player && player.isPlaying

    function fmt(s) { s = Math.max(0, Math.floor(s || 0)); return Math.floor(s / 60) + ":" + (s % 60 < 10 ? "0" : "") + (s % 60); }
    Timer { interval: 1000; repeat: true; running: root.playing; onTriggered: if (root.player && root.player.positionSupported) root.player.positionChanged() }

    Rectangle {
        id: art
        width: 150; height: 150; radius: 24; color: Theme.card; clip: true
        anchors { left: parent.left; top: parent.top }
        Image { anchors.fill: parent; source: root.player ? root.player.trackArtUrl : ""; fillMode: Image.PreserveAspectCrop; visible: status === Image.Ready; sourceSize: Qt.size(300, 300) }
        Text { anchors.centerIn: parent; text: ""; color: Theme.dim; font.family: Theme.icons; font.pixelSize: 38; visible: !root.player }
    }

    Item {
        anchors { left: art.right; leftMargin: 28; right: parent.right; top: parent.top; bottom: parent.bottom }
        Column {
            width: parent.width; spacing: 4
            Text { width: parent.width; elide: Text.ElideRight; color: Theme.fg; font.family: Theme.font; font.pixelSize: 22; font.weight: Font.Medium; font.letterSpacing: -0.4
                text: root.player ? (root.player.trackTitle || root.player.identity || "Unknown") : "Nothing playing" }
            Text { width: parent.width; elide: Text.ElideRight; color: Theme.dim; font.family: Theme.serif; font.italic: true; font.pixelSize: 19
                text: root.player ? (root.player.trackArtist || "") : "Start something to see it here" }
        }

        // progress
        Item {
            id: prog
            anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 78 }
            height: 22
            readonly property real frac: root.player && root.player.length > 0 ? Math.min(1, root.player.position / root.player.length) : 0
            Rectangle { id: line; anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 4 } height: 3; radius: 1.5; color: Theme.faint
                Rectangle { width: parent.width * prog.frac; height: parent.height; radius: 1.5; color: Theme.fg
                    Behavior on width { NumberAnimation { duration: 900; easing.type: Easing.Linear } } } }
            Text { anchors { left: parent.left; bottom: parent.bottom } text: root.fmt(root.player ? root.player.position : 0); color: Theme.dim; font.family: Theme.mono; font.pixelSize: 10 }
            Text { anchors { right: parent.right; bottom: parent.bottom } text: root.fmt(root.player ? root.player.length : 0); color: Theme.dim; font.family: Theme.mono; font.pixelSize: 10 }
            MouseArea { anchors.fill: parent; enabled: !!root.player && root.player.canSeek
                onClicked: m => { root.player.position = root.player.length * Math.max(0, Math.min(1, m.x / width)); } }
        }

        // transport
        Row {
            anchors { left: parent.left; top: parent.top; topMargin: 118 }
            spacing: 22
            Repeater {
                model: [0, 1, 2]
                Item {
                    required property int modelData
                    width: modelData === 1 ? 44 : 30; height: 44
                    Rectangle { visible: parent.modelData === 1; anchors.centerIn: parent; width: 44; height: 44; radius: 22; color: Theme.fg
                        scale: ma.pressed ? 0.92 : 1; Behavior on scale { NumberAnimation { duration: 120 } } }
                    Text { anchors.centerIn: parent; font.family: Theme.icons
                        font.pixelSize: parent.modelData === 1 ? 15 : 16
                        color: parent.modelData === 1 ? Theme.accentText : (ma.containsMouse ? Theme.fg : Theme.dim)
                        text: parent.modelData === 0 ? "" : parent.modelData === 2 ? "" : (root.playing ? "" : "") }
                    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true
                        onClicked: { if (!root.player) return; const a = parent.modelData; if (a === 0) root.player.previous(); else if (a === 1) root.player.togglePlaying(); else root.player.next(); } }
                }
            }
        }
    }

    // volume
    Row {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        spacing: 12; height: 24
        Text { anchors.verticalCenter: parent.verticalCenter; width: 22; color: Theme.dim; font.family: Theme.icons; font.pixelSize: 14
            text: Audio.muted || Audio.volume <= 0.001 ? "" : ""
            MouseArea { anchors.fill: parent; onClicked: Audio.toggleMute() } }
        Item {
            id: track
            width: parent.width - 80; height: 24; anchors.verticalCenter: parent.verticalCenter
            Rectangle { anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter } height: 3; radius: 1.5; color: Theme.faint
                Rectangle { width: parent.width * Math.min(1, Audio.volume); height: parent.height; radius: 1.5; color: Audio.muted ? Theme.dim : Theme.fg } }
            MouseArea { anchors.fill: parent
                onPressed: m => Audio.setVolume(m.x / track.width)
                onPositionChanged: m => { if (pressed) Audio.setVolume(m.x / track.width); } }
        }
        Text { anchors.verticalCenter: parent.verticalCenter; width: 34; horizontalAlignment: Text.AlignRight; color: Theme.dim; font.family: Theme.mono; font.pixelSize: 11
            text: Math.round(Audio.volume * 100) }
    }
}
