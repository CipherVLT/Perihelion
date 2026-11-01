# Perihelion

A minimal Fedora for gamers and creators, in three tiling flavors:

| Flavor | Compositor | Shell | Notes |
|---|---|---|---|
| **Hyprland** | Hyprland 0.56+ (COPR `nett00n/hyprland`) | Event Horizon | Lua config from horizon-forge / Veyl OS |
| **Niri** | niri (Fedora) | Event Horizon | niri's default config, Perihelion apps swapped in |
| **Mango** | mangowm (Terra) | none | Upstream config; only the terminal and launcher binds changed |

Every flavor starts from Fedora's `@core` and adds only what a desktop needs
to work: network, Bluetooth, firewall, PipeWire audio, Mesa/Vulkan, a login
screen, and a short list of apps. No office suite, no GNOME or KDE app
collection.

**Status: pre-alpha, targeting Fedora 45.** Nothing here has been installed
on real hardware yet. Mango is the first flavor to test.

## What every flavor includes

- **Login:** SDDM on a Wayland greeter, Pixie theme, Perihelion wallpaper
- **Terminal:** kitty. **Browser:** Firefox. **Launcher:** fuzzel
- **Files:** [Strata](https://github.com/lgse/strata), wired in as the file manager everywhere:
  folders opened from any app, "Show in folder" / "Open containing folder" in Firefox and
  Steam (`org.freedesktop.FileManager1`), Open/Save dialogs (the XDG FileChooser portal),
  and the Trash (`trash:///`, via gvfs)
- **Gaming:** Steam, gamescope, MangoHud, GameMode, ProtonPlus, Wine (Kron4ek, NTSync), winetricks
- **Repos:** Fedora, Terra, Flathub. No RPM Fusion
- Fedora's defaults kept: SELinux enforcing, firewalld on

NVIDIA ISOs are planned for later and are not built yet.

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

## Build an ISO

On Fedora:

```sh
sudo dnf install xorriso rsync isomd5sum pykickstart

# 1. Check every package exists (Fedora + Terra + COPR)
podman run --rm -v "$PWD":/src:Z -w /src registry.fedoraproject.org/fedora:45 \
    scripts/check-packages.sh all

# 2. Build from the Fedora 45 Everything netinstall ISO
scripts/build-iso.sh --flavor mango \
    --input ~/Downloads/Fedora-Everything-netinst-x86_64-45.iso \
    --output out/perihelion-mango.iso
```

Boot the ISO, pick a disk and create your user in the installer, then
install. Packages download during installation, so the machine needs a
network connection. The install log ends up in `/root/perihelion-post.log`.

To read the final kickstart without building: `scripts/render-ks.sh mango`.

## Credits

Built from pieces of [horizon-forge](https://github.com/CipherVLT/horizon-forge)
and [Veyl OS](https://github.com/CipherVLT/veyl-os). The ISO build approach
is adapted from Chris Titus Tech's
[dwm-titus](https://github.com/ChrisTitusTech/dwm-titus). See [NOTICE](NOTICE)
for every upstream and its license.
