pragma Singleton
import QtQuick
import Quickshell

// Freedesktop theme sounds through pw-play. Toggle with `ddmm set sounds=false`.
Singleton {
    id: root
    readonly property string dir: "/usr/share/sounds/freedesktop/stereo/"
    property double _last: 0

    function play(name, minGap) {
        if (!Config.sounds) return;
        const now = Date.now();
        if (now - _last < (minGap || 0)) return;
        _last = now;
        Quickshell.execDetached(["pw-play", "--volume", String(Config.soundVolume), dir + name + ".oga"]);
    }
}
