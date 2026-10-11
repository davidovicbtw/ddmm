import QtQuick
import "../singletons"

// Power menu: the island sits in the middle of the screen and unfolds five tall tiles.
// ←/→ choose. Lock and Sleep fire on Enter; Log out / Restart / Shut down fill the tile while Enter is held.
Item {
    id: root
    focus: true
    readonly property var items: [
        { t: "Lock", h: "Screen off, session kept", g: "\uf023", c: "lock" },
        { t: "Sleep", h: "Suspend to RAM", g: "\uf186", c: "systemctl suspend" },
        { t: "Log out", h: "End this session", g: "\uf2f5", c: "hyprctl dispatch 'hl.dsp.exit()' || hyprctl dispatch exit", hold: true },
        { t: "Restart", h: "Reboot the machine", g: "\uf021", c: "systemctl reboot", hold: true },
        { t: "Shut down", h: "Power everything off", g: "\uf011", c: "systemctl poweroff", hold: true, danger: true }
    ]
    property bool mouseHold: false
    readonly property bool holding: Ui.powerHold || mouseHold
    readonly property var cur: items[Ui.powerSel]
    readonly property color tint: cur.danger ? Theme.danger : Theme.fg
    property real fill: 0
    function run(m) { Ui.close(); if (m.c === "lock") Sys.lock(); else Sys.run(m.c); }

    Component.onCompleted: forceActiveFocus()
    onVisibleChanged: if (visible) forceActiveFocus()
    Keys.onEscapePressed: Ui.close()
    Keys.onPressed: ev => {
        const k = ev.key;
        if (k === Qt.Key_Left || k === Qt.Key_Up) Ui.powerSel = Math.max(0, Ui.powerSel - 1);
        else if (k === Qt.Key_Right || k === Qt.Key_Down || k === Qt.Key_Tab) Ui.powerSel = Math.min(4, Ui.powerSel + 1);
        else if (k === Qt.Key_Backtab) Ui.powerSel = Math.max(0, Ui.powerSel - 1);
        else if (k >= Qt.Key_1 && k <= Qt.Key_5) Ui.powerSel = k - Qt.Key_1;
        else if ((k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) && !ev.isAutoRepeat) Ui.powerHold = true;
        else return;
        ev.accepted = true;
    }
    Keys.onReleased: ev => {
        if (!ev.isAutoRepeat && (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter || ev.key === Qt.Key_Space)) Ui.powerHold = false;
    }

    onHoldingChanged: {
        fillAnim.stop();
        if (holding) {
            if (!cur.hold) { run(cur); return; }
            fillAnim.from = 0; fillAnim.to = 1; fillAnim.duration = 950; fillAnim.start();
        } else {
            fillAnim.from = fill; fillAnim.to = 0; fillAnim.duration = 260; fillAnim.start();
        }
    }
    Connections { target: Ui; function onPowerSelChanged() { fillAnim.stop(); root.fill = 0; } }
    NumberAnimation { id: fillAnim; target: root; property: "fill"; easing.type: Easing.InOutSine
        onFinished: if (root.fill >= 1) { root.run(root.cur); root.fill = 0; } }

    // headline for whatever is selected
    Item {
        id: head
        x: 14; y: 0; width: parent.width - 28; height: 86
        Text { x: 0; y: 4; text: "POWER"; color: Theme.dim; font.family: Theme.mono; font.pixelSize: 11; font.letterSpacing: 2.5 }
        Text {
            id: big
            x: 0; y: 20
            text: root.cur.t
            color: root.fill > 0.02 ? root.tint : Theme.fg
            font.family: Theme.serif; font.italic: true; font.pixelSize: 54
            Behavior on color { ColorAnimation { duration: 140 } }
        }
        Text {
            anchors { right: parent.right; baseline: big.baseline }
            horizontalAlignment: Text.AlignRight
            text: root.holding && root.cur.hold ? "keep holding…" : root.cur.h
            color: Theme.dim; font.family: Theme.font; font.pixelSize: 14
        }
    }

    Row {
        anchors { horizontalCenter: parent.horizontalCenter; top: head.bottom; topMargin: 14 }
        spacing: 14
        Repeater {
            model: root.items
            Rectangle {
                id: tile
                required property var modelData
                required property int index
                readonly property bool sel: Ui.powerSel === index
                readonly property color tint: modelData.danger ? Theme.danger : Theme.fg
                readonly property color onTint: modelData.danger ? "white" : Theme.accentText
                width: 136; height: 196; radius: 28
                color: sel ? Qt.rgba(1, 1, 1, 0.075) : Qt.rgba(1, 1, 1, 0.03)
                border.width: 1
                border.color: sel ? Qt.rgba(tint.r, tint.g, tint.b, 0.55) : Qt.rgba(1, 1, 1, 0.05)
                scale: ma.pressed ? 0.96 : sel ? 1.045 : 1
                y: sel ? -6 : 0
                clip: true
                Behavior on color { ColorAnimation { duration: 160 } }
                Behavior on border.color { ColorAnimation { duration: 160 } }
                Behavior on scale { SpringAnimation { spring: 4; damping: 0.3 } }
                Behavior on y { SpringAnimation { spring: 4; damping: 0.3 } }

                // hold fill rises from the bottom
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: parent.height * (tile.sel ? root.fill : 0)
                    color: tile.tint
                }
                // quick tap on non-hold tiles: soft glow behind glyph when selected
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter; y: 34
                    width: 92; height: 92; radius: 46
                    color: tile.tint; opacity: tile.sel && root.fill < 0.02 ? 0.12 : 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter; y: 52
                    text: tile.modelData.g; font.family: Theme.icons; font.pixelSize: 54
                    color: tile.sel ? (root.fill > 0.4 ? tile.onTint : tile.tint) : Theme.dim
                    Behavior on color { ColorAnimation { duration: 140 } }
                }
                Text {
                    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 38 }
                    text: tile.modelData.t
                    font.family: Theme.font; font.pixelSize: 14; font.weight: Font.Medium
                    color: tile.sel ? (root.fill > 0.12 ? tile.onTint : Theme.fg) : Theme.dim
                }
                Text {
                    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 15 }
                    text: tile.modelData.hold ? "HOLD" : "TAP"
                    font.family: Theme.mono; font.pixelSize: 10; font.letterSpacing: 2
                    color: tile.sel && root.fill > 0.04 ? tile.onTint : Theme.dim; opacity: 0.75
                }
                MouseArea {
                    id: ma
                    anchors.fill: parent; hoverEnabled: true
                    onEntered: Ui.powerSel = tile.index
                    onPressed: { Ui.powerSel = tile.index; root.mouseHold = true; }
                    onReleased: root.mouseHold = false
                    onCanceled: root.mouseHold = false
                }
            }
        }
    }

    Text {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
        text: "←  →  choose        ⏎  confirm  (hold for log out, restart, shut down)        esc  close"
        color: Theme.dim; font.family: Theme.mono; font.pixelSize: 11; opacity: 0.7
    }
}
