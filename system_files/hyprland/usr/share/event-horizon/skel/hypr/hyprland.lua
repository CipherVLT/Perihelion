-- Perihelion default Hyprland config (Lua; Hyprland 0.57 reads only Lua).
-- Seeded once by /usr/bin/event-horizon-session. Later logins keep your
-- edits. Move this file aside to get a fresh copy at the next login.

local config_dir = (os.getenv("HOME") or "") .. "/.config/hypr"

-- Run a generated file if it exists. dofile (not require) so it runs again
-- on every reload.
local function include(path)
    local f = io.open(path)
    if f then
        f:close()
        dofile(path)
    end
end

-- NVIDIA / hybrid-GPU settings, regenerated at every login. Do not edit
-- eh/gpu.lua; put overrides further down in this file instead.
include(config_dir .. "/eh/gpu.lua")

-- Scale 1: Event Horizon doesn't support fractional scales (1.25, 1.5) yet;
-- its wallpaper and settings window draw at the wrong size with them. Use 2
-- on a 4K screen. Text and panel sizes: Settings > Appearance.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

hl.env("XCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("GDK_BACKEND", "wayland,x11")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

hl.config({
    input = {
        kb_layout = "us",
        follow_mouse = 1,
        sensitivity = 0,
        touchpad = {
            natural_scroll = true,
            disable_while_typing = true,
        },
    },

    general = {
        -- Tight, even spacing: 2 px between windows, 4 px to the screen
        -- edges, so tiles line up with the monitor without wasted space.
        gaps_in = 2,
        gaps_out = 4,
        border_size = 2,
        -- Drag the gap or border between two windows to resize them.
        resize_on_border = true,
        col = {
            active_border = "rgba(e4a15aee)",
            inactive_border = "rgba(2c3038aa)",
        },
        layout = "dwindle",
        snap = { enabled = true },
    },

    decoration = {
        rounding = 8,
        -- Frosted glass behind see-through windows (kitty, see
        -- /etc/xdg/kitty/kitty.conf).
        blur = {
            enabled = true,
            size = 7,
            passes = 2,
            new_optimizations = true,
            ignore_opacity = true,
            xray = false,
        },
    },

    animations = { enabled = true },

    dwindle = { preserve_split = true },

    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
    },
})

hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE")
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE")
    hl.exec_cmd("horizon")
end)

local mod = "SUPER"
local function key(k) return mod .. " + " .. k end

hl.bind(key("Return"), hl.dsp.exec_cmd("kitty"))
hl.bind(key("Q"), hl.dsp.window.close())
hl.bind(key("M"), hl.dsp.exit())
hl.bind(key("F"), hl.dsp.window.fullscreen())
hl.bind(key("Space"), hl.dsp.exec_cmd("fuzzel"))
-- Screenshots open in Satty (annotate, copy, save to ~/Pictures/Screenshots,
-- save as). horizon-screenshot opens one editor at a time.
hl.bind(key("SHIFT + S"), hl.dsp.exec_cmd("horizon-screenshot"))
hl.bind(key("Print"), hl.dsp.exec_cmd("horizon-screenshot"))
hl.bind("Print", hl.dsp.exec_cmd("horizon-screenshot screen"))
hl.bind("ALT + Print", hl.dsp.exec_cmd("horizon-screenshot full"))
hl.bind(key("V"), hl.dsp.window.float({ action = "toggle" }))
hl.bind(key("P"), hl.dsp.window.pseudo())
hl.bind(key("T"), hl.dsp.layout("togglesplit"))

for k, dir in pairs({ left = "left", right = "right", up = "up", down = "down",
                      H = "left", L = "right", K = "up", J = "down" }) do
    hl.bind(key(k), hl.dsp.focus({ direction = dir }))
end
for _, dir in ipairs({ "left", "right", "up", "down" }) do
    hl.bind(key("SHIFT + " .. dir), hl.dsp.window.move({ direction = dir }))
end

for i = 1, 9 do
    hl.bind(key(tostring(i)), hl.dsp.focus({ workspace = i }))
    hl.bind(key("SHIFT + " .. i), hl.dsp.window.move({ workspace = i }))
end

hl.bind(key("mouse:272"), hl.dsp.window.drag(), { mouse = true })
hl.bind(key("mouse:273"), hl.dsp.window.resize(), { mouse = true })

-- Resize the focused window from the keyboard, 30 px per press.
hl.bind(key("ALT + right"), hl.dsp.window.resize({ x = 30, y = 0, relative = true }))
hl.bind(key("ALT + left"), hl.dsp.window.resize({ x = -30, y = 0, relative = true }))
hl.bind(key("ALT + up"), hl.dsp.window.resize({ x = 0, y = -30, relative = true }))
hl.bind(key("ALT + down"), hl.dsp.window.resize({ x = 0, y = 30, relative = true }))

-- Window border colours from Event Horizon (rewritten when you pick a
-- wallpaper); last, so they win over the defaults above.
include(config_dir .. "/hyprland/colors.lua")
