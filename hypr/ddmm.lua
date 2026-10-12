-- ddmm keybinds for the Lua Hyprland config (0.55+).
-- Add to hyprland.lua:  dofile(os.getenv("HOME") .. "/.config/ddmm/hypr/ddmm.lua")
local ddmm = os.getenv("HOME") .. "/.local/bin/ddmm"

hl.exec_cmd(ddmm .. " run --replace")
hl.exec_cmd(os.getenv("HOME") .. "/.local/bin/ddmm-wallpaper-restore")

hl.bind("SUPER + Space", hl.dsp.exec_cmd(ddmm .. " launcher"))
hl.bind("SUPER + S", hl.dsp.exec_cmd(ddmm .. " island toggle"))
hl.bind("SUPER + G", hl.dsp.exec_cmd(ddmm .. " wallpaper"))
hl.bind("SUPER + K", hl.dsp.exec_cmd(ddmm .. " power"))
hl.bind("SUPER + L", hl.dsp.exec_cmd(ddmm .. " lock"))
hl.bind("SUPER + V", hl.dsp.exec_cmd(ddmm .. " launcher 'v '"))

-- brightness (shows the bar inside the island)
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -q set 5%+; " .. ddmm .. " osd bright"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -q set 5%-; " .. ddmm .. " osd bright"), { locked = true, repeating = true })

-- lock when the lid closes
hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd(ddmm .. " lock"), { locked = true })
