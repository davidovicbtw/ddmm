import QtQuick
import QtQuick.Effects
import Quickshell.Services.Mpris
import "singletons"

// ddmm lock screen. The desktop island falls from the top of the screen, grows into a capsule that holds
// the clock, and turns into the password field the moment you type. A correct password shrinks it back
// and it glides up to exactly where the island lives on the desktop, so lock and desktop are one object.
Item {
    id: root
    property string wallpaper: ""
    property string user: ""
    property bool busy: false
    property bool demo: false
    property bool failed: false
    signal submit(string password)
    signal dismissed()
    signal gone()

    // phases: "drop" (pill at the top) -> "rest" (capsule in the middle) -> typing is just `typing` -> "glide" -> "out"
    property string phase: "drop"
    property bool ok: false
    property string password: ""
    property date now: new Date()
    readonly property bool typing: (password.length > 0 || busy || failed) && !ok
    readonly property bool resting: phase === "rest"
    readonly property bool showRest: resting && !typing && !ok
    readonly property var player: Mpris.players.values.find(x => x.isPlaying) || null
    focus: true

    readonly property real midY: height * 0.40
    // geometry of the desktop island so the hand-off lines up
    readonly property real homeW: Config.idleWidth
    readonly property real homeH: Config.idleHeight
    readonly property real homeY: Config.topGap

    Component.onCompleted: { forceActiveFocus(); dropTimer.start(); }
    Timer { id: dropTimer; interval: 380; onTriggered: root.phase = "rest" }
    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.now = new Date() }

    function fail() { password = ""; failed = true; shake.restart(); failTimer.restart(); }
    function leave() {
        if (ok) return;
        ok = true;
        okTimer.start();
    }
    // 1: tick shows -> 2: glide up to the desktop island position -> 3: fade the screen away
    Timer { id: okTimer; interval: 260; onTriggered: { root.phase = "glide"; glideTimer.start(); } }
    Timer { id: glideTimer; interval: 780; onTriggered: { root.phase = "out"; outTimer.start(); } }
    Timer { id: outTimer; interval: 520; onTriggered: root.gone() }
    Timer { id: failTimer; interval: 1600; onTriggered: root.failed = false }

    readonly property string greeting: {
        const h = now.getHours();
        return h < 5 ? "Still up" : h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening";
    }

    Keys.onPressed: event => {
        if (root.busy || root.ok) return;
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.submit(root.password);
        } else if (event.key === Qt.Key_Backspace) {
            root.password = root.password.slice(0, -1);
        } else if (event.key === Qt.Key_Escape) {
            if (root.password.length) root.password = ""; else if (root.demo) root.dismissed();
        } else if (event.text.length > 0 && event.text.charCodeAt(0) >= 32 && !(event.modifiers & Qt.ControlModifier)) {
            root.password += event.text;
            root.failed = false;
        }
    }

    Rectangle { anchors.fill: parent; color: "#050506" }

    // ------------------------------------------------------------ background
    Item {
        anchors.fill: parent
        Image {
            id: bgImg
            anchors.fill: parent
            source: root.wallpaper ? "file://" + root.wallpaper : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: root.width; sourceSize.height: root.height
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: bgImg
            autoPaddingEnabled: false
            blurEnabled: true; blurMax: 64
            property real p: root.phase === "rest" ? 1 : 0
            Behavior on p { NumberAnimation { duration: 900; easing.type: Easing.InOutCubic } }
            blur: p
            brightness: -0.18 * p
            saturation: -0.1 * p
                    }
        Rectangle {
            anchors.fill: parent
            opacity: root.phase === "rest" ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.InOutCubic } }
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.35) }
                GradientStop { position: 0.5; color: Qt.rgba(0, 0, 0, 0.0) }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.5) }
            }
        }
    }

    // ------------------------------------------------------------ the capsule
    Rectangle {
        id: cap
        readonly property bool home: root.phase === "drop" || root.phase === "glide" || root.phase === "out"
        width: home ? root.homeW : root.ok ? 64 : root.typing ? 360 : 460
        height: home ? root.homeH : root.ok ? 64 : root.typing ? 66 : 190
        radius: Math.min(height / 2, 95)
        x: (root.width - width) / 2
        y: home ? root.homeY : root.typing || root.ok ? root.midY + 62 : root.midY
        color: "#000000"
        border.width: 1
        border.color: root.failed ? Qt.rgba(1, 0.42, 0.37, 0.75) : Qt.rgba(1, 1, 1, 0.07)
        Behavior on border.color { ColorAnimation { duration: 220 } }
        Behavior on width { SpringAnimation { spring: 3.2; damping: 0.5; epsilon: 0.3 } }
        Behavior on height { SpringAnimation { spring: 3.2; damping: 0.55; epsilon: 0.3 } }
        Behavior on y { SpringAnimation { spring: 2.6; damping: 0.45; epsilon: 0.3 } }
        clip: true
        transform: Translate { id: shakeT }
        SequentialAnimation {
            id: shake
            NumberAnimation { target: shakeT; property: "x"; to: -16; duration: 55 }
            NumberAnimation { target: shakeT; property: "x"; to: 13; duration: 70 }
            NumberAnimation { target: shakeT; property: "x"; to: -9; duration: 70 }
            NumberAnimation { target: shakeT; property: "x"; to: 5; duration: 60 }
            NumberAnimation { target: shakeT; property: "x"; to: 0; duration: 60 }
        }

        // tiny pill state: the clock, like the desktop island
        Text {
            anchors.centerIn: parent
            opacity: cap.home ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 140 } }
            text: Qt.formatTime(root.now, Config.clock24 ? "HH:mm" : "h:mm AP")
            color: Theme.fg; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.Medium
        }

        // resting capsule: lock, clock, date
        Item {
            width: 460; height: 190
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top }
            opacity: root.showRest ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: root.showRest ? 420 : 70 } }
            Row {
                id: lockRow
                anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 22 }
                spacing: 7
                Text { anchors.verticalCenter: parent.verticalCenter; text: ""; color: Theme.dim; font.family: Theme.icons; font.pixelSize: 10 }
                Text { anchors.verticalCenter: parent.verticalCenter; text: "LOCKED"; color: Theme.dim; font.family: Theme.font; font.pixelSize: 9; font.letterSpacing: 2.6; font.weight: Font.Medium }
            }
            Row {
                id: timeRow
                anchors { horizontalCenter: parent.horizontalCenter; top: lockRow.bottom; topMargin: -6 }
                Text { text: Qt.formatTime(root.now, "HH"); color: Theme.fg; font.family: Theme.serif; font.pixelSize: 92; font.letterSpacing: -2 }
                Text {
                    text: ":"; color: Theme.fg; font.family: Theme.serif; font.pixelSize: 92
                    topPadding: -4
                    SequentialAnimation on opacity { running: root.resting; loops: Animation.Infinite
                        NumberAnimation { to: 0.25; duration: 900; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine } }
                }
                Text { text: Qt.formatTime(root.now, "mm"); color: Theme.fg; font.family: Theme.serif; font.pixelSize: 92; font.letterSpacing: -2 }
            }
            Text {
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 16 }
                text: Qt.formatDate(root.now, "dddd, d MMMM")
                color: Theme.dim; font.family: Theme.serif; font.italic: true; font.pixelSize: 21
            }
        }

        // typing: password dots
        Item {
            width: 360; height: 66
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top }
            opacity: root.typing ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 180 } }
            Text {
                anchors.centerIn: parent
                visible: root.password.length === 0 && !root.busy
                text: root.failed ? "Try again" : "Password"
                color: root.failed ? Theme.danger : Theme.dim
                font.family: Theme.serif; font.italic: true; font.pixelSize: 24
            }
            Row {
                anchors.centerIn: parent
                spacing: Math.max(4, 12 - Math.max(0, root.password.length - 12) * 0.6)
                opacity: root.busy ? 0.4 : 1
                Behavior on opacity { NumberAnimation { duration: 150 } }
                Repeater {
                    model: Math.min(root.password.length, 22)
                    Rectangle {
                        width: 10; height: 10; radius: 5; color: Theme.fg
                        scale: 0
                        Component.onCompleted: scale = 1
                        Behavior on scale { SpringAnimation { spring: 5; damping: 0.28 } }
                    }
                }
            }
            Rectangle {
                visible: root.busy
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 9 }
                height: 2; radius: 1; color: Theme.accent
                SequentialAnimation on width { running: root.busy; loops: Animation.Infinite
                    NumberAnimation { from: 10; to: 110; duration: 600; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 110; to: 10; duration: 600; easing.type: Easing.InOutSine } }
            }
        }

        // accepted
        Text {
            anchors.centerIn: parent
            text: ""; color: Theme.fg; font.family: Theme.icons; font.pixelSize: 22
            opacity: root.ok && root.phase === "rest" ? 1 : 0; visible: opacity > 0.01
            scale: root.ok ? 1 : 0.4
            Behavior on opacity { NumberAnimation { duration: 180 } }
            Behavior on scale { SpringAnimation { spring: 4; damping: 0.3 } }
        }
    }

    // ------------------------------------------------------------ satellites: live activities, privately
    Row {
        id: sats
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.midY + 190 + 26
        spacing: 12
        opacity: root.showRest ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 260 } }

        component Sat: Rectangle {
            id: sat
            property alias glyph: g.text
            property alias label: l.text
            property color glyphColor: Theme.fg
            property int idx: 0
            height: 38; radius: 19; color: "#000000"
            width: row.implicitWidth + 28
            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.07)
            scale: root.showRest ? 1 : 0.6
            Behavior on scale { SequentialAnimation {
                PauseAnimation { duration: root.resting ? 360 + sat.idx * 110 : 0 }
                SpringAnimation { spring: 4.2; damping: 0.3; epsilon: 0.002 } } }
            Row {
                id: row
                anchors.centerIn: parent; spacing: 8
                Text { id: g; anchors.verticalCenter: parent.verticalCenter; color: sat.glyphColor; font.family: Theme.icons; font.pixelSize: 13 }
                Text { id: l; anchors.verticalCenter: parent.verticalCenter; color: Theme.fg; font.family: Theme.font; font.pixelSize: 12; font.weight: Font.Medium
                    elide: Text.ElideRight; width: Math.min(implicitWidth, 230) }
            }
        }

        Sat { idx: 0; visible: !!root.player; glyph: ""; glyphColor: Theme.accent
            label: root.player ? (root.player.trackTitle || "Playing") + (root.player.trackArtist ? "  ·  " + root.player.trackArtist : "") : "" }
        Sat { idx: 1; visible: Notifs.unread > 0; glyph: ""
            label: Notifs.unread + (Notifs.unread === 1 ? " notification" : " notifications") }
        Sat { idx: 2; visible: Sys.hasBattery; glyph: Sys.charging ? "" : ""; glyphColor: Sys.charging ? Theme.accent : Theme.fg
            label: Math.round(Sys.percent) + "%" }
    }

    // ------------------------------------------------------------ footer
    Text {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 54 }
        opacity: root.showRest ? 0.55 : 0
        Behavior on opacity { NumberAnimation { duration: 300 } }
        text: root.greeting + ", " + root.user + "."
        color: Theme.fg; font.family: Theme.serif; font.italic: true; font.pixelSize: 24
    }
    Text {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 28 }
        opacity: root.showRest ? 0.4 : 0
        Behavior on opacity { NumberAnimation { duration: 300 } }
        text: "TYPE TO UNLOCK"
        color: Theme.fg; font.family: Theme.font; font.pixelSize: 10; font.letterSpacing: 3; font.weight: Font.Medium
    }
}
