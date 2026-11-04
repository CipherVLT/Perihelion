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

-- Cursor: Bibata Modern Classic, 24 px (GTK apps read it from gsettings).
hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORM", "wayland")
-- Qt apps take their look from qt6ct (~/.config/qt6ct/qt6ct.conf).
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
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

-- Keybinds: Veyl OS's set (github.com/CipherVLT/veyl-os keybind.lua) with
-- Perihelion's apps, plus the app drawer, wallpaper picker and power menu.
-- Super+H lists every bind with its description.
local mainMod = "SUPER"
local function key(k) return mainMod .. " + " .. k end
local function bind(k, action, desc, opts)
    opts = opts or {}
    opts.description = desc
    hl.bind(k, action, opts)
end

-- 1. Applications
bind(key("RETURN"), hl.dsp.exec_cmd("kitty"), "Terminal")
bind(key("SHIFT + RETURN"), hl.dsp.exec_cmd("kitty --class perihelion-float"), "Floating terminal (showcase)")
bind(key("E"), hl.dsp.exec_cmd("strata"), "File manager")
bind(key("B"), hl.dsp.exec_cmd("firefox"), "Browser")
bind(key("D"), hl.dsp.exec_cmd("fuzzel"), "App launcher")
bind(key("A"), hl.dsp.exec_cmd("perihelion-drawer"), "App drawer")
bind(key("S"), hl.dsp.exec_cmd("steam"), "Steam")
bind(key("L"), hl.dsp.exec_cmd("loginctl lock-session"), "Lock screen")
bind(key("SHIFT + E"), hl.dsp.exit(), "Log out")
bind(key("M"), hl.dsp.exit(), "Log out")
bind(key("SHIFT + Q"), hl.dsp.exec_cmd("perihelion-power-menu"), "Power menu")
bind(key("T"), hl.dsp.exec_cmd("horizon-settings"), "Settings")
bind(key("H"), hl.dsp.exec_cmd("perihelion-keys"), "Show all keybinds")
bind(key("SHIFT + W"), hl.dsp.exec_cmd("perihelion-wallpaper-picker"), "Wallpaper picker")
bind(key("V"), hl.dsp.exec_cmd("horizon-clipstack-pick"), "Clipboard history")
bind(key("O"), hl.dsp.exec_cmd("eh-ipc overview-toggle"), "Overview")
bind(key("SHIFT + D"), hl.dsp.exec_cmd("pkill -x horizon; sleep 0.5; horizon"), "Restart Event Horizon")

-- 2. Window management
bind(key("Q"), hl.dsp.window.close(), "Close window")
bind(key("W"), hl.dsp.window.float({ action = "toggle" }), "Toggle floating")
bind(key("F"), hl.dsp.window.fullscreen(), "Toggle fullscreen")

-- Glass (Super+G): the focused window turns see-through, the wallpaper
-- blurred behind it; press again for solid. kitty is already glass on its
-- own (see /etc/xdg/kitty/kitty.conf).
local glass = {}
local function setGlass(on)
    local override = on and 1 or 0
    hl.dispatch(hl.dsp.window.set_prop({ prop = "opacity_override", value = override }))
    hl.dispatch(hl.dsp.window.set_prop({ prop = "opacity", value = on and 0.85 or 1.0 }))
    hl.dispatch(hl.dsp.window.set_prop({ prop = "opacity_inactive_override", value = override }))
    hl.dispatch(hl.dsp.window.set_prop({ prop = "opacity_inactive", value = on and 0.80 or 1.0 }))
end
local function toggleGlass()
    local w = hl.get_active_window()
    if not w then return end
    local id = tostring(w.address or w.pid)
    local on = not glass[id]
    local ok, err = pcall(setGlass, on)
    if ok then
        glass[id] = on or nil
    else
        hl.notification.create({ text = "Glass: " .. tostring(err), timeout = 4000 })
    end
end
bind(key("G"), toggleGlass, "Glass (see-through) window")

-- Floating terminal (Super+Shift+Return): half the screen, bottom-right
-- corner, for desktop showcases. Drag it with Super+left mouse.
hl.window_rule({
    match = { class = "^perihelion-float$" },
    float = true,
    size = { "monitor_w*0.5", "monitor_h*0.55" },
    move = { "monitor_w-window_w-12", "monitor_h-window_h-12" },
})

-- Always-glass apps. Add your own the same way (class from: hyprctl clients).
hl.window_rule({ match = { class = "^moe\\.launcher\\.the-honkers-railway-launcher$" }, opacity = 0.85 })

-- 3. Navigation and layout
bind(key("TAB"), hl.dsp.focus({ workspace = "m+1" }), "Next workspace on monitor")
bind(key("SHIFT + TAB"), hl.dsp.focus({ workspace = "m-1" }), "Previous workspace on monitor")
for _, dir in ipairs({ "left", "right", "up", "down" }) do
    bind(key(dir), hl.dsp.focus({ direction = dir }), "Focus " .. dir)
end
bind("ALT + TAB", hl.dsp.window.cycle_next(), "Cycle windows")

bind(key("SHIFT + right"), hl.dsp.window.resize({ x = 30, y = 0, relative = true }), "Resize window right")
bind(key("SHIFT + left"), hl.dsp.window.resize({ x = -30, y = 0, relative = true }), "Resize window left")
bind(key("SHIFT + up"), hl.dsp.window.resize({ x = 0, y = -30, relative = true }), "Resize window up")
bind(key("SHIFT + down"), hl.dsp.window.resize({ x = 0, y = 30, relative = true }), "Resize window down")

-- Floating windows nudge by 30 px; tiled windows swap in that direction.
local function moveOrSwap(direction, x, y)
    return function()
        local w = hl.get_active_window()
        if w and w.floating then
            hl.dispatch(hl.dsp.window.move({ x = x, y = y, relative = true }))
        else
            hl.dispatch(hl.dsp.window.move({ direction = direction }))
        end
    end
end
bind(key("SHIFT + CTRL + left"), moveOrSwap("left", -30, 0), "Move or swap window left")
bind(key("SHIFT + CTRL + right"), moveOrSwap("right", 30, 0), "Move or swap window right")
bind(key("SHIFT + CTRL + up"), moveOrSwap("up", 0, -30), "Move or swap window up")
bind(key("SHIFT + CTRL + down"), moveOrSwap("down", 0, 30), "Move or swap window down")

-- 4. Screenshots open in Satty (annotate, copy, save to ~/Pictures/Screenshots)
bind(key("SHIFT + S"), hl.dsp.exec_cmd("horizon-screenshot"), "Screenshot region")
bind(key("PRINT"), hl.dsp.exec_cmd("horizon-screenshot"), "Screenshot region")
bind("PRINT", hl.dsp.exec_cmd("horizon-screenshot screen"), "Screenshot current screen")
bind("ALT + PRINT", hl.dsp.exec_cmd("horizon-screenshot full"), "Screenshot all screens")

-- 5. Workspaces
for i = 1, 9 do
    bind(key(tostring(i)), hl.dsp.focus({ workspace = i }), "Workspace " .. i)
    bind(key("SHIFT + " .. i), hl.dsp.window.move({ workspace = i }), "Move to workspace " .. i)
end
bind(key("0"), hl.dsp.focus({ workspace = 10 }), "Workspace 10")
bind(key("SHIFT + 0"), hl.dsp.window.move({ workspace = 10 }), "Move to workspace 10")

bind(key("CTRL + right"), hl.dsp.focus({ workspace = "r+1" }), "Next workspace")
bind(key("CTRL + left"), hl.dsp.focus({ workspace = "r-1" }), "Previous workspace")
bind(key("CTRL + down"), hl.dsp.focus({ workspace = "empty" }), "Open empty workspace")
bind(key("CTRL + ALT + right"), hl.dsp.window.move({ workspace = "r+1" }), "Move to next workspace")
bind(key("CTRL + ALT + left"), hl.dsp.window.move({ workspace = "r-1" }), "Move to previous workspace")

-- 6. Mouse
bind(key("mouse_down"), hl.dsp.focus({ workspace = "e+1" }), "Scroll to next workspace")
bind(key("mouse_up"), hl.dsp.focus({ workspace = "e-1" }), "Scroll to previous workspace")
bind(key("mouse:272"), hl.dsp.window.drag(), "Drag window", { mouse = true })
bind(key("mouse:273"), hl.dsp.window.resize(), "Resize window", { mouse = true })
bind(key("X"), hl.dsp.window.resize(), "Resize mode")

-- 7. Media keys (work on the lock screen too)
bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), "Play or pause", { locked = true })
bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), "Next track", { locked = true })
bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), "Previous track", { locked = true })
bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"), "Volume up", { locked = true })
bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), "Volume down", { locked = true })
bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), "Mute", { locked = true })
bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set +5%"), "Brightness up", { locked = true })
bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), "Brightness down", { locked = true })

-- Window border colours from Event Horizon (rewritten when you pick a
-- wallpaper); last, so they win over the defaults above.
include(config_dir .. "/hyprland/colors.lua")
