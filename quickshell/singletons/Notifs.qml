pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Notification server + capped history of plain copies. The newest one is shown inside the island.
Singleton {
    id: root
    property bool dnd: false
    property int unread: 0
    property var latest: null
    readonly property alias history: hist
    readonly property int maxHistory: 40

    signal arrived()
    ListModel { id: hist }
    function clear() { hist.clear(); unread = 0; }
    function remove(i) { hist.remove(i); }

    NotificationServer {
        keepOnReload: false
        actionsSupported: true
        bodySupported: true
        imageSupported: true
        onNotification: n => {
            const item = {
                app: n.appName || "",
                summary: n.summary || "",
                body: n.body || "",
                icon: n.image || (n.appIcon ? Quickshell.iconPath(n.appIcon, true) : ""),
                stamp: Qt.formatDateTime(new Date(), "HH:mm"),
                critical: n.urgency === NotificationUrgency.Critical
            };
            hist.insert(0, item);
            if (hist.count > root.maxHistory) hist.remove(root.maxHistory, hist.count - root.maxHistory);
            root.unread++;
            n.tracked = false;
            if (!root.dnd || item.critical) { root.latest = item; root.arrived(); }
        }
    }
}
