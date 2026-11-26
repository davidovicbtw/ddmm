import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "singletons"

// Apple-style lock screen: big thin clock under a padlock, avatar + glass password field at the bottom.
// Unlock: the padlock pops open, the lock UI swells and fades away, the wallpaper un-blurs and the
// desktop (grabbed just before locking) settles back in from slightly zoomed. Locking plays it in reverse.
Item {
    id: root
    property string wallpaper: ""
    property string shot: ""
    property string user: ""
    property bool busy: false
    property bool demo: false
    property bool failed: false
    signal submit(string password)
    signal dismissed()
    signal gone()

    // phases: "in" (desktop blurs into the lock) -> "rest" -> (ok) "open" (padlock opens) -> "out" (zoom back to desktop)
    property string phase: "in"
    property bool ok: false
    property string password: ""
    property date now: new Date()
    property int tries: 0
    readonly property bool typing: password.length > 0 || busy
    readonly property bool locked: phase === "in" || phase === "rest"
    focus: true

    Component.onCompleted: { forceActiveFocus(); inTimer.start(); }
    Timer { id: inTimer; interval: 60; onTriggered: root.phase = "rest" }
    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.now = new Date() }

    function fail() { tries++; password = ""; failed = true; shake.restart(); failTimer.restart(); }
    function leave() { if (ok) return; ok = true; phase = "open"; outTimer.start(); }
    Timer { id: outTimer; interval: 520; onTriggered: { root.phase = "out"; doneTimer.start(); } }
    Timer { id: doneTimer; interval: 780; onTriggered: root.gone() }
    Timer { id: failTimer; interval: 1500; onTriggered: root.failed = false }

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

    // ------------------------------------------------------------ wallpaper: blurs in on lock, sharpens on unlock
    Item {
        anchors.fill: parent
        scale: root.phase === "out" ? 1.0 : root.locked ? 1.0 : 1.03
        Behavior on scale { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
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
            property real p: root.locked || root.phase === "open" ? 1 : 0
            Behavior on p { NumberAnimation { duration: root.phase === "out" ? 700 : 800; easing.type: Easing.InOutCubic } }
            blur: p * Config.lockBlur * 0.55
            brightness: -Config.lockDim * p
            saturation: 0.12 * p
        }
        Rectangle {
            anchors.fill: parent
            opacity: root.locked ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 600 } }
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.22) }
                GradientStop { position: 0.45; color: Qt.rgba(0, 0, 0, 0.0) }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.45) }
            }
        }
    }

    // the desktop as locked: dissolves out on lock, settles back in (from slightly zoomed) on unlock
    Image {
        anchors.fill: parent
        source: root.shot ? "file://" + root.shot : ""
        fillMode: Image.Stretch
        cache: false
        visible: status === Image.Ready && opacity > 0.01
        opacity: root.phase === "rest" || root.phase === "open" ? 0 : 1
        scale: root.phase === "out" ? 1.0 : root.phase === "in" ? 1.0 : 1.05
        Behavior on opacity { NumberAnimation { duration: root.phase === "out" ? 620 : 520; easing.type: Easing.InOutQuad } }
        Behavior on scale { NumberAnimation { duration: 780; easing.type: Easing.OutCubic } }
    }

    // ------------------------------------------------------------ lock UI (swells and fades on unlock)
    Item {
        id: ui
        anchors.fill: parent
        opacity: root.phase === "rest" || root.phase === "open" ? 1 : 0
        scale: root.phase === "out" ? 1.14 : root.phase === "in" ? 0.94 : 1.0
        Behavior on opacity { NumberAnimation { duration: root.phase === "out" ? 360 : 520; easing.type: Easing.InOutQuad } }
        Behavior on scale { NumberAnimation { duration: root.phase === "out" ? 620 : 700; easing.type: Easing.OutCubic } }

        // --- padlock
        Item {
            id: lockIcon
            width: 26; height: 32
            x: (root.width - width) / 2
            y: root.height * 0.085
            opacity: 0.9
            transform: Translate { id: lockShake }
            property color c: root.failed ? Theme.danger : "#ffffff"
            Behavior on c { ColorAnimation { duration: 200 } }
            // shackle: lifts and swings open on its right leg
            Rectangle {
                id: shackle
                width: 15; height: 22; radius: 7.5
                x: (parent.width - width) / 2
                y: root.ok ? -3 : 1
                color: "transparent"
                border.width: 2.6; border.color: lockIcon.c
                transform: Rotation { origin.x: shackle.width - 1.3; origin.y: shackle.height; axis { x: 0; y: 0; z: 1 } angle: root.ok ? -34 : 0
                    Behavior on angle { SpringAnimation { spring: 5; damping: 0.32; epsilon: 0.05 } } }
                Behavior on y { SpringAnimation { spring: 5; damping: 0.4; epsilon: 0.05 } }
            }
            Rectangle {
                width: parent.width; height: 18; radius: 4.5
                y: parent.height - height
                color: lockIcon.c
            }
            Rectangle {   // keyhole
                width: 3.5; height: 6; radius: 1.7
                x: (parent.width - width) / 2; y: parent.height - 12
                color: "#1a1a1c"; opacity: 0.55
            }
        }

        // --- date + clock
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.height * 0.085 + 52
            visible: Config.lockDate
            text: Qt.formatDate(root.now, "dddd, d MMMM")
            color: Qt.rgba(1, 1, 1, 0.82)
            font.family: Theme.font; font.pixelSize: Math.round(root.height * 0.026); font.weight: Font.Medium
        }
        Text {
            id: clock
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.height * 0.085 + 52 + Math.round(root.height * 0.026) + 4
            text: Qt.formatTime(root.now, Config.clock24 ? "HH:mm" : "h:mm")
            color: Qt.rgba(1, 1, 1, 0.94)
            font.family: Theme.font; font.pixelSize: Math.round(root.height * 0.15)
            font.weight: Font.Light; font.letterSpacing: -4
            style: Text.Normal
        }

        // --- bottom: avatar, name, field
        Column {
            id: login
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.height * 0.70
            spacing: 12
            transform: Translate { id: shakeT }

            Item {   // avatar
                width: 76; height: 76
                anchors.horizontalCenter: parent.horizontalCenter
                Rectangle {
                    id: avMask
                    anchors.fill: parent; radius: width / 2
                    layer.enabled: true; visible: false
                }
                Rectangle {
                    anchors.fill: parent; radius: width / 2
                    color: Qt.rgba(1, 1, 1, 0.16)
                    border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.22)
                    Text {
                        anchors.centerIn: parent
                        text: root.user ? root.user.charAt(0).toUpperCase() : ""
                        color: "white"; opacity: 0.9
                        font.family: Theme.font; font.pixelSize: 32; font.weight: Font.Medium
                        visible: face.status !== Image.Ready
                    }
                }
                Image {
                    id: face
                    anchors.fill: parent
                    source: "file://" + Quickshell.env("HOME") + "/.face"
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 152; sourceSize.height: 152
                    visible: false
                }
                MultiEffect {
                    anchors.fill: parent
                    source: face
                    maskEnabled: true; maskSource: avMask
                    visible: face.status === Image.Ready
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.user
                color: "white"
                font.family: Theme.font; font.pixelSize: 19; font.weight: Font.Medium
            }

            // glass field
            Rectangle {
                id: field
                width: 250; height: 42; radius: 21
                anchors.horizontalCenter: parent.horizontalCenter
                color: Qt.rgba(1, 1, 1, root.typing ? 0.26 : 0.18)
                border.width: 1
                border.color: root.failed ? Qt.rgba(1, 0.42, 0.37, 0.9) : Qt.rgba(1, 1, 1, root.typing ? 0.38 : 0.24)
                Behavior on color { ColorAnimation { duration: 180 } }
                Behavior on border.color { ColorAnimation { duration: 200 } }

                Text {
                    anchors.centerIn: parent
                    visible: root.password.length === 0 && !root.busy
                    text: root.failed ? "Wrong password" : "Enter Password"
                    color: root.failed ? Theme.danger : Qt.rgba(1, 1, 1, 0.62)
                    font.family: Theme.font; font.pixelSize: 15
                }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 18
                    spacing: 7
                    opacity: root.busy ? 0.45 : 1
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                    Repeater {
                        model: Math.min(root.password.length, 14)
                        Rectangle {
                            width: 9; height: 9; radius: 4.5; color: "white"
                            scale: 0
                            Component.onCompleted: scale = 1
                            Behavior on scale { SpringAnimation { spring: 6; damping: 0.4 } }
                        }
                    }
                }
                // submit arrow
                Rectangle {
                    width: 28; height: 28; radius: 14
                    anchors { right: parent.right; rightMargin: 7; verticalCenter: parent.verticalCenter }
                    color: Qt.rgba(1, 1, 1, 0.92)
                    opacity: root.password.length > 0 && !root.busy ? 1 : 0
                    scale: opacity
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                    Text { anchors.centerIn: parent; text: ""; color: "#111"; font.family: Theme.icons; font.pixelSize: 12 }
                    MouseArea { anchors.fill: parent; onClicked: root.submit(root.password) }
                }
                // busy: field breathes
                SequentialAnimation on scale { running: root.busy; loops: Animation.Infinite
                    NumberAnimation { to: 1.03; duration: 450; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 450; easing.type: Easing.InOutSine } }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.failed && root.tries > 1 ? "Try again  ·  " + root.tries : (Config.lockHint ? "Type your password to unlock" : "")
                color: Qt.rgba(1, 1, 1, 0.55)
                font.family: Theme.font; font.pixelSize: 13
            }
        }
    }

    SequentialAnimation {
        id: shake
        NumberAnimation { target: shakeT; property: "x"; to: -18; duration: 55 }
        NumberAnimation { target: shakeT; property: "x"; to: 15; duration: 70 }
        NumberAnimation { target: shakeT; property: "x"; to: -10; duration: 70 }
        NumberAnimation { target: shakeT; property: "x"; to: 5; duration: 60 }
        NumberAnimation { target: shakeT; property: "x"; to: 0; duration: 60 }
    }

    // caps lock warning
    property bool caps: false
    Text {
        x: (root.width - width) / 2
        y: root.height * 0.70 + 76 + 12 + 24 + 12 + 42 + 36
        text: "Caps Lock is on"
        color: "#ffd479"; font.family: Theme.font; font.pixelSize: 13
        opacity: Config.lockCaps && root.caps && root.typing && root.locked ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
    }
    Timer { interval: 400; repeat: true; running: Config.lockCaps && root.typing && root.locked; triggeredOnStart: true; onTriggered: if (!capsProc.running) capsProc.running = true }
    Process {
        id: capsProc
        command: ["sh", "-c", "cat /sys/class/leds/*capslock/brightness 2>/dev/null | grep -q 1"]
        onExited: code => root.caps = code === 0
    }

    // battery, bottom right, like a phone's status corner
    Row {
        anchors { right: parent.right; bottom: parent.bottom; rightMargin: 28; bottomMargin: 24 }
        spacing: 7
        visible: Sys.hasBattery
        opacity: ui.opacity * 0.8
        Text { anchors.verticalCenter: parent.verticalCenter; text: Math.round(Sys.percent) + "%"; color: "white"; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.Medium }
        Text { anchors.verticalCenter: parent.verticalCenter; text: Sys.charging ? "" : ""; color: Sys.charging ? "#7ee787" : "white"; font.family: Theme.icons; font.pixelSize: 14 }
    }
}
