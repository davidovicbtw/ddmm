-- ddmm keybinds for the Lua Hyprland config (0.55+).
-- Add to hyprland.lua:  dofile(os.getenv("HOME") .. "/.config/ddmm/hypr/ddmm.lua")
local ddmm = os.getenv("HOME") .. "/.local/bin/ddmm"

hl.exec_cmd(ddmm .. " run --replace")

hl.bind("SUPER + Space", hl.dsp.exec_cmd(ddmm .. " launcher"))
hl.bind("SUPER + S", hl.dsp.exec_cmd(ddmm .. " island toggle"))
hl.bind("SUPER + G", hl.dsp.exec_cmd(ddmm .. " wallpaper"))
hl.bind("SUPER + K", hl.dsp.exec_cmd(ddmm .. " power"))
hl.bind("SUPER + L", hl.dsp.exec_cmd(ddmm .. " lock"))
hl.bind("SUPER + V", hl.dsp.exec_cmd(ddmm .. " launcher 'v '"))
