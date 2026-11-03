# Configuring simpbar (Mango flavor)

Perihelion's Mango flavor uses [simpbar](https://github.com/jaytheoutpatient/simpbar)
by **jaytheoutpatient**, a native Zig/Wayland bar. Everything about it lives in
one file:

```
~/.config/simpbar/config.json
```

The untouched Perihelion default is `/usr/share/perihelion/simpbar/config.json`.
To start over: `cp /usr/share/perihelion/simpbar/config.json ~/.config/simpbar/`.

**Apply changes:** save the file, then press **Super+Shift+D** (restarts the bar),
or reload it live with `pkill -USR1 -x simpbar`. If the bar suddenly looks
like simpbar's stock grey bar, the file has a mistake (a missing comma or
quote, or a color that isn't `#RRGGBB`) and simpbar fell back to its built-in
defaults: run `simpbar` in a terminal to see which line it complains about.

Edit it with `nano ~/.config/simpbar/config.json` (Ctrl+O saves, Ctrl+X quits).

## Layout

The bar has three groups:

```json
"modules": {
  "left":   [ { "kind": "workspaces" }, { "kind": "mpris" }, { "kind": "cava" } ],
  "center": [ { "kind": "launchers" },  { "kind": "clock" } ],
  "right":  [ { "kind": "power" }, { "kind": "battery" }, { "kind": "volume" },
              { "kind": "network" }, { "kind": "tray" }, { "kind": "layout" } ]
}
```

- **left** and **center** are drawn left to right.
- **right** is drawn from the screen edge inward: the **first** entry is the
  one at the far right (Perihelion puts the power button there).
- Remove a module by deleting its `{ ... }` entry, or keep it with
  `"enabled": false`.

### Which modules go where

| Group | Modules |
|---|---|
| left, center | `workspaces`, `mpris` (now playing), `clock`, `launchers` |
| left (Perihelion) | `cava` as a mirrored sound wave, best right after `mpris` |
| right | `power`, `battery`, `volume`, `network`, `tray`, `layout` (Mango layout picker), `cava`, `cpu`, `cpu_temp`, `ram`, `disk`, `weather`, `custom_script`, `drawer_toggle` |

A module put in a group that doesn't draw it is silently skipped.

Not useful on Perihelion: `pacman` (Arch updates) and `waypaper` (removed upstream).
`weather` asks wttr.in for the forecast, so it is off by default.

### The drawer

Right-group modules can hide behind a toggle button: add
`{ "kind": "drawer_toggle" }` and give the modules to hide `"in_drawer": true`:

```json
{ "kind": "drawer_toggle" },
{ "kind": "tray", "in_drawer": true },
{ "kind": "cpu", "in_drawer": true }
```

### Your own module (`custom_script`)

Shows the output of a command, refreshed every `interval_secs` seconds:

```json
{ "kind": "custom_script", "label": "GPU", "command": "sensors | awk '/edge/ {print $2}'", "interval_secs": 5 }
```

## Launcher buttons (center dock)

```json
"launchers": [
  { "label": "Browser", "command": "firefox" },
  { "label": "Files",   "command": "strata" },
  { "label": "Term",    "command": "kitty" },
  { "label": "Steam",   "command": "steam" }
]
```

`command` is any shell command. The icon is found automatically from the
app's desktop entry; set `"icon": "icon-name"` to pick one yourself. Add an
app by adding a line (mind the commas between entries).

## Appearance

Colors are `"#RRGGBB"`. Perihelion uses Catppuccin Macchiato
(<https://catppuccin.com/palette/>):

| Name | Hex | Used for |
|---|---|---|
| Base | `#24273A` | bar background (`bg_color`) |
| Text | `#CAD3F5` | text (`text_color`) |
| Blue | `#8AADF4` | accent: border, active workspace, bezel |
| Pink | `#F5BDE6` | cava |
| Lavender | `#B7BDF8` | |
| Mauve | `#C6A0F6` | |
| Yellow | `#EED49F` | |
| Red | `#ED8796` | |
| Surface0 | `#363A4F` | module pills, hover |
| Overlay0 | `#6E738D` | inactive workspaces |

| Key | Values | Perihelion |
|---|---|---|
| `position` | `"top"`, `"bottom"` | `"bottom"` |
| `bar_mode` | `"taskbar"` (full width), `"dock"` | `"taskbar"` |
| `bar_height` | pixels | `28` |
| `bg_opacity_percent` | 0–100 | `90` |
| `corner_radius_px` | pixels | `0` |
| `border_top_px`, `border_bottom_px`, `border_left_px`, `border_right_px` | pixels | top `2` (the edge facing your windows) |
| `border_color` | color | blue |
| `workspace_active_color`, `workspace_inactive_color` | color | blue, overlay0 |
| `module_pills`, `pill_borders` | `true`/`false` | pills on, pill borders off |
| `module_pill_opacity` | 0–100 | `100` |
| `clock_format` | `"time_24h"`, `"time_24h_seconds"`, `"time_12h"`, `"date_24h"`, `"date_12h"` | `"date_12h"` |
| `bezel_style` | `"solid"`, `"matugen"`, `"rainbow-puke"` | `"solid"` |
| `bezel_effect` | `"solid"`, `"rotating"`, `"breathing"` | `"solid"` |
| `animations_enabled` | `true`/`false` | `true` |
| `monitor` | output name (e.g. `"DP-1"`), empty = all | all |
| `font_path` | a `.ttf` file | JetBrainsMono Nerd Font Regular |

### cava (audio visualizer)

| Key | Values | Perihelion |
|---|---|---|
| `cava_color` | color | `#F5BDE6` (pink) |
| `cava_style` | `"bars"`, `"wave"`, `"curve"` | `"bars"` |
| `bg_mode` | `"none"`, `"cava"` (equalizer across the whole bar background), `"matrix"`, `"lava"` | `"none"` |
| `cava_bg_strength` | 0–100, how strongly `bg_mode: "cava"` tints the bar | `35` |

`cava` in **left** draws a mirrored sound wave (a Perihelion patch to
simpbar, `build/patches/simpbar-left-cava-wave.patch`); in **right** it is
simpbar's small equalizer. Move the `{ "kind": "cava" }` entry to switch.

For the visualizer filling the whole bar behind the modules, try
`"bg_mode": "cava"` with `"cava_style": "curve"` and `"cava_bg_strength": 45`.

## Wallpaper to match

```sh
perihelion-wallpaper ~/Pictures/your-image.png
```

It is remembered across logins. Deep indigo and lavender art (like synthwave
or pixel-art album covers) sits well with the Macchiato blue/pink accents.

## Troubleshooting

- Bar back to stock grey after an edit: `simpbar` in a terminal shows the config error.
- Power button: opens `perihelion-power-menu` (also Super+Shift+Q).
- `perihelion-doctor` reports whether simpbar is running and which build it is.
