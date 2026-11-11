# Perihelion

A minimal Fedora for gamers and creators, in three tiling flavors:

| Flavor | Compositor | Shell | Notes |
|---|---|---|---|
| **Hyprland** | Hyprland 0.56+ (COPR `nett00n/hyprland`) | Event Horizon | Lua config from horizon-forge / Veyl OS |
| **Niri** | niri (Fedora) | Event Horizon | niri's default config, Perihelion apps swapped in |
| **Mango** | mangowm (Terra) | simpbar + swaybg | Veyl OS keybinds, gaps and look translated to Mango |

Every flavor starts from Fedora's `@core` and adds only what a desktop needs
to work: network, Bluetooth, firewall, PipeWire audio, Mesa/Vulkan, a login
screen, kitty, Firefox, Strata, Steam and gamescope. No office suite, no
GNOME or KDE app collection.

**Only listed packages.** The kickstart installs with `--exclude-weakdeps`,
so nothing Fedora merely "recommends" comes along, and the installed system
keeps `install_weak_deps=False` in `/etc/dnf/dnf.conf` so later installs stay
lean too. If something seems missing, it was a weak dependency: add it to a
list in `packages/` (or flip that dnf setting).

**Status: pre-alpha, targeting Fedora 45.** Nothing here has been installed
on real hardware yet. Mango is the first flavor to test.

## What every flavor includes

- **Login:** SDDM on a Wayland greeter, Pixie theme
- **Terminal:** kitty. **Browser:** Firefox. **Launcher:** fuzzel
- **Files:** [Strata](https://github.com/lgse/strata), wired in as the file manager everywhere:
  folders opened from any app, "Show in folder" / "Open containing folder" in Firefox and
  Steam (`org.freedesktop.FileManager1`), Open/Save dialogs (the XDG FileChooser portal),
  and the Trash (`trash:///`, via gvfs)
- **Gaming:** Steam and gamescope (plus the 32-bit Mesa/Vulkan drivers Steam needs),
  Wine 11.21 (Kron4ek's Staging WoW64 build, NTSYNC on) with winetricks, gamemode
  and MangoHud
- **Repos:** Fedora and Terra, plus Flatpak with Flathub already added (`flatpak install flathub <app>`). No RPM Fusion
- Fedora's defaults kept: SELinux enforcing, firewalld on

NVIDIA ISOs are planned for later and are not built yet.

## Time zone

If the installer leaves the system on UTC, Perihelion sets the time zone
from where the machine is (Fedora's geoip, the same service the installer
uses), during the install or at the next boot that's online. A time zone
you picked is never changed. By hand: `sudo timedatectl set-timezone
America/Chicago`, then log out and back in.

## Something wrong?

Run `perihelion-doctor --save` and share `~/perihelion-doctor.txt`.

## Keybinds

All three flavors share your Veyl OS keybind set: Super+Return terminal,
Super+D launcher, Super+A app drawer, Super+E files, Super+B browser,
Super+S Steam, Super+O overview, Super+Shift+W wallpaper, Super+Shift+Q
power menu, Super+H every keybind. Hyprland and Niri also have Super+V
clipboard history and Super+T settings (Event Horizon).

## Look

Every flavor: Numix-Circle icons, the Bibata Modern Classic cursor at 24 px,
and DejaVu Sans Mono 11 pt in kitty, with kitty in Catppuccin Macchiato.
Change the icons or cursor in `~/.config/gtk-3.0/settings.ini` and
`gtk-4.0/settings.ini` (plus `gsettings set org.gnome.desktop.interface ...`),
and the font in `~/.config/kitty/kitty.conf`.
Qt apps follow qt6ct (Catppuccin Macchiato, Numix-Circle, DejaVu): run
`qt6ct` to change them.

**Glass.** kitty is see-through by default (Ctrl+Shift+A then M / L for
more or less). On Mango, GTK apps (Files, Settings, dialogs, file pickers)
are frosted glass by default, Event Horizon style: perihelion-theme makes
only their backgrounds see-through, tinted with the wallpaper theme, so text
stays sharp, and Mango blurs the wallpaper behind them (4 soft passes, a
touch darker and more saturated, cached once per wallpaper). Menus and
popovers stay nearly solid, since Mango doesn't blur behind popups. Turn it
off with Super+G or Perihelion Settings > Window glass. A `gtk.css` of your
own is left alone; put `@import url("perihelion-glass.css");` at its top to
keep the glass. On Hyprland and Niri, Super+G makes windows see-through.
The Honkers Railway Launcher is always glass; add your own apps with a
window rule (examples in each compositor's config).

## Mango: first login

Pick **Mango** on the login screen. Super is the Windows key.

| Keys | Does |
|---|---|
| Super+Return | Terminal (kitty) |
| Super+D | App launcher (fuzzel) |
| Super+E / Super+B / Super+S | Files (Strata) / Firefox / Steam |
| Super+Q | Close window |
| Super+arrows | Move focus |
| Super+Shift+arrows | Resize (or drag the gap between windows, no key held) |
| Super+Shift+Ctrl+arrows | Swap windows |
| Super+1-9 / Super+Shift+1-9 | Go to / move window to workspace |
| Super+W / Super+F | Floating / fullscreen |
| Super+Shift+Return | Floating terminal, half-size in the bottom-right corner (for showcases) |
| Super+A | App drawer (grid of every app) |
| Super+Shift+W | Wallpaper picker: previews of `~/Pictures/Wallpapers`, search, Random, Bing (today's image), Open folder |
| Super+O / Alt+W | Overview (Mango's own / simpbar-shell's with live previews) |
| Super+Shift+Q | Power menu (also the power button on the bar) |
| Ctrl+drag / Alt+right-click | Move / remove a desktop widget (Mango; add them in Perihelion Settings) |
| Super+Shift+G | Blur strength (Mango): normal, strong, soft, off |
| Super+G | Glass mode (Mango: frosted GTK windows on/off; Hyprland: the focused window; Niri: every window) |
| Super+H | **Every keybind, searchable** |
| Super+Shift+E | Log out |

- Gaps 2 px inside / 4 px outside, 2 px Catppuccin Macchiato blue (`0x8aadf4ff`)
  border on the focused window, see-through blurred kitty.
- Your config: `~/.config/mango/config.conf` (Super+Shift+R reloads it).
  Bar: [Perihelion Shell](https://github.com/CipherVLT/perihelion-shell), our fork
  of [simpbar](https://github.com/jaytheoutpatient/simpbar) by jaytheoutpatient,
  `~/.config/simpbar/config.json` (Super+Shift+D restarts it). Colors follow the
  wallpaper, in Catppuccin. Guide:
  [docs/simpbar.md](docs/simpbar.md), also at `/usr/share/doc/perihelion/simpbar.md`.
  Launcher: `~/.config/fuzzel/fuzzel.ini`.
- Wallpaper: `perihelion-wallpaper ~/Pictures/some-image.png` (remembered).
- Something wrong? Run `perihelion-doctor` in a terminal: it checks the
  config, lists missing programs and shows this boot's errors.
  `perihelion-doctor --save` writes it to `~/perihelion-doctor.txt` to share.

## Layout

```
kickstart/base.ks          repos, services, installer settings (all flavors)
kickstart/flavors/*.ks     extra repos per flavor + which package lists it uses
kickstart/post.ks          the %post steps (copy repo in, run build/*.sh)
packages/*.txt             package lists, one name per line
build/                     scripts run inside the new system during install
system_files/<tree>/       files copied onto / (common, event-horizon, hyprland, niri, mango)
branding/wallpapers/       default wallpapers
scripts/                   render-ks.sh, build-iso.sh, check-packages.sh (run on your machine)
```

To add or remove a package, edit the list in `packages/` and rebuild.

## Download a test ISO

GitHub builds all three ISOs automatically on every push to `main` that
changes the recipe (and on demand: **Actions → Build ISOs → Run workflow**).
They are attached to the **testing** pre-release under **Releases**, each with
a `.sha256` file. Download one, boot it in a VM, install.

**Which build is this?** Every ISO file name ends in the commit it was built
from (`perihelion-mango-20261101-a5f31af.iso`), matching the commit shown on
the release and on GitHub. After installing, check it with:

```sh
cat /usr/share/perihelion/release   # PERIHELION_COMMIT=a5f31af
```

The recipe (config, keybinds, package lists) is fixed when the ISO is built.
The packages themselves (Mango, Firefox, Steam, ...) download during
installation, so they are always the newest versions in Fedora and Terra.

These builds have no wallpapers (plain login background). Pull requests run
the same checks and build, but publish nothing.

## Build an ISO yourself

Building is quick (it repacks Fedora's ISO; no compiling), and works on any
Linux with the tools below, or inside a `fedora:45` container. On Fedora:

```sh
sudo dnf install xorriso rsync isomd5sum pykickstart

# 1. Check every package exists (Fedora + Terra + COPR)
podman run --rm -v "$PWD":/src:Z -w /src registry.fedoraproject.org/fedora:45 \
    scripts/check-packages.sh all

# 2. Optional, personal builds only: the Kurzgesagt black-hole wallpapers
#    (free for personal use, so never committed; see NOTICE)
scripts/fetch-wallpapers.sh

# 3. Build: downloads the pinned Fedora 45 Everything netinstall ISO,
#    checks its SHA256, then builds
scripts/build-iso.sh --flavor mango --download --output out/perihelion-mango.iso
```

Like dwm-titus, the build only accepts a Fedora ISO whose SHA256 is pinned in
`scripts/fedora-netinst.ref` (currently the Fedora 45 final release, 45-1.4; the
build also checks Fedora's GPG-signed CHECKSUM file). `--input FILE` uses an ISO you already have,
as long as it matches a pinned hash.

Boot the ISO, pick a disk and create your user in the installer, then
install. Packages download during installation, so the machine needs a
network connection. The install log ends up in `/root/perihelion-post.log`.

To read the final kickstart without building: `scripts/render-ks.sh mango`.

## Credits

The Mango flavor's bar and desktop are [Perihelion Shell](https://github.com/CipherVLT/perihelion-shell),
Perihelion's fork (with his blessing) of [simpbar](https://github.com/jaytheoutpatient/simpbar)
by **jaytheoutpatient**, a native Zig/Wayland bar for Hyprland and MangoWM.
The Catppuccin presets come from **Mirrez**'s simpbar-catppuccin-matugen
package; the palette is [Catppuccin](https://catppuccin.com) (MIT).
The other palettes in Perihelion Settings (about 270, searchable) are
[Event Horizon](https://github.com/Event-Horizon-desktop-environment)'s colour
themes (GPL-3.0), imported as they are; credits for each upstream scheme are in
`/usr/share/perihelion/palettes/NOTICE.md`. Your own palette files go in
`~/.local/share/perihelion/palettes/`.
On Mango the Super+A app drawer is Perihelion Shell's Quickshell drawer
(from simpbar by **jaytheoutpatient**; right-click an app to pin it to the
dock). Hyprland and Niri use [nwg-drawer](https://github.com/nwg-piotr/nwg-drawer)
by **Piotr Miller** (MIT).

Built from pieces of [horizon-forge](https://github.com/CipherVLT/horizon-forge)
and [Veyl OS](https://github.com/CipherVLT/veyl-os). The ISO build approach
is adapted from Chris Titus Tech's
[dwm-titus](https://github.com/ChrisTitusTech/dwm-titus). See [NOTICE](NOTICE)
for every upstream and its license.
