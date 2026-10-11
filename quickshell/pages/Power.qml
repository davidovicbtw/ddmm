import QtQuick
import "../singletons"

// Power: a strip of glyphs, the selected one unfolds into a wide capsule.
// Lock / Sleep fire at once; Log out / Restart / Shut down fill up while you hold Enter (or the mouse button).
Item {
    id: root
    property bool ownsWheel: false
    readonly property var items: [
        { t: "Lock", h: "Lock the screen", g: "\uf023", c: "lock" },
        { t: "Sleep", h: "Suspend to RAM", g: "\uf186", c: "systemctl suspend" },
        { t: "Log out", h: "Hold to end session", g: "\uf2f5", c: "hyprctl dispatch 'hl.dsp.exit()' || hyprctl dispatch exit", hold: true },
        { t: "Restart", h: "Hold to reboot", g: "\uf021", c: "systemctl reboot", hold: true },
        { t: "Shut down", h: "Hold to power off", g: "\uf011", c: "systemctl poweroff", hold: true, danger: true }
    ]
    property bool mouseHold: false
    readonly property bool holding: Ui.powerHold || mouseHold
    readonly property var cur: items[Ui.powerSel]
    property real fill: 0
    function run(m) { Ui.close(); if (m.c === "lock") Sys.lock(); else Sys.run(m.c); }

    onHoldingChanged: {
        fillAnim.stop();
        if (holding) {
            if (!cur.hold) { run(cur); return; }
            fillAnim.from = 0; fillAnim.to = 1; fillAnim.duration = 900; fillAnim.start();
        } else {
            fillAnim.from = fill; fillAnim.to = 0; fillAnim.duration = 220; fillAnim.start();
        }
    }
    Connections { target: Ui; function onPowerSelChanged() { fillAnim.stop(); root.fill = 0; } }
    NumberAnimation { id: fillAnim; target: root; property: "fill"; easing.type: Easing.InOutSine
        onFinished: if (root.fill >= 1) { root.run(root.cur); root.fill = 0; } }

    Row {
        id: strip
        anchors.centerIn: parent
        spacing: 12
        Repeater {
            model: root.items
            Rectangle {
                id: it
                required property var modelData
                required property int index
                readonly property bool sel: Ui.powerSel === index
                readonly property color tint: modelData.danger ? Theme.danger : Theme.fg
                width: sel ? 250 : 66; height: 66; radius: 33
                color: Theme.card
                clip: true
                border.width: sel ? 1 : 0; border.color: Qt.rgba(tint.r, tint.g, tint.b, 0.35)
                Behavior on width { SpringAnimation { spring: 3.2; damping: 0.28; mass: 0.9 } }

                // the hold fill, sweeping left to right behind the content
                Rectangle {
                    height: parent.height; radius: parent.radius
                    width: parent.width * (it.sel ? root.fill : 0)
                    color: it.tint
                    opacity: 0.95
                }
                // glyph: sits left, inverts once the fill passes under it
                Text {
                    id: gl
                    x: sel ? 22 : (parent.width - width) / 2; anchors.verticalCenter: parent.verticalCenter
                    Behavior on x { SpringAnimation { spring: 3.2; damping: 0.3 } }
                    text: it.modelData.g; font.family: Theme.icons; font.pixelSize: 24
                    color: it.sel && root.fill > 0.08 ? (it.modelData.danger ? "white" : Theme.accentText) : (it.sel ? it.tint : Theme.dim)
                }
                Column {
                    x: 66; anchors.verticalCenter: parent.verticalCenter
                    opacity: it.sel ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: it.sel ? 220 : 60 } }
                    Text { text: it.modelData.t; font.family: Theme.serif; font.italic: true; font.pixelSize: 26
                        color: root.fill > 0.5 ? (it.modelData.danger ? "white" : Theme.accentText) : Theme.fg }
                    Text { text: root.fill > 0.02 ? "keep holding…" : it.modelData.h; font.family: Theme.font; font.pixelSize: 11
                        color: root.fill > 0.5 ? (it.modelData.danger ? "white" : Theme.accentText) : Theme.dim }
                }
                MouseArea {
                    anchors.fill: parent; hoverEnabled: true
                    onEntered: Ui.powerSel = it.index
                    onPressed: { Ui.powerSel = it.index; root.mouseHold = true; }
                    onReleased: root.mouseHold = false
                    onCanceled: root.mouseHold = false
                }
            }
        }
    }
    Text {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 6 }
        text: "←  →  choose      ⏎  hold to confirm      esc  close"
        color: Theme.dim; font.family: Theme.mono; font.pixelSize: 11; opacity: 0.7
    }
}
