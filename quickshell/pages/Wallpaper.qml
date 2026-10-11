import QtQuick
import Quickshell
import Quickshell.Io
import "../singletons"

// Wallpaper picker: type to filter, left/right to browse (arrow keys), Enter applies.
Item {
    id: root
    property var all: []   // [{path, tags}]
    readonly property var files: refilterList(all, filter)
    readonly property var colors: ["red", "orange", "yellow", "green", "cyan", "blue", "purple", "pink", "brown", "black", "gray", "white"]
    readonly property var swatch: ({ red: "#e5484d", orange: "#f5871f", yellow: "#f2c94c", green: "#3fb950", cyan: "#2ec5d3", blue: "#3b82f6", purple: "#9b5de5", pink: "#f472b6", brown: "#8b5e3c", black: "#111111", gray: "#888b94", white: "#f4f4f5" })
    readonly property var alias: ({ "kırmızı": "red", "kirmizi": "red", "kırmmızı": "red", "turuncu": "orange", "sarı": "yellow", "sari": "yellow", "yeşil": "green", "yesil": "green", "turkuaz": "cyan", "mavi": "blue", "mor": "purple", "pembe": "pink", "kahverengi": "brown", "kahve": "brown", "siyah": "black", "gri": "gray", "beyaz": "white", "koyu": "dark", "açık": "light", "acik": "light" })
    property string dir: ""
    property string current: ""
    property string filter: ""
    readonly property int pageStep: 6

    Process {
        command: ["bash", "-c", "d=\"" + Config.wallDir + "\"; d=\"${d/#\\~/$HOME}\"; echo \"$d\"; $HOME/.local/bin/ddmm-wallcolors \"$d\""]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const L = text.split("\n").filter(x => x);
                root.dir = L.shift() || "";
                root.all = L.map(l => { const i = l.indexOf("\t"); return { path: l.slice(0, i), tags: l.slice(i + 1).split(" ").filter(t => t !== "") }; });
                const i = root.files.indexOf(root.current);
                strip.currentIndex = i >= 0 ? i : 0;
            }
        }
    }
    FileView {
        path: Quickshell.env("HOME") + "/.config/ddmm/wallpaper"
        printErrors: false
        onLoaded: root.current = text().trim()
    }
    Process { id: apply }
    function refilterList(list, q) {
        const words = q.toLowerCase().split(/\s+/).filter(w => w !== "").map(w => alias[w] || w);
        if (words.length === 0) return list.map(e => e.path);
        return list.filter(e => {
            const name = nameOf(e.path).toLowerCase();
            return words.every(w => name.indexOf(w) >= 0 || e.tags.some(t => t.indexOf(w) === 0));
        }).map(e => e.path);
    }
    onFilesChanged: strip.currentIndex = 0
    function setWall(i) {
        if (i < 0 || i >= files.length) return;
        const p = files[i];
        current = p;
        apply.command = ["sh", "-c", 'awww img "$1" --transition-type grow --transition-pos center --transition-duration 1 --transition-fps 60 && mkdir -p ~/.config/ddmm && printf %s "$1" > ~/.config/ddmm/wallpaper', "sh", p];
        apply.running = true;
        Ui.close();
    }
    function nameOf(f) { return f ? f.split("/").pop().replace(/\.[^.]+$/, "") : ""; }

    // header
    Text { id: title; text: "Wallpapers"; color: Theme.fg; font.family: Theme.serif; font.italic: true; font.pixelSize: 30 }
    Text {
        anchors { right: parent.right; baseline: title.baseline }
        text: root.files.length ? (strip.currentIndex + 1) + " / " + root.files.length : "0"
        color: Theme.dim; font.family: Theme.mono; font.pixelSize: 12
    }
    TextInput {
        id: field
        anchors { left: title.right; leftMargin: 22; baseline: title.baseline; right: parent.right; rightMargin: 90 }
        color: Theme.fg; font.family: Theme.font; font.pixelSize: 15; clip: true
        selectionColor: Theme.accent; selectedTextColor: Theme.accentText
        focus: true
        onTextChanged: root.filter = text
        Keys.onPressed: ev => {
            if (ev.key === Qt.Key_Left) { strip.currentIndex = Math.max(0, strip.currentIndex - 1); ev.accepted = true; }
            else if (ev.key === Qt.Key_Right) { strip.currentIndex = Math.min(strip.count - 1, strip.currentIndex + 1); ev.accepted = true; }
            else if (ev.key === Qt.Key_Up || ev.key === Qt.Key_PageUp) { strip.currentIndex = Math.max(0, strip.currentIndex - root.pageStep); ev.accepted = true; }
            else if (ev.key === Qt.Key_Down || ev.key === Qt.Key_PageDown) { strip.currentIndex = Math.min(strip.count - 1, strip.currentIndex + root.pageStep); ev.accepted = true; }
            else if (ev.key === Qt.Key_Home) { strip.currentIndex = 0; ev.accepted = true; }
            else if (ev.key === Qt.Key_End) { strip.currentIndex = strip.count - 1; ev.accepted = true; }
            else if (ev.key === Qt.Key_R && (ev.modifiers & Qt.ControlModifier)) { strip.currentIndex = Math.floor(Math.random() * Math.max(1, strip.count)); ev.accepted = true; }
        }
        Keys.onReturnPressed: root.setWall(strip.currentIndex)
        Keys.onEnterPressed: root.setWall(strip.currentIndex)
        Keys.onEscapePressed: { if (text !== "") text = ""; else Ui.close(); }
        Text { visible: !parent.text; text: "name or colour (red, mavi…)"; color: Theme.dim; font.family: Theme.serif; font.italic: true; font.pixelSize: 18 }
    }
    Component.onCompleted: field.forceActiveFocus()

    Row {
        id: chips
        anchors { horizontalCenter: parent.horizontalCenter; top: title.bottom; topMargin: 12 }
        spacing: 11
        Repeater {
            model: root.colors
            delegate: Rectangle {
                id: chip
                required property string modelData
                readonly property bool on: root.filter.trim().toLowerCase() === modelData
                width: 20; height: 20; radius: 10
                color: root.swatch[modelData]
                border.width: on ? 2.5 : 1
                border.color: on ? Theme.fg : Qt.rgba(1, 1, 1, 0.25)
                scale: on ? 1.2 : chipMa.containsMouse ? 1.1 : 1
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
                MouseArea {
                    id: chipMa
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { field.text = chip.on ? "" : chip.modelData; field.forceActiveFocus(); }
                }
            }
        }
    }

    ListView {
        id: strip
        anchors { left: parent.left; right: parent.right; top: chips.bottom; topMargin: 10; bottom: label.top; bottomMargin: 6 }
        orientation: ListView.Horizontal
        model: root.files
        clip: false
        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: width / 2 - 150; preferredHighlightEnd: width / 2 + 150
        highlightMoveDuration: Config.animations ? 260 : 0
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: 600
        delegate: Item {
            required property int index
            required property string modelData
            readonly property bool cur: index === strip.currentIndex
            readonly property bool live: modelData === root.current
            width: 300; height: strip.height
            Rectangle {
                anchors.centerIn: parent
                width: 280; height: 176; radius: 22; color: Theme.card; clip: true
                scale: cur ? 1.12 : 0.88
                opacity: cur ? 1 : 0.5
                Behavior on scale { SpringAnimation { spring: 4; damping: 0.4; epsilon: 0.002 } }
                Behavior on opacity { NumberAnimation { duration: 200 } }
                Image {
                    anchors.fill: parent
                    source: "file://" + modelData
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(560, 352); asynchronous: true; cache: false
                }
                Rectangle { visible: live; anchors { left: parent.left; top: parent.top; margins: 12 } width: 8; height: 8; radius: 4; color: Theme.accent }
                MouseArea { anchors.fill: parent; onClicked: { if (cur) root.setWall(index); else strip.currentIndex = index; } }
            }
        }
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: ev => {
                const d = Math.abs(ev.angleDelta.x) > Math.abs(ev.angleDelta.y) ? ev.angleDelta.x : ev.angleDelta.y;
                if (d < 0) strip.currentIndex = Math.min(strip.count - 1, strip.currentIndex + 1);
                else if (d > 0) strip.currentIndex = Math.max(0, strip.currentIndex - 1);
            }
        }
    }
    Text {
        id: label
        anchors { horizontalCenter: parent.horizontalCenter; bottom: foot.top; bottomMargin: 4 }
        color: Theme.fg; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.Medium
        text: root.files.length ? root.nameOf(root.files[strip.currentIndex]) : (root.all.length ? "No wallpaper matches \"" + root.filter + "\"" : "No wallpapers in " + Config.wallDir)
    }
    Text {
        id: foot
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
        color: Qt.rgba(1, 1, 1, 0.3); font.family: Theme.font; font.pixelSize: 10; font.letterSpacing: 0.6
        text: "←  →  browse      ↑  ↓  jump      ↵  apply      ctrl+R  random      esc  close"
    }
}
