#!/usr/bin/env bash
# ddmm installer - a Dynamic Island desktop for Hyprland, built on Quickshell.
#   ./install.sh              install (asks before anything big)
#   ./install.sh --yes        non-interactive
#   ./install.sh --link       symlink instead of copy (for hacking on it)
#   ./install.sh --check      only check dependencies
#   ./install.sh --uninstall  remove ddmm (keeps your settings unless --purge)
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QS_DIR="$HOME/.config/quickshell/ddmm"
BIN_DIR="$HOME/.local/bin"
CFG_DIR="$HOME/.config/ddmm"
FONT_DIR="$HOME/.local/share/fonts/ddmm"
STAMP="$(date +%Y%m%d-%H%M%S)"

YES=0; LINK=0; CHECK=0; UNINSTALL=0; PURGE=0; FONTS=1
for a in "$@"; do case "$a" in
  -y|--yes) YES=1;; --link) LINK=1;; --check) CHECK=1;; --uninstall) UNINSTALL=1;;
  --purge) PURGE=1;; --no-fonts) FONTS=0;;
  -h|--help) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
  *) echo "unknown option: $a (try --help)" >&2; exit 2;; esac; done

if [ -t 1 ]; then B=$'\e[1m'; G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; D=$'\e[2m'; N=$'\e[0m'; else B=; G=; Y=; R=; D=; N=; fi
say()  { printf '%s\n' "${B}==>${N} $*"; }
ok()   { printf '  %s✓%s %s\n' "$G" "$N" "$*"; }
warn() { printf '  %s!%s %s\n' "$Y" "$N" "$*"; }
bad()  { printf '  %s✗%s %s\n' "$R" "$N" "$*"; }
ask()  { [ "$YES" = 1 ] && return 0; read -r -p "$1 [Y/n] " r </dev/tty || return 1; [[ -z "$r" || "$r" =~ ^[Yy] ]]; }

# ---------- uninstall ----------
if [ "$UNINSTALL" = 1 ]; then
  say "Uninstalling ddmm"
  "$BIN_DIR/ddmm" stop 2>/dev/null || true
  rm -rf "$QS_DIR" "$BIN_DIR/ddmm" "$BIN_DIR/ddmm-wallcolors" "$CFG_DIR/hypr"
  ok "removed shell, CLI and keybind snippets"
  if [ "$PURGE" = 1 ]; then rm -rf "$CFG_DIR" "$FONT_DIR" "$HOME/.cache/ddmm"; ok "removed settings, fonts, cache"
  else echo "  ${D}settings in $CFG_DIR and fonts kept (use --purge to remove)${N}"; fi
  echo "  Remember to delete the ddmm lines from your Hyprland config."
  exit 0
fi

# ---------- dependency check ----------
say "Checking dependencies"
have() { command -v "$1" >/dev/null 2>&1; }
. /etc/os-release 2>/dev/null || true
DISTRO="${ID:-unknown}${ID_LIKE:+ ($ID_LIKE)}"
ok "distro: $DISTRO"

MISSING_REQ=(); MISSING_OPT=()
req() { have "$1" && ok "$1" || { bad "$1  ${D}- $2${N}"; MISSING_REQ+=("$1"); }; }
opt() { have "$1" && ok "$1" || { warn "$1  ${D}- $2${N}"; MISSING_OPT+=("$1"); }; }
req qs            "Quickshell (git/0.3+): the shell runtime"
req hyprctl       "Hyprland: workspaces, windows, keybinds"
req python3       "runs the ddmm CLI"
req awww          "wallpaper daemon (swww successor); needed for the wallpaper picker"
opt hyprlock      "provides the PAM service the lock screen authenticates with"
opt cliphist      "clipboard history in the launcher ('v ')"
opt wl-copy       "wl-clipboard: copy results"
opt fd            "file search in the launcher ('f ')"
opt brightnessctl "brightness slider + OSD"
opt pw-play       "pipewire: system sounds"
opt nmcli         "NetworkManager: Wi-Fi tile"
opt bluetoothctl  "bluez: Bluetooth tile"
opt powerprofilesctl "power-profiles-daemon: power saver tile"
opt kitty         "default terminal (change with: ddmm set terminal=foot)"
opt grim          "screenshots (not required)"
python3 -c 'import PIL' 2>/dev/null && ok "python-pillow" || { warn "python-pillow  ${D}- colour tags in the wallpaper picker${N}"; MISSING_OPT+=("python-pillow"); }
[ -e /etc/pam.d/hyprlock ] && ok "/etc/pam.d/hyprlock" || warn "/etc/pam.d/hyprlock missing - install hyprlock or the lock screen can't verify your password"

if [ "${#MISSING_REQ[@]}" -gt 0 ] || [ "${#MISSING_OPT[@]}" -gt 0 ]; then
  echo
  case "${ID:-}${ID_LIKE:-}" in
    *arch*) echo "  Arch hint:  ${B}yay -S quickshell-git hyprland awww hyprlock cliphist wl-clipboard fd brightnessctl pipewire networkmanager bluez power-profiles-daemon kitty python-pillow${N}";;
    *fedora*) echo "  Fedora hint: quickshell and awww come from COPR/cargo; the rest: ${B}sudo dnf install hyprland hyprlock cliphist wl-clipboard fd-find brightnessctl pipewire-utils NetworkManager python3-pillow kitty${N}";;
    *debian*|*ubuntu*) echo "  Debian/Ubuntu hint: build quickshell + awww from source; the rest: ${B}sudo apt install hyprland hyprlock cliphist wl-clipboard fd-find brightnessctl pipewire-bin network-manager python3-pil kitty${N}";;
    *) echo "  Install the missing packages with your package manager.";;
  esac
  echo
fi
[ "$CHECK" = 1 ] && exit $(( ${#MISSING_REQ[@]} > 0 ))
if [ "${#MISSING_REQ[@]}" -gt 0 ]; then
  ask "Required tools are missing. Install ddmm anyway?" || { echo "aborted"; exit 1; }
fi

# ---------- install files ----------
backup() { [ -e "$1" ] || [ -L "$1" ] && { mv "$1" "$1.bak-$STAMP"; warn "existing $(basename "$1") moved to $1.bak-$STAMP"; } || true; }
put() { # put <src> <dest>
  mkdir -p "$(dirname "$2")"
  if [ -L "$2" ] && [ "$(readlink -f "$2")" = "$(readlink -f "$1")" ]; then return; fi
  if [ "$LINK" = 0 ] && [ -e "$2" ] && diff -rq "$1" "$2" >/dev/null 2>&1; then return; fi
  backup "$2"
  if [ "$LINK" = 1 ]; then ln -s "$1" "$2"; else cp -r "$1" "$2"; fi
}

say "Installing"
"$BIN_DIR/ddmm" stop >/dev/null 2>&1 || true
put "$SRC/quickshell" "$QS_DIR";                 ok "shell      -> $QS_DIR"
put "$SRC/bin/ddmm" "$BIN_DIR/ddmm";             ok "CLI        -> $BIN_DIR/ddmm"
put "$SRC/bin/ddmm-wallcolors" "$BIN_DIR/ddmm-wallcolors"
chmod +x "$SRC/bin/ddmm" "$SRC/bin/ddmm-wallcolors"
mkdir -p "$CFG_DIR/hypr" "$HOME/Pictures/Wallpapers"
cp "$SRC/hypr/ddmm.conf" "$SRC/hypr/ddmm.lua" "$CFG_DIR/hypr/"
ok "keybinds   -> $CFG_DIR/hypr/{ddmm.conf,ddmm.lua}"
case ":$PATH:" in *":$BIN_DIR:"*) ;; *) warn "$BIN_DIR is not in your PATH - add it to your shell profile";; esac

# ---------- fonts ----------
need_fonts() { fc-list 2>/dev/null | grep -qi "Instrument Serif" && fc-list | grep -qi "Geist"; }
if [ "$FONTS" = 1 ]; then
  if need_fonts; then ok "fonts already installed (Geist, Geist Mono, Instrument Serif)"
  elif have curl && ask "Download fonts (Geist, Geist Mono, Instrument Serif; SIL OFL) from Google Fonts?"; then
    mkdir -p "$FONT_DIR"
    base="https://github.com/google/fonts/raw/main/ofl"
    for f in "instrumentserif/InstrumentSerif-Regular.ttf" "instrumentserif/InstrumentSerif-Italic.ttf" \
             "geist/Geist%5Bwght%5D.ttf" "geistmono/GeistMono%5Bwght%5D.ttf"; do
      out="$FONT_DIR/$(basename "${f//%5B/[}" | sed 's/%5D/]/')"
      curl -fsSL "$base/$f" -o "$out" && ok "$(basename "$out")" || warn "could not download $f"
    done
    fc-cache -f "$FONT_DIR" >/dev/null 2>&1 || true
  else warn "skipping fonts - the UI will fall back to a system font and look off"; fi
fi

# ---------- first-run niceties ----------
[ -f "$CFG_DIR/settings.json" ] || echo '{}' > "$CFG_DIR/settings.json"

echo
say "Done. Next steps"
cat <<EOT
  1. Hook it into Hyprland (pick your config style):
       ${B}hyprland.conf${N}   source = ~/.config/ddmm/hypr/ddmm.conf
       ${B}hyprland.lua${N}    dofile(os.getenv("HOME") .. "/.config/ddmm/hypr/ddmm.lua")
     Remove any other bar (waybar, ags, ...) from your autostart - the island is the whole UI.
  2. Start it now:        ${B}ddmm run${N}
  3. Preview the lock screen safely:  ${B}ddmm lockdemo${N}   (Esc leaves)
  4. Put wallpapers in ~/Pictures/Wallpapers, press ${B}SUPER+G${N}
  5. Tweak things:        ${B}ddmm list${N}  /  ${B}ddmm set accent=#7aa2ff${N}

  Keys: SUPER+Space launcher · SUPER+S island · SUPER+G wallpapers · SUPER+K power · SUPER+L lock
EOT
if have qs && [ -n "${WAYLAND_DISPLAY:-}" ] && ask "Start ddmm now?"; then "$BIN_DIR/ddmm" run --replace || true; fi
