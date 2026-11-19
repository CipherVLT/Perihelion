# Configuring Perihelion Bar (Mango flavor)

Perihelion's Mango flavor uses Perihelion Bar, from
[Perihelion Shell](https://github.com/CipherVLT/perihelion-shell), a native
Zig/Wayland bar. Everything about it lives in
one file:

```
~/.config/perihelionbar/config.json
```

The untouched Perihelion default is `/usr/share/perihelion/perihelionbar/config.json`.
To start over: `cp /usr/share/perihelion/perihelionbar/config.json ~/.config/perihelionbar/`.

**Apply changes:** save the file, then press **Super+Shift+D** (restarts the bar),
or reload it live with `pkill -USR1 -x perihelionbar`. If the bar suddenly looks
like perihelionbar's stock grey bar, the file has a mistake (a missing comma or
quote, or a color that isn't `#RRGGBB`) and perihelionbar fell back to its built-in
defaults: run `perihelionbar` in a terminal to see which line it complains about.

Edit it with `nano ~/.config/perihelionbar/config.json` (Ctrl+O saves, Ctrl+X quits).

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
| right | `power`, `battery`, `volume`, `notifications` (bell and notification panel), `control_center` (sliders and quick switches), `network`, `tray`, `layout` (Mango layout picker), `cava`, `cpu`, `cpu_temp`, `ram`, `disk`, `weather`, `custom_script`, `drawer_toggle` |

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

Colors follow the wallpaper (see [Colors from the wallpaper](#colors-from-the-wallpaper)).
With that switched off, colors are `"#RRGGBB"` in `config.json`. Perihelion's
own are Catppuccin Macchiato (<https://catppuccin.com/palette/>):

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
| `bar_height` | pixels | `32` |
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

cava is a mirrored sound wave, on either side of the bar or both. Its
gradient runs `bezel_color` at the middle, `cava_color`, then `matrix_color`
at the peaks: the three accents picked from the wallpaper (blue, pink and
yellow by default). The terminal `cava` uses its own colors, in
`~/.config/cava/config`.

| Key | Values | Perihelion |
|---|---|---|
| `cava_color` | color | `#F5BDE6` (pink) |
| `cava_style` | `"bars"`, `"wave"`, `"curve"` | `"bars"` |
| `bg_mode` | `"none"`, `"cava"` (equalizer across the whole bar background), `"matrix"`, `"lava"` | `"none"` |
| `cava_bg_strength` | 0–100, how strongly `bg_mode: "cava"` tints the bar | `35` |

Perihelion Settings lists the Audio Visualizer in both the Left and Right groups,
so each side has its own switch. Both waves keep the same distance from the
module beside them (workspaces on the left, the clock on the right).

## Notifications

mako shows the pop-ups. The bell in the bar (`notifications`, on by default;
`{ "kind": "notifications", "enabled": false }` hides it) opens a panel with
mako's recent notifications, newest first: app, title and the first line of
the text (mako's history has no times). Below the list:

- **Do not disturb**: no pop-ups while it's on (mako's `do-not-disturb` mode);
  the bell is crossed out. The choice is kept in
  `~/.local/state/perihelionbar/notifications` and comes back after a restart.
- **Clear all**: dismisses the pop-ups and empties the panel.

A dimmed bell means mako isn't running; the panel then says so.

## Control Center

The sliders icon (`control_center`, on by default;
`{ "kind": "control_center", "enabled": false }` hides it) opens a panel with:

- **Volume** and **Brightness** sliders (click the speaker to mute). The
  Brightness slider is dimmed on machines without a backlight.
- **Wi-Fi** on/off and the network you're on ("No Wi-Fi" without Wi-Fi hardware).
- **Bluetooth** on/off ("No adapter" without one).
- **Power**: click for the next power profile (Saver, Balanced, Performance).
- **Keep awake**: no idle lock while it's on. The bar holds an idle inhibitor,
  so it ends when the bar quits or you log out; it doesn't block the lock on
  suspend.
- **Do not disturb**: the same switch as in the notifications panel.

A dimmed switch does nothing: the hardware or the service behind it isn't there.

## Brightness OSD

The brightness keys (`brightnessctl set +5%` / `5%-` in Mango's keybinds) make the
bar show the same panel as the volume OSD: a sun icon, the level bar and the
percentage, for about 2 seconds. The bar notices the change in the backlight
itself (`/sys/class/backlight/…/actual_brightness`), so it also shows for
brightness changed any other way. Machines without a backlight (desktops,
virtual machines) never see it. Turn it off in `config.json`:

```json
"bar": { "enabled": true, "brightness_osd": false }
```

## The dock

The pinned apps live in their own dock at the bottom center, not in the bar.
It is a second copy of the bar started in dock mode (`PERIHELIONBAR_DOCK=1 perihelionbar`,
by `perihelion-bar-start` at login; Super+Shift+D restarts both). It
shows the `launchers` from `~/.config/perihelionbar/config.json`, the same list
Perihelion Settings edits; the first one runs `appdrawer` and wears the distro's
logo. Windows stop above the dock.

For the visualizer filling the whole bar behind the modules, try
`"bg_mode": "cava"` with `"cava_style": "curve"` and `"cava_bg_strength": 45`.

## Desktop widgets (perihelionbar-shell)

Eleven widgets can sit on the wallpaper: clock, weather, media (now
playing), system, calendar, notes, desktop icons, fastfetch (system info), processes (the busiest programs), network (download and
upload speed) and user (your name and uptime), on see-through cards.
On a fresh install the clock card shows and every other card is off
(`/usr/share/perihelion/perihelionbar/widgets-disabled` lists them) until
you turn it on in Perihelion Settings. Keeping one card on keeps
perihelion-shell running, and the Alt+W overview with it.

- **Add or remove:** open **Perihelion Settings** from the app launcher (Super+D)
  or the app drawer (Super+A). Under *Appearance → Desktop Widgets*, each
  widget has a switch, and the desktop updates right away.
- **Change how they look:** *Appearance → Desktop Card Options* sets the
  clock face (digital, flip, stacked or classic; 24-hour, seconds, date),
  the System card's style (columns, bars or ring gauges), temperature and weather
  units, what clicking the weather does, how many programs the Processes
  card lists, the Network graph and how often it reads, the User card's
  heading, uptime wording and name line, how many reminders the Calendar lists, and
  note tabs and checklists.
- **Remove one quickly:** hold **Alt** and right-click it. Turn it back on in
  Perihelion Settings; it comes back where it was.
- **Move:** hold **Ctrl** and drag a card.
- **Resize:** drag the grip in a card's bottom-right corner.
- The last widget can't be removed with Alt + right-click: with none left,
  perihelionbar-shell stops, and the Alt+W overview with it.

**More or less see-through:** `"card_bg_opacity"` in
`~/.config/perihelionbar/shell.json`, from 0 (clear) to 100 (solid). Perihelion
uses 25; perihelionbar's own default is 55. Restart the widgets after changing it
(command below). Super+G doesn't affect the widgets: it changes app windows.

**Holidays on the calendar:** `"holiday_country"` (default `"US"`) and
`"holiday_region"` (for example `"US-TX"` for Texas's own holidays) in the
same file.

What some of them need:

- **Weather** comes from Open-Meteo (free, no key, NOAA's models in the US),
  read by the bar and the widget themselves; they share one answer, cached
  in `~/.cache/perihelionbar/weather.cache`, refreshed every 15 minutes. Set
  your place on the first line of `~/.config/perihelionbar/weather-location`:
  `City, ST` (US), `City, FR` (other countries) or `latitude,longitude`, for
  example `echo "DeSoto, TX" > ~/.config/perihelionbar/weather-location`
  (`"weather_city"` in `shell.json` does the same). Without it, the place is
  guessed from your internet address (a VPN can put you elsewhere).
  Temperatures are in °F in the US and °C elsewhere unless you pick one.
  The card shows a 7-day forecast; clicking it opens the full forecast
  (weather.gov in the US, Windy elsewhere). After sunset a clear sky shows
  a moon. `perihelion-weather` still prints the current weather in a
  terminal, but the widget no longer uses it.
- **Desktop icons** shows the `.desktop` files in `~/Desktop`. In Steam,
  *Manage → Add desktop shortcut* puts a game there.
- **Notes:** click and type; Esc or a click elsewhere saves. Up to nine
  notes, one tab each: **+** adds one, **×** deletes the open one (click it
  twice; the text is kept in `notes/.last-deleted.txt`). Lines starting
  `- [ ] ` show as checkboxes you can tick, `- ` as bullets, `# ` as
  headings. Each note is a plain file, `~/.config/perihelionbar/notes/note1.txt`
  to `note9.txt`; edits made elsewhere show up by themselves.
- **System:** seven columns by default: CPU, CPU temperature, memory, GPU
  temperature, GPU busy, download and upload, each a value over a thin bar
  and an icon. A reading the computer doesn't have (no GPU sensor in a
  virtual machine) is dimmed with "n/a". `"system_style"` can also be
  `"bars"` or `"rings"`. With two GPUs, click it to switch.
- **Fastfetch** shows the same logo and sections as fastfetch in a terminal
  (`/usr/share/perihelion/fastfetch/config.jsonc`, or your own
  `~/.config/fastfetch/config.jsonc`). Shell is your login shell, Terminal
  the terminal Super+Return opens (kitty) with the font from its config, and
  Wmtheme the GTK theme. Rows with nothing to show are left out.
- **Processes:** the busiest programs by CPU or memory; click to switch.
  It only lists them.
- **Calendar reminders:** `~/.config/perihelionbar/reminders.txt`, one per line as
  `2026-11-25 18:00 Dinner` (or `2026-11-25 18:00 2 Dinner` to be notified
  2 days early). Click a day to add or remove one. `"calendar_reminders"`
  (0 to 6, default 0 = off) lists today's and the next reminders under the
  month, under a *Reminders* header; click a row to open its day. The
  calendar marks today with a soft disc, holidays in the holiday colour and
  reminder days with a short bar, and names the next holiday under the month.
- **Network:** download and upload speed over wired, Wi-Fi and mobile
  connections (VPNs, bridges and containers aren't counted twice), with a
  graph of the last 60 readings. `"network_graph"` (default `true`) shows the
  graph; `"network_interval_seconds"` (1 to 10, default 2) sets how often it
  reads `/proc/net/dev`.
- **User:** the distro logo (Fedora's) on a rounded tile, `user@host` as
  the heading and the uptime, redrawn once a minute. `"user_host"` (default
  `true`) puts the host in the heading; `"user_uptime_short"` (default
  `false`) always uses `2h 39m` instead of `2 hours, 39 mins`;
  `"user_show_name"` (default `false`) adds your full name.

By hand: `~/.config/perihelionbar/widgets-disabled` lists hidden widgets (ids
`clock weather media system calendar note1 icons fastfetch processes
network user`,
one per line), and `~/.config/perihelionbar/shell.json` holds positions in
pixels and the card options (its keys are listed in Perihelion Shell's
README). After editing: `pkill -f '^(/usr/bin/)?perihelion-shell( |$)'; setsid -f perihelion-shell`
(the process name is cut to 15 characters, so `pkill -x` can't match it).

Perihelion Settings's Bar pages also change the bar's colors, modules and
launcher buttons. Perihelion hides its Mango and System pages, which would
edit files Perihelion doesn't use.

## Colors from the wallpaper

```sh
perihelion-wallpaper ~/Pictures/your-image.png   # or Super+Shift+W
```

The wallpaper is remembered across logins, and every change recolors the
desktop to match it. `perihelion-theme` has two styles:

- **Catppuccin** (default): a flavor from how light the picture is (Latte for
  light ones; Frappé, Macchiato or Mocha for darker ones) and the three
  Catppuccin accents closest to its strongest colors. Every color is a real
  Catppuccin color; the wallpaper only chooses which.
- **Material You**: matugen, perihelionbar's own engine, makes Material Design
  colors from the wallpaper (tonal spot, vibrant, expressive, ...).

It writes:

| What | File |
|---|---|
| bar, visualizer wave, desktop widgets | `~/.config/perihelionbar/matugen.json` |
| app drawer (Super+A) | `~/.config/perihelionbar/matugen.json` (popup colors, read live by the Quickshell drawer) |
| launcher and power menu (fuzzel) | `[colors]` in `~/.config/fuzzel/fuzzel.ini` |
| Strata | `~/.config/strata/themes/tokyo-night.toml` |
| window borders (Mango) | `~/.config/mango/colors.conf` |
| fastfetch: the Fedora logo, section headers and values | `~/.config/fastfetch/config.jsonc` |
| kitty: background, text, 16 colors | `~/.config/kitty/perihelion-colors.conf` |
| terminal cava's gradient | `~/.config/cava/config` |
| btop | `~/.config/btop/themes/perihelion.theme` |
| cmatrix (nearest terminal color) | `~/.config/perihelion/cmatrix-color` |

In Perihelion Settings → Appearance → Theming:

- **Match the wallpaper** turns all of it on or off (off: the bar uses the
  colors set below it, and nothing else is touched).
- **Style**: a palette, or Material You (matugen).
- **Palette**: Catppuccin (auto, Latte, Frappé, Macchiato, Mocha), Gruvbox
  (auto, dark, light), Rosé Pine (auto, main, Moon, Dawn), Nord, Tokyo Night.
- **Wallpaper tint**: the backgrounds (bar, widgets, terminal, popups, login
  screen) become a dark shade of the wallpaper's main color, keeping the
  palette's lightness. Off: the palette's own backgrounds.
- **Accent colors**: from the wallpaper, or the palette's own.
- **Matugen color scheme** and **Theme mode** (Material You): tonal spot,
  vibrant, ...; dark, light or auto.

To keep your own drawer CSS, fuzzel colors, Strata theme, fastfetch or cava colors, delete the
`perihelion-theme` line in that file: it is never rewritten after that.
`perihelion-theme --dry-run` prints what it would pick, without writing.

## Troubleshooting

### cava in the bar stays flat (a dotted line) while music plays

The bar runs its own cava (settings in `~/.config/perihelionbar/cava.conf`,
PipeWire input following the default output). A dotted line means that
cava runs but hears silence. Play something, then:

1. `pkill -x cava`. perihelionbar starts a fresh one within 5 seconds. If the bar
   moves now, the first cava started before the audio system was ready.
   Perihelion starts the bar through `perihelion-bar-start`, which waits
   for the default audio output, to avoid exactly this.
2. Still flat: `cava -p ~/.config/perihelionbar/cava.conf` prints the bar's
   numbers (rows separated by `;`). "cava was built without 'pipewire' input
   support" means the file asks for PipeWire, which Fedora's cava doesn't
   have: set `method = pulse` in its `[input]` section (Perihelion's own
   copy already does), then `pkill -x cava`.

The full-bar visualizer behind the modules is `"bg_mode": "cava"` with
`"cava_style": "curve"` (or `"wave"`, `"bars"`) and `"cava_bg_strength": 45`.


- Bar back to stock grey after an edit: `perihelionbar` in a terminal shows the config error.
- Power button: opens `perihelion-power-menu` (also Super+Shift+Q).
- `perihelion-doctor` reports whether perihelionbar is running and which build it is.
