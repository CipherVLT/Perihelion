# Perihelion

A minimal Fedora for gamers and creators, in three tiling flavors:

| Flavor | Compositor | Shell | Notes |
|---|---|---|---|
| **Hyprland** | Hyprland 0.56+ (COPR `nett00n/hyprland`) | Event Horizon | Lua config from horizon-forge / Veyl OS |
| **Niri** | niri (Fedora) | Event Horizon | niri's default config, Perihelion apps swapped in |
| **Mango** | mangowm (Terra) | none | Upstream config; only the terminal and launcher binds changed |

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
- **Gaming:** Steam and gamescope (plus the 32-bit Mesa/Vulkan drivers Steam needs)
- **Repos:** Fedora and Terra. No RPM Fusion, no Flathub (add it yourself if you want Flatpaks)
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

## Download a test ISO

GitHub builds all three ISOs automatically on every push to `main` that
changes the recipe (and on demand: **Actions → Build ISOs → Run workflow**).
They are attached to the **testing** pre-release under **Releases**, each with
a `.sha256` file. Download one, boot it in a VM, install.

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
`scripts/fedora-netinst.ref` (currently Fedora 45 Beta 1.3; swap in the final
release's line when it ships). `--input FILE` uses an ISO you already have,
as long as it matches a pinned hash.

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
