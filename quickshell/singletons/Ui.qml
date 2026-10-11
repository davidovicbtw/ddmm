pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root
    readonly property var pageNames: ["home", "media", "system", "notifs", "power"]
    readonly property var pageTitles: ["Today", "Now playing", "System", "Notifications", "Power"]
    property bool hovered: false
    property bool pinned: false          // opened by IPC, stays until closed
    property bool toast: false           // opened by a notification
    property bool osdOn: false           // volume / brightness feedback
    property string osdKind: "vol"
    property real osdValue: 0
    property bool osdMuted: false
    // live activity (workspace switch, track change, charger) shown without hovering
    property string flashKind: ""
    property bool flashOn: false
    property var flashData: ({})
    property bool spotlight: false       // launcher: the island moves to the middle and becomes a search box
    property bool walls: false           // wallpaper picker, same idea
    property bool powerMenu: false       // power menu: same morph as the wallpaper picker
    property real spotlightH: 120
    property int page: 0
    property double stamp: 0             // last time something opened (guards the Super-tap)
    property int powerSel: 0
    property bool powerHold: false
    property string query: ""
    readonly property bool open: hovered || pinned
    readonly property string pageName: pageNames[page]

    function setPage(i) { page = Math.max(0, Math.min(pageNames.length - 1, i)); }
    function openPage(name, q) {
        const i = pageNames.indexOf(name);
        if (i < 0) return;
        if (pinned && page === i) { close(); return; }
        query = q || "";
        stamp = Date.now();
        page = i; pinned = true;
    }
    function showOsd(kind, v, muted) { osdKind = kind; osdValue = v; osdMuted = !!muted; flashOn = false; osdOn = true; }
    function flash(kind, data) { flashKind = kind; flashData = data || ({}); osdOn = false; flashOn = true; }
    function toggle() { stamp = Date.now(); if (pinned) close(); else { hovered = false; pinned = true; } }
    function openSpotlight(q) {
        if (spotlight && !q) { close(); return; }
        pinned = false; hovered = false; walls = false; powerMenu = false;
        query = q || "";
        stamp = Date.now();
        spotlight = true;
    }
    function toggleWalls() {
        if (walls) { walls = false; return; }
        pinned = false; hovered = false; spotlight = false; powerMenu = false;
        stamp = Date.now();
        walls = true;
    }
    function togglePowerMenu() {
        if (powerMenu) { powerMenu = false; return; }
        pinned = false; hovered = false; spotlight = false; walls = false;
        stamp = Date.now();
        powerSel = 0; powerHold = false;
        powerMenu = true;
    }
    function close() { pinned = false; hovered = false; toast = false; spotlight = false; walls = false; powerMenu = false; powerHold = false; }
}
