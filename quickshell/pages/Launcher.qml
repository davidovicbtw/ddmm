import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../singletons"

// Search: apps (ranked by how you use them), open windows, system actions, maths + unit conversion,
// and prefixes:  > command   f files   v clipboard history
Item {
    id: root
    readonly property bool ownsWheel: true
    Binding { target: Ui; property: "spotlightH"; value: Math.round(116 + (root.results.length > 0 ? 8 + Math.min(list.contentHeight, 340) : 0)) }
    property string q: ""
    property var results: []
    property var apps: []
    property var hist: ({})
    property var fileHits: []
    property var clipHits: []
    property string mode: "all"

    // ------------------------------------------------------------------ data
    readonly property var actions: [
        { id: "lock", title: "Lock screen", glyph: "", cmd: "$HOME/.local/bin/ddmm lock", kw: "lock screen secure" },
        { id: "sleep", title: "Sleep", glyph: "", cmd: "systemctl suspend", kw: "suspend sleep" },
        { id: "logout", title: "Log out", glyph: "", cmd: "hyprctl dispatch 'hl.dsp.exit()' || hyprctl dispatch exit", kw: "logout exit sign out" },
        { id: "reboot", title: "Restart", glyph: "", cmd: "systemctl reboot", kw: "reboot restart" },
        { id: "shutdown", title: "Shut down", glyph: "", cmd: "systemctl poweroff", kw: "shutdown power off turn off" },
        { id: "wall", title: "Wallpapers", glyph: "", fn: "walls", kw: "wallpaper background" },
        { id: "notifs", title: "Notifications", glyph: "", page: "notifs", kw: "notifications history" },
        { id: "system", title: "System", glyph: "", page: "system", kw: "system cpu ram battery wifi bluetooth" },
        { id: "media", title: "Now playing", glyph: "", page: "media", kw: "music media player volume" },
        { id: "today", title: "Calendar", glyph: "", page: "home", kw: "calendar today date clock" },
        { id: "dnd", title: "Toggle Do not disturb", glyph: "", fn: "dnd", kw: "dnd focus silent" },
        { id: "wifi", title: "Toggle Wi-Fi", glyph: "", fn: "wifi", kw: "wifi wireless network" },
        { id: "mute", title: "Mute / unmute", glyph: "", fn: "mute", kw: "mute sound audio volume" },
        { id: "settings", title: "ddmm settings", glyph: "", cmd: "kitty --hold sh -c 'ddmm list'", kw: "settings config preferences ddmm" }
    ]
    readonly property var quick: ["lock", "wall", "dnd", "system"]

    readonly property var units: ({
        m: ["len", 1], km: ["len", 1000], cm: ["len", 0.01], mm: ["len", 0.001], mi: ["len", 1609.344], ft: ["len", 0.3048], in: ["len", 0.0254], yd: ["len", 0.9144],
        kg: ["mass", 1], g: ["mass", 0.001], lb: ["mass", 0.45359237], oz: ["mass", 0.028349523],
        b: ["data", 1], kb: ["data", 1024], mb: ["data", 1048576], gb: ["data", 1073741824], tb: ["data", 1099511627776],
        s: ["time", 1], min: ["time", 60], h: ["time", 3600], d: ["time", 86400],
        l: ["vol", 1], ml: ["vol", 0.001], gal: ["vol", 3.785411784],
        c: ["temp", 0], f: ["temp", 0], k: ["temp", 0]
    })

    function fmtNum(v) { return String(Number.parseFloat(v.toPrecision(10))); }

    function calc(s) {
        s = s.trim();
        let m = /^(-?[\d.]+)\s*°?([a-z]+)\s+(?:to|in|into|->|=)\s+°?([a-z]+)$/i.exec(s);
        if (m) {
            const a = units[m[2].toLowerCase()], b = units[m[3].toLowerCase()];
            if (a && b && a[0] === b[0]) {
                const x = parseFloat(m[1]);
                let out;
                if (a[0] === "temp") {
                    const f = m[2].toLowerCase(), t = m[3].toLowerCase();
                    const c = f === "c" ? x : f === "f" ? (x - 32) * 5 / 9 : x - 273.15;
                    out = t === "c" ? c : t === "f" ? c * 9 / 5 + 32 : c + 273.15;
                } else out = x * a[1] / b[1];
                return { value: fmtNum(out) + " " + m[3].toLowerCase(), copy: fmtNum(out), expr: m[1] + " " + m[2].toLowerCase() };
            }
        }
        m = /^([\d.]+)\s*%\s*of\s*([\d.]+)$/i.exec(s);
        if (m) { const v = parseFloat(m[1]) * parseFloat(m[2]) / 100; return { value: fmtNum(v), copy: fmtNum(v), expr: s }; }
        let t = s.toLowerCase().replace(/\^/g, "**");
        t = t.replace(/\b(sqrt|sin|cos|tan|log|exp|abs|round|floor|ceil|pow|min|max)\b/g, "Math.$1").replace(/\bln\b/g, "Math.log").replace(/\bpi\b/g, "Math.PI").replace(/\be\b/g, "Math.E");
        const stripped = t.replace(/Math\.(sqrt|sin|cos|tan|log|exp|abs|round|floor|ceil|pow|min|max|PI|E)/g, "");
        if (!/^[0-9+\-*/().,%\s]*$/.test(stripped)) return null;
        if (!/[0-9]/.test(t) && t.indexOf("Math.PI") < 0) return null;
        if (!/[+\-*/%]/.test(stripped) && !/Math\.[a-z]+\(/.test(t)) return null;
        try {
            const v = Function('"use strict"; return (' + t + ")")();
            return typeof v === "number" && isFinite(v) ? { value: fmtNum(v), copy: fmtNum(v), expr: s } : null;
        } catch (e) { return null; }
    }

    function score(qs, s) {
        if (!s) return -1;
        if (s === qs) return 100;
        if (s.startsWith(qs)) return 90;
        if (s.indexOf(" " + qs) >= 0) return 75;
        const i = s.indexOf(qs);
        if (i >= 0) return 60 - Math.min(20, i);
        const ini = s.split(/[\s\-_.]+/).map(w => w[0] || "").join("");
        if (ini.startsWith(qs)) return 55;
        let j = 0, gaps = 0, last = -1;
        for (let k = 0; k < s.length && j < qs.length; k++)
            if (s[k] === qs[j]) { if (last >= 0) gaps += k - last - 1; last = k; j++; }
        return j === qs.length ? Math.max(10, 40 - gaps) : -1;
    }
    function frec(key) {
        const h = hist[key];
        if (!h) return 0;
        const days = (Date.now() - h.t) / 86400000;
        return Math.min(25, h.n * 3 / (1 + days / 7));
    }
    function bump(key) {
        const h = hist[key] || { n: 0, t: 0 };
        hist[key] = { n: h.n + 1, t: Date.now() };
        histFile.setText(JSON.stringify(hist));
    }
    function icon(name) {
        if (!name) return "";
        return name.startsWith("/") ? "file://" + name : Quickshell.iconPath(name, true);
    }
    function loadApps() {
        const out = [];
        for (const e of DesktopEntries.applications.values) {
            if (e.noDisplay) continue;
            out.push({ e, id: e.id, n: e.name.toLowerCase(), g: (e.genericName || "").toLowerCase(), k: ((e.keywords || []).join(" ") + " " + (e.comment || "")).toLowerCase() });
        }
        apps = out;
        rebuild();
    }
    function windows() {
        const out = [];
        for (const t of Hyprland.toplevels.values) {
            const o = t.lastIpcObject || ({});
            const cls = o.class || "";
            if (!t.title && !cls) continue;
            const ent = cls ? DesktopEntries.heuristicLookup(cls) : null;
            out.push({ addr: t.address, title: t.title || cls, cls, ws: o.workspace ? o.workspace.id : 0, icon: ent ? ent.icon : cls.toLowerCase() });
        }
        return out;
    }
    function actionItem(a) { return { kind: "act", section: "Actions", title: a.title, sub: "", glyph: a.glyph, act: a }; }
    function appItem(a, section) { return { kind: "app", section, title: a.e.name, sub: a.e.genericName || "", icon: a.e.icon, entry: a.e, key: "app:" + a.id }; }
    function winItem(w) { return { kind: "win", section: "Windows", title: w.title, sub: (w.cls ? w.cls : "") + (w.ws > 0 ? "  ·  workspace " + w.ws : ""), icon: w.icon, glyph: "", win: w }; }

    function rebuild() {
        mode = q.startsWith(">") ? "cmd" : q.startsWith("v ") ? "clip" : q.startsWith("f ") ? "files" : "all";
        const out = [], raw = q;
        if (mode === "cmd") {
            const c = raw.slice(1).trim();
            out.push({ kind: "cmd", section: "Run", title: c || "Type a command", sub: "run", glyph: "", cmd: c, term: false });
            if (c) out.push({ kind: "cmd", section: "Run", title: c, sub: "in a terminal", glyph: "", cmd: c, term: true });
        } else if (mode === "clip") {
            const s = raw.slice(2).trim().toLowerCase();
            for (const c of clipHits) if (!s || c.text.toLowerCase().indexOf(s) >= 0) out.push({ kind: "clip", section: "Clipboard", title: c.text, sub: "", glyph: "", id: c.id });
            if (out.length === 0) out.push({ kind: "none", section: "Clipboard", title: clipHits.length ? "Nothing matches" : "Clipboard history is empty", sub: "", glyph: "" });
        } else if (mode === "files") {
            const s = raw.slice(2).trim();
            for (const f of fileHits) {
                const dir = f.endsWith("/"), p = dir ? f.slice(0, -1) : f, i = p.lastIndexOf("/");
                out.push({ kind: "file", section: "Files", title: p.slice(i + 1), sub: p.slice(0, i).replace(Quickshell.env("HOME"), "~"), glyph: dir ? "" : "", path: f });
            }
            if (out.length === 0) out.push({ kind: "none", section: "Files", title: s ? "No files found" : "Type to search your home folder", sub: "", glyph: "" });
        } else {
            const s = raw.trim().toLowerCase();
            if (s === "") {
                const w = windows();
                for (const x of w.slice(0, 5)) out.push(winItem(x));
                const sug = apps.map(a => ({ a, f: frec("app:" + a.id) })).filter(x => x.f > 0).sort((x, y) => y.f - x.f).slice(0, 6);
                for (const x of sug) out.push(appItem(x.a, "Suggested"));
                for (const id of quick) out.push(Object.assign(actionItem(actions.find(a => a.id === id)), { section: "Quick actions" }));
            } else {
                const c = calc(raw);
                if (c) out.push({ kind: "calc", section: "Result", title: "= " + c.value, sub: c.expr, copy: c.copy, glyph: "" });
                const groups = [];
                const ap = [];
                for (const a of apps) {
                    const sc = Math.max(score(s, a.n), score(s, a.g) * 0.8, score(s, a.k) * 0.5);
                    if (sc > 0) ap.push({ sc: sc + frec("app:" + a.id), it: appItem(a, "Applications") });
                }
                ap.sort((x, y) => y.sc - x.sc);
                if (ap.length) groups.push({ best: ap[0].sc, items: ap.slice(0, 7).map(x => x.it) });
                const wn = [];
                for (const w of windows()) {
                    const sc = Math.max(score(s, w.title.toLowerCase()), score(s, w.cls.toLowerCase()));
                    if (sc > 0) wn.push({ sc: sc + 5, it: winItem(w) });
                }
                wn.sort((x, y) => y.sc - x.sc);
                if (wn.length) groups.push({ best: wn[0].sc, items: wn.slice(0, 4).map(x => x.it) });
                const ac = [];
                for (const a of actions) {
                    const sc = Math.max(score(s, a.title.toLowerCase()), score(s, a.kw) * 0.9);
                    if (sc > 0) ac.push({ sc: sc + frec("act:" + a.id), it: actionItem(a) });
                }
                ac.sort((x, y) => y.sc - x.sc);
                if (ac.length) groups.push({ best: ac[0].sc, items: ac.slice(0, 4).map(x => x.it) });
                groups.sort((x, y) => y.best - x.best);
                for (const g of groups) for (const i of g.items) out.push(i);
                out.push({ kind: "more", section: "Elsewhere", title: "Search files for “" + raw.trim() + "”", sub: "f", glyph: "", text: "f " + raw.trim() });
                out.push({ kind: "web", section: "Elsewhere", title: "Search the web for “" + raw.trim() + "”", sub: "", glyph: "" });
            }
        }
        results = out;
        list.currentIndex = out.length ? 0 : -1;
    }

    function activate(it) {
        if (!it || it.kind === "none") return;
        switch (it.kind) {
        case "app": bump(it.key); Ui.close(); it.entry.execute(); break;
        case "win": {
            Ui.close();
            const a = it.win.addr.startsWith("0x") ? it.win.addr : "0x" + it.win.addr;
            Hyprland.dispatch('hl.dsp.focus({ window = "address:' + a + '" })');
            break;
        }
        case "act": {
            const a = it.act;
            bump("act:" + a.id);
            if (a.page) { Ui.close(); Ui.openPage(a.page); }
            else if (a.fn === "walls") { Ui.close(); Ui.toggleWalls(); }
            else if (a.fn === "dnd") { Notifs.dnd = !Notifs.dnd; Ui.close(); }
            else if (a.fn === "wifi") { Sys.setWifi(!Sys.wifi); Ui.close(); }
            else if (a.fn === "mute") { Audio.toggleMute(); Ui.close(); }
            else { Ui.close(); Sys.run(a.cmd); }
            break;
        }
        case "calc": Ui.close(); Sys.run("printf %s '" + it.copy + "' | wl-copy"); break;
        case "file": Ui.close(); Sys.run("xdg-open '" + it.path.replace(/'/g, "'\\''") + "'"); break;
        case "clip": Ui.close(); Sys.run("cliphist decode " + it.id + " | wl-copy"); break;
        case "cmd":
            if (!it.cmd) return;
            Ui.close();
            if (it.term) Quickshell.execDetached([Config.terminal, "--hold", "sh", "-c", it.cmd]);
            else Sys.run(it.cmd);
            break;
        case "more": field.text = it.text; break;
        case "web": Ui.close(); Sys.run("xdg-open '" + Config.search + encodeURIComponent(q.trim()).replace(/'/g, "%27") + "'"); break;
        }
    }

    // ------------------------------------------------------------------ plumbing
    onQChanged: {
        rebuild();
        if (mode === "files") fileTimer.restart();
        if (mode === "clip" && !clipProc.running && clipHits.length === 0) clipProc.running = true;
    }
    Connections { target: DesktopEntries.applications; function onValuesChanged() { root.loadApps(); } }
    Connections { target: Hyprland.toplevels; function onValuesChanged() { if (root.q.trim() === "" || root.mode === "all") root.rebuild(); } }
    Connections { target: Ui; function onQueryChanged() { if (field.text !== Ui.query) field.text = Ui.query; } }
    Connections { target: Ui; function onOpenChanged() { if (Ui.open) field.forceActiveFocus(); } }
    onVisibleChanged: if (visible) field.forceActiveFocus()
    Component.onCompleted: {
        Hyprland.refreshToplevels();
        field.text = Ui.query;
        loadApps();
        field.forceActiveFocus();
    }

    FileView {
        id: histFile
        path: Quickshell.env("HOME") + "/.config/ddmm/launcher-history.json"
        printErrors: false
        onLoaded: { try { root.hist = JSON.parse(text()); } catch (e) { root.hist = ({}); } root.rebuild(); }
    }
    Timer { id: fileTimer; interval: 180; onTriggered: {
        const s = root.q.slice(2).trim();
        if (s.length < 2) { root.fileHits = []; root.rebuild(); return; }
        fdProc.command = ["fd", "--hidden", "--ignore-case", "--max-results", "40", "--exclude", ".cache", "--exclude", ".git", "--exclude", "node_modules", "--exclude", ".local/share", s, Quickshell.env("HOME")];
        fdProc.running = true;
    } }
    Process {
        id: fdProc
        stdout: StdioCollector { onStreamFinished: { root.fileHits = text.split("\n").filter(x => x); if (root.mode === "files") root.rebuild(); } }
    }
    Process {
        id: clipProc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.clipHits = text.split("\n").filter(x => x).slice(0, 80).map(l => { const i = l.indexOf("\t"); return { id: l.slice(0, i), text: l.slice(i + 1) }; });
                if (root.mode === "clip") root.rebuild();
            }
        }
    }

    // ------------------------------------------------------------------ view
    Item {
        id: box
        width: parent.width; height: 52
        Text { x: 2; anchors.verticalCenter: parent.verticalCenter; text: ""; color: Theme.dim; font.family: Theme.icons; font.pixelSize: 16 }
        TextInput {
            id: field
            anchors { fill: parent; leftMargin: 36; rightMargin: 90 }
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.fg; font.family: Theme.font; font.pixelSize: 24; font.letterSpacing: -0.4; clip: true
            selectByMouse: true; selectionColor: Theme.accent; selectedTextColor: Theme.accentText
            onTextChanged: root.q = text
            Keys.onPressed: ev => {
                const ctrl = ev.modifiers & Qt.ControlModifier;
                if (ev.key === Qt.Key_Tab || (ctrl && (ev.key === Qt.Key_N || ev.key === Qt.Key_J))) { list.currentIndex = Math.min(list.count - 1, list.currentIndex + 1); ev.accepted = true; }
                else if (ev.key === Qt.Key_Backtab || (ctrl && (ev.key === Qt.Key_P || ev.key === Qt.Key_K))) { list.currentIndex = Math.max(0, list.currentIndex - 1); ev.accepted = true; }
                else if (ev.key === Qt.Key_Down) { list.currentIndex = Math.min(list.count - 1, list.currentIndex + 1); ev.accepted = true; }
                else if (ev.key === Qt.Key_Up) { list.currentIndex = Math.max(0, list.currentIndex - 1); ev.accepted = true; }
                else if ((ev.modifiers & Qt.AltModifier) && ev.key >= Qt.Key_1 && ev.key <= Qt.Key_9) { root.activate(root.results[ev.key - Qt.Key_1]); ev.accepted = true; }
            }
            Keys.onReturnPressed: root.activate(root.results[list.currentIndex])
            Keys.onEnterPressed: root.activate(root.results[list.currentIndex])
            Keys.onEscapePressed: { if (text !== "") text = ""; else Ui.close(); }
            Text { visible: !parent.text; text: "Search apps, windows, maths…"; color: Theme.dim; font.family: Theme.serif; font.italic: true; font.pixelSize: 26 }
        }
        Text {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            visible: root.mode !== "all"
            text: root.mode === "cmd" ? "RUN" : root.mode === "clip" ? "CLIPBOARD" : "FILES"
            color: Theme.accent; font.family: Theme.font; font.pixelSize: 10; font.letterSpacing: 2; font.weight: Font.DemiBold
        }
        Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: Theme.faint }
    }

    ListView {
        id: list
        anchors { top: box.bottom; topMargin: 4; left: parent.left; right: parent.right; bottom: foot.top; bottomMargin: 4 }
        model: root.results
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        highlightMoveDuration: 140; highlightResizeDuration: 140
        highlight: Rectangle { radius: 14; color: Theme.card }
        highlightFollowsCurrentItem: true
        section.property: "section"
        section.criteria: ViewSection.FullString
        section.delegate: Item {
            required property string section
            width: list.width; height: 28
            Text { x: 10; anchors.bottom: parent.bottom; anchors.bottomMargin: 4; text: parent.section.toUpperCase(); color: Theme.dim
                font.family: Theme.font; font.pixelSize: 10; font.letterSpacing: 2; font.weight: Font.Medium }
        }
        delegate: Item {
            id: row
            required property int index
            required property var modelData
            readonly property bool sel: ListView.isCurrentItem
            readonly property bool big: modelData.kind === "calc"
            width: list.width; height: big ? 72 : 46

            Item {
                id: tile
                x: 10; anchors.verticalCenter: parent.verticalCenter; width: 30; height: 30
                visible: !row.big
                Image { id: ic; anchors.fill: parent; source: row.modelData.icon ? root.icon(row.modelData.icon) : ""; sourceSize: Qt.size(60, 60); fillMode: Image.PreserveAspectFit; visible: status === Image.Ready }
                Rectangle { anchors.fill: parent; radius: 9; color: Theme.card; visible: !ic.visible
                    Text { anchors.centerIn: parent; text: row.modelData.glyph || ""; color: row.modelData.act && row.modelData.act.id === "shutdown" ? Theme.danger : Theme.fg; font.family: Theme.icons; font.pixelSize: 14 } }
            }
            Column {
                visible: !row.big
                anchors { left: tile.right; leftMargin: 14; right: parent.right; rightMargin: 56; verticalCenter: parent.verticalCenter }
                spacing: 1
                Text { width: parent.width; elide: Text.ElideRight; text: row.modelData.title; color: Theme.fg; font.family: Theme.font; font.pixelSize: 14; font.weight: Font.Medium }
                Text { width: parent.width; visible: text !== ""; elide: Text.ElideRight; text: row.modelData.sub || ""; color: Theme.dim; font.family: Theme.font; font.pixelSize: 11 }
            }
            // calculator result: big serif number
            Column {
                visible: row.big
                anchors { left: parent.left; leftMargin: 14; right: parent.right; rightMargin: 56; verticalCenter: parent.verticalCenter }
                Text { width: parent.width; elide: Text.ElideRight; text: row.modelData.title; color: Theme.fg; font.family: Theme.serif; font.pixelSize: 36 }
                Text { width: parent.width; elide: Text.ElideRight; text: row.modelData.sub + "   ·   ↵ copy"; color: Theme.dim; font.family: Theme.font; font.pixelSize: 11 }
            }
            Text { anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                text: row.sel ? "" : (row.index < 9 ? "⌥" + (row.index + 1) : "")
                color: row.sel ? Theme.fg : Qt.rgba(1, 1, 1, 0.28)
                font.family: row.sel ? Theme.icons : Theme.font; font.pixelSize: row.sel ? 12 : 11 }
            MouseArea { anchors.fill: parent; hoverEnabled: true
                onPositionChanged: list.currentIndex = row.index
                onClicked: root.activate(row.modelData) }
        }
    }

    Text {
        id: foot
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 16
        horizontalAlignment: Text.AlignHCenter
        color: Qt.rgba(1, 1, 1, 0.3)
        font.family: Theme.font; font.pixelSize: 10; font.letterSpacing: 0.6
        text: root.mode === "all" ? "↵ open     ↑↓ select     > run     f files     v clipboard     5km to mi     20% of 80" : "esc to clear     ↵ select"
    }
}
