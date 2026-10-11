import QtQuick
import "../singletons"

Item {
    id: root
    readonly property bool ownsWheel: list.contentHeight > list.height
    Row {
        id: top
        width: parent.width; height: 26
        spacing: 22; layoutDirection: Qt.RightToLeft
        Text { text: "Clear all"; color: Theme.dim; font.family: Theme.font; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter
            MouseArea { anchors.fill: parent; onClicked: Notifs.clear() } }
        Text { text: Notifs.dnd ? "Do not disturb · on" : "Do not disturb · off"; color: Notifs.dnd ? Theme.accent : Theme.dim; font.family: Theme.font; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter
            MouseArea { anchors.fill: parent; onClicked: Notifs.dnd = !Notifs.dnd } }
    }
    ListView {
        id: list
        anchors { top: top.bottom; topMargin: 2; left: parent.left; right: parent.right; bottom: parent.bottom }
        model: Notifs.history; spacing: 0; clip: true
        boundsBehavior: Flickable.StopAtBounds
        add: Transition { NumberAnimation { property: "opacity"; from: 0; duration: 240 } }
        remove: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 160 } }
        displaced: Transition { NumberAnimation { properties: "y"; duration: 240; easing.type: Easing.OutCubic } }
        delegate: Item {
            id: row
            required property int index
            required property string app
            required property string summary
            required property string body
            required property string stamp
            required property bool critical
            width: list.width; height: 56
            Rectangle { anchors { bottom: parent.bottom; left: parent.left; right: parent.right } height: 1; color: Theme.faint }
            Column { anchors { left: parent.left; right: parent.right; rightMargin: 90; verticalCenter: parent.verticalCenter } spacing: 2
                Text { width: parent.width; elide: Text.ElideRight; color: row.critical ? Theme.danger : Theme.fg; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.Medium; text: row.summary }
                Text { width: parent.width; elide: Text.ElideRight; color: Theme.dim; font.family: Theme.font; font.pixelSize: 12
                    text: (row.app ? row.app + "  ·  " : "") + row.body.replace(/<[^>]*>/g, "").split("\n")[0] } }
            Text { anchors { right: parent.right; rightMargin: 30; verticalCenter: parent.verticalCenter } text: row.stamp; color: Theme.dim; font.family: Theme.mono; font.pixelSize: 11 }
            Text { anchors { right: parent.right; verticalCenter: parent.verticalCenter } text: ""; color: Theme.dim; font.family: Theme.icons; font.pixelSize: 11
                MouseArea { anchors.fill: parent; anchors.margins: -9; onClicked: Notifs.remove(row.index) } }
        }
        Text { anchors.centerIn: parent; visible: list.count === 0; text: "All quiet."; color: Theme.dim; font.family: Theme.serif; font.italic: true; font.pixelSize: 26 }
    }
}
