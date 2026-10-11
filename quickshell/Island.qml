import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import "singletons"

PanelWindow {
    id: win
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    // idle: only the island takes input. spotlight / wallpapers: the whole screen does, so a click outside closes it.
    mask: Region { item: win.modal ? scrim : pill }
    WlrLayershell.namespace: "ddmm-island"
    WlrLayershell.keyboardFocus: win.modal || Ui.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property var player: Mpris.players.values.find(x => x.isPlaying) || null
    readonly property bool modal: Ui.spotlight || Ui.walls || Ui.powerMenu
    readonly property string mode: Ui.spotlight ? "spotlight" : Ui.walls ? "walls" : Ui.powerMenu ? "power" : Ui.open ? "page" : Ui.flashOn ? "flash" : Ui.osdOn ? "osd" : Ui.toast ? "toast" : "idle"
    readonly property real flashW: Ui.flashKind === "ws" ? 330 : Ui.flashKind === "media" ? 400 : 240
    readonly property real flashH: Ui.flashKind === "media" ? 68 : 50
    readonly property real wantW: mode === "spotlight" ? 760 : mode === "walls" ? 980 : mode === "power" ? 800 : mode === "page" ? Config.openWidth : mode === "flash" ? flashW : mode === "osd" ? 250 : mode === "toast" ? 440 : (player ? Config.idleWidth + 64 : Config.idleWidth)
    readonly property real wantH: mode === "spotlight" ? Ui.spotlightH : mode === "walls" ? 450 : mode === "power" ? 400 : mode === "page" ? Config.openHeight : mode === "flash" ? flashH : mode === "osd" ? 46 : mode === "toast" ? 78 : Config.idleHeight

    readonly property real wantY: mode === "spotlight" ? Math.max(Config.topGap, win.height * 0.30 - wantH / 4) : (mode === "walls" || mode === "power") ? Math.max(Config.topGap, (win.height - wantH) * 0.4) : Config.topGap

    SystemClock { id: clock; precision: Config.seconds ? SystemClock.Seconds : SystemClock.Minutes }

    Timer { id: closeTimer; interval: Config.closeDelay; onTriggered: Ui.hovered = false }
    Timer { id: toastTimer; interval: 4500; onTriggered: Ui.toast = false }
    Timer { id: osdTimer; interval: 1400; onTriggered: Ui.osdOn = false }
    Timer { id: ready; interval: 4000; running: true }
    Timer { id: flashTimer; onTriggered: Ui.flashOn = false }
    function flash(kind, data, ms) {
        if (!Config.liveActivities || ready.running) return;
        Ui.flash(kind, data);
        flashTimer.interval = ms;
        flashTimer.restart();
    }
    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() {
            const w = Hyprland.focusedWorkspace;
            if (w) win.flash("ws", { id: w.id, name: w.name }, 1300);
        }
    }
    Connections {
        target: win.player
        ignoreUnknownSignals: true
        function onTrackTitleChanged() { mediaDebounce.restart(); }
    }
    Timer {
        id: mediaDebounce
        interval: 500
        onTriggered: if (win.player && win.player.trackTitle) win.flash("media", { title: win.player.trackTitle, artist: win.player.trackArtist || "", art: win.player.trackArtUrl || "" }, 3200)
    }
    Connections {
        target: Sys
        function onChargingChanged() { if (Sys.hasBattery && !ready.running) Sounds.play(Sys.charging ? "power-plug" : "power-unplug"); if (Sys.hasBattery) win.flash("power", { charging: Sys.charging, pct: Math.round(Sys.percent) }, 2400); }
    }
    Connections {
        target: Notifs
        function onArrived() { Ui.toast = true; toastTimer.restart(); Sounds.play("message-new-instant", 400); }
    }
    Connections {
        target: Ui
        function onOsdOnChanged() { if (Ui.osdOn) osdTimer.restart(); }
        function onOsdValueChanged() { osdTimer.restart(); }
        function onPageChanged() { win.syncWatch(); if (Ui.pageName === "notifs") Notifs.unread = 0; }
        function onOpenChanged() { win.syncWatch(); if (!Ui.open) { stage.snapBack(); Ui.powerSel = 0; } }
    }
    Connections {
        target: Audio
        function onVolumeChanged() { if (!ready.running) { Ui.showOsd("vol", Audio.volume, Audio.muted); Sounds.play("audio-volume-change", 180); } }
        function onMutedChanged() { if (!ready.running) Ui.showOsd("vol", Audio.volume, Audio.muted); }
    }
    function syncWatch() { Sys.watch = Ui.open && (Ui.pageName === "system" || Ui.pageName === "home"); }

    // ------------------------------------------------------------------ the island
    // dim + click catcher while a modal is up
    Rectangle {
        id: scrim
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, win.modal ? 0.34 : 0)
        Behavior on color { ColorAnimation { duration: 320 } }
        MouseArea { anchors.fill: parent; enabled: win.modal; onClicked: Ui.close() }
    }

    Rectangle {
        id: pill
        x: (parent.width - width) / 2
        y: win.wantY
        width: win.wantW
        height: win.wantH
        radius: Math.min(height / 2, win.modal ? 30 : 36)
        color: Theme.bg
        clip: true

        Behavior on width { SpringAnimation { spring: 3.6; damping: 0.3; epsilon: 0.3; mass: 1 } enabled: Config.animations }
        Behavior on height { SpringAnimation { spring: 3.6; damping: 0.3; epsilon: 0.3; mass: 1 } enabled: Config.animations }
        Behavior on y { SpringAnimation { spring: 2.8; damping: 0.34; epsilon: 0.3; mass: 1 } enabled: Config.animations }

        HoverHandler {
            enabled: !win.modal
            onHoveredChanged: {
                if (hovered) { closeTimer.stop(); Ui.hovered = true; }
                else closeTimer.restart();
            }
        }
        WheelHandler {
            blocking: false
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: ev => stage.onScroll(ev)
        }

        // ---- idle: clock, plus a tiny equaliser when something is playing
        Item {
            id: idle
            anchors.fill: parent
            readonly property real k: win.mode === "idle" ? 1 : 0
            opacity: k
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 140 } }

            Row {
                visible: !!win.player
                anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                spacing: 2.5
                Repeater {
                    model: 4
                    Rectangle {
                        id: bar
                        required property int index
                        width: 2.5; height: 4; radius: 1.2; color: Theme.accent
                        anchors.verticalCenter: parent.verticalCenter
                        SequentialAnimation on height {
                            running: idle.visible && !!win.player
                            loops: Animation.Infinite
                            NumberAnimation { to: 5 + (bar.index * 5) % 9; duration: 260 + bar.index * 70; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 3 + (bar.index * 7) % 5; duration: 300 + bar.index * 50; easing.type: Easing.InOutSine }
                        }
                    }
                }
            }
            Text {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: win.player ? 10 : 0
                Behavior on anchors.horizontalCenterOffset { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                text: Qt.formatTime(clock.date, Config.clock24 ? (Config.seconds ? "HH:mm:ss" : "HH:mm") : (Config.seconds ? "h:mm:ss AP" : "h:mm AP"))
                color: Theme.fg
                font.family: Theme.font; font.pixelSize: 13; font.weight: Font.Medium
            }
            Rectangle {
                visible: Notifs.unread > 0
                width: 6; height: 6; radius: 3; color: Theme.accent
                anchors { verticalCenter: parent.verticalCenter; right: parent.right; rightMargin: 12 }
            }
        }

        // ---- live activity (workspace / track / charger)
        Item {
            id: flashBox
            anchors.fill: parent
            readonly property real k: win.mode === "flash" ? 1 : 0
            opacity: k
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 150 } }

            // workspaces: a capsule slides to the active numeral
            Item {
                visible: Ui.flashKind === "ws"
                anchors.centerIn: parent
                width: 5 * 46; height: 32
                Rectangle {
                    id: cap
                    readonly property int wid: Ui.flashKind === "ws" && Ui.flashData.id ? Ui.flashData.id : 1
                    width: 40; height: 30; radius: 15; color: Theme.fg
                    x: (Math.max(1, Math.min(5, wid)) - 1) * 46 + 3
                    visible: wid >= 1 && wid <= 5
                    Behavior on x { SpringAnimation { spring: 5; damping: 0.4; epsilon: 0.3 } }
                }
                Repeater {
                    model: 5
                    Text {
                        required property int index
                        readonly property bool cur: Ui.flashKind === "ws" && Ui.flashData.id === index + 1
                        readonly property bool used: !!Hyprland.workspaces.values.find(w => w.id === index + 1)
                        x: index * 46; width: 46; height: 32
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                        text: index + 1
                        color: cur ? Theme.accentText : used ? Theme.fg : Theme.dim
                        font.family: Theme.mono; font.pixelSize: 14; font.weight: cur ? Font.Bold : Font.Normal
                    }
                }
                // special / out-of-range workspaces get a name instead
                Text {
                    visible: !cap.visible
                    anchors.centerIn: parent
                    text: Ui.flashData.name || ""
                    color: Theme.fg; font.family: Theme.serif; font.italic: true; font.pixelSize: 22
                }
            }
            // track change
            Row {
                visible: Ui.flashKind === "media"
                anchors { fill: parent; leftMargin: 14; rightMargin: 18 }
                spacing: 14
                Rectangle {
                    width: 44; height: 44; radius: 12; color: Theme.card; clip: true
                    anchors.verticalCenter: parent.verticalCenter
                    Image { anchors.fill: parent; source: Ui.flashKind === "media" ? (Ui.flashData.art || "") : ""; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(88, 88) }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 60; spacing: 2
                    Text { width: parent.width; elide: Text.ElideRight; color: Theme.fg; font.family: Theme.font; font.pixelSize: 14; font.weight: Font.Medium; text: Ui.flashData.title || "" }
                    Text { width: parent.width; elide: Text.ElideRight; color: Theme.dim; font.family: Theme.serif; font.italic: true; font.pixelSize: 16; text: Ui.flashData.artist || "" }
                }
            }
            // charger
            Row {
                visible: Ui.flashKind === "power"
                anchors.centerIn: parent
                spacing: 12
                Text { anchors.verticalCenter: parent.verticalCenter; text: Ui.flashData.charging ? "\uf0e7" : "\uf240"; color: Ui.flashData.charging ? Theme.accent : Theme.fg; font.family: Theme.icons; font.pixelSize: 16 }
                Text { anchors.verticalCenter: parent.verticalCenter; color: Theme.fg; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.Medium
                    text: Ui.flashData.charging ? "Charging" : "On battery" }
                Text { anchors.verticalCenter: parent.verticalCenter; color: Theme.dim; font.family: Theme.mono; font.pixelSize: 12; text: (Ui.flashData.pct || 0) + "%" }
            }
            MouseArea { anchors.fill: parent; onClicked: { Ui.flashOn = false; Ui.pinned = true; Ui.setPage(Ui.flashKind === "media" ? 1 : Ui.flashKind === "power" ? 2 : 0); } }
        }

        // ---- osd
        Item {
            anchors.fill: parent
            readonly property real k: win.mode === "osd" ? 1 : 0
            opacity: k
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 140 } }
            Text {
                id: osdIcon
                anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
                color: Theme.fg; font.family: Theme.icons; font.pixelSize: 15; width: 20
                text: Ui.osdKind === "bright" ? "" : (Ui.osdMuted || Ui.osdValue <= 0.001 ? "" : Ui.osdValue < 0.5 ? "" : "")
            }
            Rectangle {
                anchors { left: osdIcon.right; leftMargin: 12; right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
                height: 4; radius: 2; color: Theme.faint
                Rectangle {
                    height: parent.height; radius: 2; color: Ui.osdMuted ? Theme.dim : Theme.fg
                    width: parent.width * Math.max(0, Math.min(1, Ui.osdValue))
                    Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                }
            }
        }

        // ---- toast: newest notification
        Item {
            anchors.fill: parent
            readonly property real k: win.mode === "toast" ? 1 : 0
            opacity: k
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 160 } }
            Row {
                anchors { fill: parent; leftMargin: 18; rightMargin: 18 }
                spacing: 14
                Image {
                    width: 40; height: 40; anchors.verticalCenter: parent.verticalCenter
                    source: Notifs.latest ? Notifs.latest.icon : ""
                    visible: status === Image.Ready
                    sourceSize: Qt.size(80, 80); fillMode: Image.PreserveAspectFit
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 54; spacing: 3
                    Text { width: parent.width; elide: Text.ElideRight; color: Theme.fg; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.Medium
                        text: Notifs.latest ? Notifs.latest.summary : "" }
                    Text { width: parent.width; elide: Text.ElideRight; color: Theme.dim; font.family: Theme.font; font.pixelSize: 12
                        text: Notifs.latest ? (Notifs.latest.app ? Notifs.latest.app + "  ·  " : "") + Notifs.latest.body.replace(/<[^>]*>/g, "").split("\n")[0] : "" }
                }
            }
            MouseArea { anchors.fill: parent; onClicked: { Ui.toast = false; Ui.openPage("notifs"); } }
        }

        // ---- spotlight (launcher) and wallpaper picker: the island, moved to the middle
        Item {
            id: spot
            anchors.fill: parent
            property real shown: win.mode === "spotlight" ? 1 : 0
            Behavior on shown { SequentialAnimation {
                PauseAnimation { duration: win.mode === "spotlight" && Config.animations ? 140 : 0 }
                NumberAnimation { duration: win.mode === "spotlight" ? 300 : 90; easing.type: Easing.OutCubic } } }
            opacity: shown; visible: shown > 0.01
            Loader {
                anchors { fill: parent; margins: 22 }
                active: win.mode === "spotlight" || spot.shown > 0.01
                source: "pages/Launcher.qml"
            }
        }
        Item {
            id: wallBox
            anchors.fill: parent
            property real shown: win.mode === "walls" ? 1 : 0
            Behavior on shown { SequentialAnimation {
                PauseAnimation { duration: win.mode === "walls" && Config.animations ? 140 : 0 }
                NumberAnimation { duration: win.mode === "walls" ? 300 : 90; easing.type: Easing.OutCubic } } }
            opacity: shown; visible: shown > 0.01
            Loader {
                anchors { fill: parent; margins: 26 }
                active: win.mode === "walls" || wallBox.shown > 0.01
                source: "pages/Wallpaper.qml"
            }
        }

        Item {
            id: powBox
            anchors.fill: parent
            property real shown: win.mode === "power" ? 1 : 0
            Behavior on shown { SequentialAnimation {
                PauseAnimation { duration: win.mode === "power" && Config.animations ? 140 : 0 }
                NumberAnimation { duration: win.mode === "power" ? 300 : 90; easing.type: Easing.OutCubic } } }
            opacity: shown; visible: shown > 0.01
            Loader {
                anchors { fill: parent; margins: 26 }
                active: win.mode === "power" || powBox.shown > 0.01
                source: "pages/PowerMenu.qml"
            }
        }

        // ---- the full island
        Item {
            id: panel
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            width: Config.openWidth; height: parent.height
            property real shown: win.mode === "page" ? 1 : 0
            Behavior on shown {
                SequentialAnimation {
                    PauseAnimation { duration: win.mode === "page" && Config.animations ? 110 : 0 }
                    NumberAnimation { duration: win.mode === "page" ? 380 : 110; easing.type: Easing.OutCubic }
                }
            }
            opacity: shown
            visible: shown > 0.01
            scale: 0.94 + 0.06 * shown
            transformOrigin: Item.Top

            focus: true
            Connections {
                target: Ui
                function onOpenChanged() { if (Ui.open) panel.forceActiveFocus(); }
                function onPageChanged() { if (Ui.open) panel.forceActiveFocus(); }
            }
            Keys.onEscapePressed: Ui.close()
            Keys.onReleased: ev => {
                if (!ev.isAutoRepeat && [Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space].includes(ev.key)) Ui.powerHold = false;
            }
            Keys.onPressed: ev => {
                if (Ui.pageName === "power" && [Qt.Key_Left, Qt.Key_Right, Qt.Key_Up, Qt.Key_Down, Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space].includes(ev.key)) {
                    if (ev.key === Qt.Key_Left || ev.key === Qt.Key_Up) Ui.powerSel = Math.max(0, Ui.powerSel - 1);
                    else if (ev.key === Qt.Key_Right || ev.key === Qt.Key_Down) Ui.powerSel = Math.min(4, Ui.powerSel + 1);
                    else if (!ev.isAutoRepeat) Ui.powerHold = true;
                    ev.accepted = true;
                }
                else if (ev.key >= Qt.Key_1 && ev.key <= Qt.Key_5) { Ui.setPage(ev.key - Qt.Key_1); ev.accepted = true; }
                else if (ev.key === Qt.Key_Tab) { Ui.setPage((Ui.page + 1) % Ui.pageNames.length); ev.accepted = true; }
                else if (ev.key === Qt.Key_Backtab) { Ui.setPage((Ui.page + Ui.pageNames.length - 1) % Ui.pageNames.length); ev.accepted = true; }
            }

            // header: serif title + page glyphs
            Item {
                id: header
                x: 28; y: 18; width: parent.width - 56; height: 34

                Item {
                    id: titleBox
                    width: 300; height: parent.height; clip: true
                    Repeater {
                        model: Ui.pageTitles
                        Text {
                            required property int index
                            required property string modelData
                            readonly property real d: index - stage.pos
                            anchors.verticalCenter: parent.verticalCenter
                            x: d * 26
                            opacity: Math.max(0, 1 - Math.abs(d) * 1.6)
                            text: modelData
                            color: Theme.fg
                            font.family: Theme.serif; font.pixelSize: 30; font.italic: true
                        }
                    }
                }
                Row {
                    id: tabs
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: 4
                    Repeater {
                        model: ["\uf015", "\uf001", "\uf2db", "\uf0f3", "\uf011"]
                        Item {
                            required property int index
                            required property string modelData
                            readonly property bool on: Math.round(stage.pos) === index
                            width: 30; height: 30
                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                color: on ? Theme.fg : Theme.dim
                                font.family: Theme.icons; font.pixelSize: 14
                                Behavior on color { ColorAnimation { duration: 160 } }
                            }
                            MouseArea { anchors.fill: parent; hoverEnabled: true; onClicked: Ui.setPage(index)
                                cursorShape: Qt.PointingHandCursor }
                        }
                    }
                }
                Rectangle {
                    // marker follows the animated position
                    y: header.height - 2; height: 2; radius: 1; width: 14; color: Theme.accent
                    x: tabs.x + stage.pos * 34 + 8
                    visible: stage.pos > -0.5
                }
            }

            // page carousel
            Item {
                id: stage
                x: 28; y: header.y + header.height + 6
                width: parent.width - 56
                height: parent.height - y - 22
                clip: true

                property real pos: 0
                property real drag: 0
                property bool dragging: false
                readonly property var cur: pages.itemAt(Ui.page) ? pages.itemAt(Ui.page).item : null
                readonly property bool curOwnsWheel: !!cur && !!cur.ownsWheel

                Behavior on pos {
                    enabled: !stage.dragging
                    NumberAnimation { duration: Theme.dur; easing.type: Easing.OutQuint }
                }
                Component.onCompleted: pos = Ui.page
                Connections { target: Ui; function onPageChanged() { if (!stage.dragging) stage.pos = Ui.page; } }

                function snapBack() { drag = 0; dragging = false; wheelEnd.stop(); pos = Ui.page; }

                // mouse wheel: one notch = one page. touchpad: the pages follow your fingers, then snap.
                function onScroll(ev) {
                    if (win.mode !== "page" || cool.running) return;
                    const px = ev.pixelDelta, ad = ev.angleDelta;
                    const hasPx = px.x !== 0 || px.y !== 0;
                    // a real wheel sends whole 120-unit notches with no pixel delta; everything else is a touchpad
                    const notch = !hasPx && (Math.abs(ad.x) >= 120 || Math.abs(ad.y) >= 120) && ad.x % 120 === 0 && ad.y % 120 === 0;
                    const touch = !notch;
                    const sx = hasPx ? px.x : ad.x * 0.5, sy = hasPx ? px.y : ad.y * 0.5;
                    const horiz = Math.abs(sx) > Math.abs(sy);
                    if (!horiz && curOwnsWheel) return;
                    let d = horiz ? sx : sy;
                    if (Config.invertScroll) d = -d;
                    if (d === 0) return;
                    if (!touch) {
                        Ui.setPage(Ui.page + (d < 0 ? 1 : -1));
                        cool.restart();
                        return;
                    }
                    dragging = true;
                    drag = Math.max(-Config.swipeDistance, Math.min(Config.swipeDistance, drag - d));
                    const raw = Ui.page + drag / Config.swipeDistance;
                    pos = Math.max(0, Math.min(Ui.pageNames.length - 1, raw));
                    wheelEnd.restart();
                }
                Timer {
                    id: wheelEnd
                    interval: 90
                    onTriggered: {
                        const o = stage.drag / Config.swipeDistance;
                        stage.dragging = false;
                        stage.drag = 0;
                        if (Math.abs(o) > 0.2) { Ui.setPage(Ui.page + (o > 0 ? 1 : -1)); cool.restart(); }
                        stage.pos = Ui.page;
                    }
                }
                Timer { id: cool; interval: 260 }

                Repeater {
                    id: pages
                    model: 5
                    Loader {
                        required property int index
                        readonly property real d: index - stage.pos
                        width: stage.width; height: stage.height
                        active: Math.abs(d) < 1.2
                        visible: Math.abs(d) < 1
                        x: d * stage.width * 0.35
                        opacity: Math.max(0, 1 - Math.abs(d) * 1.5)
                        scale: 1 - Math.abs(d) * 0.05
                        source: "pages/" + ["Home", "Media", "System", "Notifs", "Power"][index] + ".qml"
                    }
                }
            }
        }
    }
}
