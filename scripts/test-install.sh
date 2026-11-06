#!/usr/bin/env bash
# Rehearse a flavor's installation inside a Fedora container, so mistakes in
# the %post scripts fail here instead of in the installer.
#
# Installs the flavor's %packages exactly as the kickstart lists them (no
# weak dependencies, same repositories), creates a regular user the way
# Anaconda does, then runs build/common-post.sh and build/flavor-<f>.sh.
# What a container can't do (boot, start the desktop) is not covered.
#
# Run as root in a throwaway fedora:45 container, never on a real system:
#   podman run --rm -v "$PWD":/src:Z -w /src registry.fedoraproject.org/fedora:45 \
#       scripts/test-install.sh mango
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
flavor=${1:-}
case "${flavor}" in
    hyprland | niri | mango) ;;
    *) echo "usage: $0 <hyprland|niri|mango>" >&2; exit 1 ;;
esac
[[ -f /run/.containerenv || -f /.dockerenv || "${PERIHELION_TEST_ANYWAY:-}" == 1 ]] || {
    echo "refusing to run outside a container: this installs packages and changes system files" >&2
    exit 1
}

releasever=$(rpm -E %fedora)
ks=$(mktemp)
"${repo_dir}/scripts/render-ks.sh" "${flavor}" "${ks}" >/dev/null
mapfile -t packages < <(sed -n '/^%packages/,/^%end$/p' "${ks}" | grep -v -e '^%' -e '^#' -e '^$')

repos=(
    --repofrompath "terra-install,https://repos.fyralabs.com/terra${releasever}"
    --setopt=terra-install.gpgcheck=0
)
if grep -q 'copr-nett00n-hyprland-install' "${ks}"; then
    repos+=(
        --repofrompath "copr-hyprland-install,https://download.copr.fedorainfracloud.org/results/nett00n/hyprland/fedora-${releasever}-x86_64/"
        --setopt=copr-hyprland-install.gpgcheck=0
    )
fi

# Containers have no SELinux, so label mistakes can't show up below. Guard
# the one known way to cause them: copying files onto the system with
# `cp -a`, which carries the source's SELinux label along.
if grep -rnE '\bcp +-[a-zA-Z]*a' "${repo_dir}/build" "${repo_dir}/kickstart" | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' | grep -v '/mnt/sysimage/var/tmp/perihelion'; then
    echo "install scripts must not use cp -a onto the system (copies SELinux labels); use cp -R --preserve=mode,timestamps --no-preserve=ownership,context,xattr" >&2
    exit 1
fi

echo "::group::Install ${#packages[@]} packages (no weak dependencies)"
# tsflags= : container images skip documentation; Anaconda installs it.
dnf5 install -y --setopt=install_weak_deps=False --setopt=tsflags= "${repos[@]}" "${packages[@]}"
echo "::endgroup::"

# Anaconda creates the user before %post runs; do the same.
useradd -m -u 1000 -G wheel tester

echo "::group::%post: common + ${flavor}"
rm -rf /var/tmp/perihelion
cp -a "${repo_dir}" /var/tmp/perihelion
rm -rf /var/tmp/perihelion/.git /var/tmp/perihelion/out
printf 'PERIHELION_COMMIT=%s\n' "${PERIHELION_COMMIT:-test}" > /var/tmp/perihelion/BUILD
# Also exercise the local-build path with wallpapers (scripts/fetch-wallpapers.sh):
# two stand-in 1x1 PNGs, the second marked as the default.
if [[ "${PERIHELION_TEST_WALLPAPERS:-1}" == 1 ]]; then
    for name in test-a.png test-b.png; do
        printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\rIDATx\x9cc\xf8\x0f\x00\x00\x01\x01\x00\x05\x18\xd8N\x00\x00\x00\x00IEND\xaeB`\x82' \
            > "/var/tmp/perihelion/branding/wallpapers/${name}"
    done
    echo test-b.png > /var/tmp/perihelion/branding/wallpapers/DEFAULT
fi
export PERIHELION_SRC=/var/tmp/perihelion PERIHELION_FLAVOR="${flavor}"
bash "${PERIHELION_SRC}/build/common-post.sh"
bash "${PERIHELION_SRC}/build/flavor-${flavor}.sh"
bash -c "source ${PERIHELION_SRC}/build/lib.sh && refresh_icon_caches"
bash -c 'source "${PERIHELION_SRC}/build/lib.sh" && relabel_system'
echo "::endgroup::"

echo "::group::Weak dependencies left out (review: anything essential belongs in packages/)"
# Every "Recommends" of an installed package that nothing installed provides.
rpm -qa --qf '[%{=NAME}\t%{RECOMMENDNAME}\n]' | sort -u | while IFS=$'\t' read -r pkg cap; do
    [[ -n "${cap}" && "${cap}" != "(none)" ]] || continue
    case "${cap}" in \(*) continue ;; esac   # rich dependencies: skip
    rpm -q --whatprovides "${cap}" >/dev/null 2>&1 || printf '  %-40s recommended by %s\n' "${cap}" "${pkg}"
done | sort
echo "::endgroup::"

echo "::group::Checks"
fail=0
check() { if "$@"; then echo "  ok    $*"; else echo "  FAIL  $*"; fail=1; fi; }
check test -x /usr/libexec/strata/strata
check grep -q 'inode/directory=io.github.lgse.Strata.desktop' /etc/xdg/mimeapps.list
check grep -qx 'install_weak_deps=False' /etc/dnf/dnf.conf
check grep -q "PERIHELION_FLAVOR=${flavor}" /usr/share/perihelion/release
check test -L /etc/systemd/system/display-manager.service
# Every PAM module the PAM configuration requires must exist (a missing
# pam_systemd.so left the login screen without a seat). Lines starting with
# "-" are optional by design and may name absent modules.
while read -r module; do
    check test -f "/usr/lib64/security/${module}"
done < <(grep -hE '^[[:space:]]*[a-z]' /etc/pam.d/* | grep -oE 'pam_[a-z0-9_]+\.so' | sort -u)
has_en_utf8_locale() { locale -a 2>/dev/null | grep -qi '^en_US\.utf8$'; }
check has_en_utf8_locale
# 64-bit and 32-bit graphics drivers (Steam needs both)
check rpm -q mesa-dri-drivers.x86_64 mesa-vulkan-drivers.x86_64 vulkan-loader.x86_64
check rpm -q mesa-dri-drivers.i686 mesa-vulkan-drivers.i686 vulkan-loader.i686
check rpm -q dconf cracklib-dicts nano
check rpm -q fastfetch lm_sensors nethogs
# Look: Numix-Circle icons, Bibata cursor 24 px, DejaVu Sans Mono 11 pt
check test -f /usr/share/icons/Numix-Circle/index.theme
check test -f /usr/share/icons/Numix/index.theme
check rpm -q qt6ct dejavu-lgc-sans-fonts imv cava
check test -f /usr/share/qt6ct/colors/Catppuccin-Macchiato.conf
check grep -qx 'color_scheme_path=/usr/share/qt6ct/colors/Catppuccin-Macchiato.conf' /home/tester/.config/qt6ct/qt6ct.conf
check grep -qx 'image/png=imv.desktop;' /etc/xdg/mimeapps.list
check grep -qx "gradient_color_2 = '#f5bde6'" /home/tester/.config/cava/config
term_cava_ok() { ! timeout 5 cava -p /home/tester/.config/cava/config 2>&1 </dev/null | head -c 2000 | grep -qiE 'loading config|built without'; }
check term_cava_ok
check grep -qx 'icon_theme=Numix-Circle' /home/tester/.config/qt6ct/qt6ct.conf
check rpm -q bibata-cursor-theme dejavu-sans-mono-fonts
check test -d /usr/share/icons/Bibata-Modern-Classic/cursors
check grep -qx 'font_family DejaVu Sans Mono' /etc/xdg/kitty/kitty.conf
check grep -qx 'font_size 11.0' /etc/xdg/kitty/kitty.conf
dejavu_ok() { fc-match 'DejaVu Sans Mono' | grep -q '^DejaVuSansMono\.ttf'; }
check dejavu_ok
check grep -qx 'gtk-cursor-theme-name=Bibata-Modern-Classic' /home/tester/.config/gtk-3.0/settings.ini
check grep -qx 'gtk-icon-theme-name=Numix-Circle' /home/tester/.config/gtk-4.0/settings.ini
check grep -qx 'CursorTheme=Bibata-Modern-Classic' /etc/sddm.conf.d/10-perihelion.conf
dconf_ok() { [[ "$(dconf read /org/gnome/desktop/interface/cursor-theme 2>/dev/null)" == "'Bibata-Modern-Classic'" ]]; }
check dconf_ok
# kitty: Catppuccin Macchiato in every flavor
check grep -qx 'background              #24273A' /etc/xdg/kitty/kitty.conf
check grep -qx 'color4  #8AADF4' /etc/xdg/kitty/kitty.conf
# Shared helpers (every flavor)
# perihelion-wallpapers' imports work (no display needed for this)
wallpapers_imports_ok() { python3 -c 'import gi; gi.require_version("Gtk", "4.0"); gi.require_version("GdkPixbuf", "2.0"); from gi.repository import Gtk, GdkPixbuf'; }
check wallpapers_imports_ok
wallpapers_parses() { python3 -c 'import ast, sys; ast.parse(open(sys.argv[1]).read())' /usr/bin/perihelion-wallpapers; }
check wallpapers_parses
for helper in perihelion-power-menu perihelion-wallpaper-picker perihelion-drawer perihelion-keys perihelion-glass perihelion-wallpapers; do
    check test -x "/usr/bin/${helper}"
done
check rpm -q playerctl gtk-layer-shell
check test -x /usr/bin/nwg-drawer
check test -d /usr/share/nwg-drawer/desktop-directories
drawer_links_ok() { ! ldd /usr/bin/nwg-drawer | grep -q 'not found'; }
check drawer_links_ok
check test -f /home/tester/.config/nwg-drawer/drawer.css
drawer_flags_ok() { local h; h=$(nwg-drawer -h 2>&1 || true); for f in -term -fm -ovl -c -is -spacing; do grep -q -- "^ *${f}\b" <<<"${h}" || { echo "nwg-drawer has no ${f}"; return 1; }; done; }
check drawer_flags_ok
check rpm -q flatpak
flathub_configured() { flatpak remotes --system --columns=name | grep -qx flathub; }
check flathub_configured
check test -f /var/lib/perihelion/flathub-added
check test -L /etc/systemd/system/multi-user.target.wants/perihelion-flathub.service
check test -x /usr/libexec/perihelion-auto-timezone
# GTK sees Perihelion-installed icons only through the rebuilt hicolor cache
check grep -aq 'io.github.lgse.Strata' /usr/share/icons/hicolor/icon-theme.cache
check rpm -q chrony
check test -L /etc/systemd/system/multi-user.target.wants/chronyd.service
check grep -qx UTC /etc/adjtime
check test -L /etc/systemd/system/multi-user.target.wants/perihelion-auto-timezone.service
check bash -n /usr/bin/perihelion-doctor
check test -f /home/tester/.config/fastfetch/config.jsonc
fastfetch_config_ok() { fastfetch --config /home/tester/.config/fastfetch/config.jsonc --pipe >/dev/null 2>/tmp/ff.err && ! grep -qi error /tmp/ff.err; }
check fastfetch_config_ok
# CPU/GPU lines must not end in an empty "@  GHz" (field numbers that
# don't exist in this fastfetch version)
cpu_gpu_ok() { ! fastfetch --config /home/tester/.config/fastfetch/config.jsonc --pipe 2>/dev/null | grep -q '@  GHz'; }
check cpu_gpu_ok
check perihelion-os-age
check bash -n /etc/profile.d/perihelion-fastfetch.sh
# Everything the login screen needs (Weston greeter + Qt Wayland + theme)
check rpm -q sddm sddm-wayland-generic weston qt6-qtwayland qt6-qtdeclarative
check test -x /usr/bin/weston
check grep -q '^Current=pixie' /etc/sddm.conf.d/10-perihelion.conf
check test -f /usr/share/sddm/themes/pixie/Main.qml
check test -x /usr/bin/perihelion-doctor
if [[ "${PERIHELION_TEST_WALLPAPERS:-1}" == 1 ]]; then
    check test "$(readlink /usr/share/backgrounds/perihelion/default.png)" = test-b.png
    check test -s /usr/share/sddm/themes/pixie/assets/background.png
fi
case "${flavor}" in
    mango)
        check test -f /home/tester/.config/mango/config.conf
        check test -x /usr/bin/simpbar
        check test -f /home/tester/.config/simpbar/config.json
        check test -f "$(sed -n 's/.*"font_path": "\([^"]*\)".*/\1/p' /home/tester/.config/simpbar/config.json)"
        check grep -q '/JetBrainsMonoNerdFont-Regular.ttf"' /home/tester/.config/simpbar/config.json
        check ldd /usr/bin/simpbar
        check test -x /usr/bin/perihelion-power-menu
        check test -x /usr/bin/appdrawer
        check test -x /usr/bin/simpbar-shell
        check ldd /usr/bin/simpbar-shell
        check test -f /home/tester/.config/simpbar/shell.json
        check test -f /home/tester/.config/simpbar/matugen.json
        # Minimal desktop: only weather and calendar on, see-through cards
        minimal_widgets_ok() { ! grep -qxE 'weather|calendar' /home/tester/.config/simpbar/widgets-disabled && [[ $(grep -c . /home/tester/.config/simpbar/widgets-disabled) -eq 6 ]]; }
        check minimal_widgets_ok
        check grep -q '"card_bg_opacity": 25' /home/tester/.config/simpbar/shell.json
        check test -x /usr/bin/simpbar-config
        check ldd /usr/bin/simpbar-config
        check test -f /usr/share/applications/simpbar-config.desktop
        check grep -aq 'simpbar-config' /usr/share/icons/hicolor/icon-theme.cache
        check rpm -q gtk4 libadwaita
        check grep -q 'ALT,w,spawn,simpbar-shell overview toggle' /home/tester/.config/mango/config.conf
        check grep -qx 'bind=SUPER,g,spawn,perihelion-glass' /home/tester/.config/mango/config.conf
        check grep -qx 'exec_once=perihelion-simpbar-start' /home/tester/.config/mango/config.conf
        check bash -n /usr/bin/perihelion-simpbar-start
        check bash -n /usr/bin/perihelion-weather
        # Live weather (Open-Meteo); reported, not fatal, so an outage can't block a build
        mkdir -p /tmp/wtest/.config/simpbar && echo "DeSoto, TX" > /tmp/wtest/.config/simpbar/weather-location
        if w=$(HOME=/tmp/wtest perihelion-weather 2>&1) && [[ $(tr -cd '|' <<<"${w}" | wc -c) -eq 6 ]]; then
            echo "  ok    perihelion-weather: ${w}"
        else
            echo "  WARN  perihelion-weather: ${w}"
        fi
        # Catppuccin theming from the wallpaper, run for real in a scratch home
        # seeded like the tester's (reads images through GdkPixbuf)
        check test -x /usr/bin/perihelion-theme
        check test -x /usr/bin/simpbar-matugen
        check grep -qx 'source_optional=~/.config/mango/colors.conf' /home/tester/.config/mango/config.conf
        rm -rf /tmp/ttest && mkdir -p /tmp/ttest && cp -a /home/tester/.config /tmp/ttest/
        theme_ok() {
            local img=/usr/share/icons/hicolor/scalable/apps/simpbar-config.svg
            [[ -f /usr/share/backgrounds/perihelion/default.png ]] && img=/usr/share/backgrounds/perihelion/default.png
            HOME=/tmp/ttest XDG_CONFIG_HOME=/tmp/ttest/.config XDG_CACHE_HOME=/tmp/ttest/.cache \
                perihelion-theme --force "${img}" &&
                grep -q '"matrix_color"' /tmp/ttest/.config/simpbar/matugen.json &&
                grep -q 'Written by perihelion-theme' /tmp/ttest/.config/nwg-drawer/drawer.css &&
                grep -q '^# perihelion-theme' /tmp/ttest/.config/fuzzel/fuzzel.ini &&
                grep -q '^focus_color=0x' /tmp/ttest/.config/mango/colors.conf
        }
        check theme_ok
        check grep -qx 'bind=SUPER+SHIFT,g,spawn,perihelion-blur' /home/tester/.config/mango/config.conf
        check grep -q 'app_id:^perihelion-float\$' /home/tester/.config/mango/config.conf
        check grep -qx 'method = pulse' /home/tester/.config/simpbar/cava.conf
        # The input the bar's cava.conf asks for must be one Fedora's cava has
        cava_pulse_ok() { ! timeout 5 cava -p /home/tester/.config/simpbar/cava.conf 2>&1 </dev/null | head -c 2000 | grep -q "built without 'pulse'"; }
        check cava_pulse_ok
        check grep -qx 'source_optional=~/.config/mango/glass.conf' /home/tester/.config/mango/config.conf
        check test -f /usr/share/doc/perihelion/simpbar.md
        check rpm -q cava
        check grep -q '"position": "bottom"' /home/tester/.config/simpbar/config.json
        check grep -q '"kind": "power"' /home/tester/.config/simpbar/config.json
        check test -f /home/tester/.config/fuzzel/fuzzel.ini
        check grep -q '"keyColor": "1;38;2;238;212;159"' /home/tester/.config/fastfetch/config.jsonc
        os_pink_ok() { [[ $(grep -c '"keyColor": "1;38;2;245;189;230"' /home/tester/.config/fastfetch/config.jsonc) -eq 4 ]]; }
        check os_pink_ok
        check grep -q '"1": "38;2;138;173;244", "2": "38;2;238;212;159"' /home/tester/.config/fastfetch/config.jsonc
        check grep -q '"title": "1;38;2;237;135;150", "output": "38;2;138;173;244"' /home/tester/.config/fastfetch/config.jsonc
        check mango -p -c /home/tester/.config/mango/config.conf
        check test "$(stat -c %U /home/tester/.config/mango/config.conf)" = tester
        check test -f /etc/xdg/xdg-desktop-portal/mango-portals.conf
        ;;
    hyprland)
        check test -x /usr/bin/horizon
        check test -f /usr/share/wayland-sessions/event-horizon.desktop
        check grep -q 'bind(key("A"), hl.dsp.exec_cmd("perihelion-drawer"), "App drawer")' /usr/share/event-horizon/skel/hypr/hyprland.lua
        check grep -q 'bind(key("G"), toggleGlass, ' /usr/share/event-horizon/skel/hypr/hyprland.lua
        check grep -q 'bind(key("O"), hl.dsp.exec_cmd("eh-ipc overview-toggle"), "Overview")' /usr/share/event-horizon/skel/hypr/hyprland.lua
        check test -x /usr/bin/horizon-wallpaper
        check test -x /usr/bin/horizon-clipstack-pick
        check test -f /etc/xdg/xdg-desktop-portal/hyprland-portals.conf
        ;;
    niri)
        check test -x /usr/bin/horizon
        check test -f /home/tester/.config/niri/config.kdl
        check niri validate -c /home/tester/.config/niri/config.kdl
        check grep -q 'Mod+A hotkey-overlay-title="App drawer" { spawn "perihelion-drawer"; }' /home/tester/.config/niri/config.kdl
        check grep -q 'Mod+Shift+W hotkey-overlay-title="Wallpaper picker"' /home/tester/.config/niri/config.kdl
        has_one_binds_block() { [[ $(grep -c '^binds {' /home/tester/.config/niri/config.kdl) -eq 1 ]]; }
        check has_one_binds_block
        check grep -q 'Mod+G hotkey-overlay-title="Glass mode' /home/tester/.config/niri/config.kdl
        check grep -q '^include optional=true "glass.kdl"$' /home/tester/.config/niri/config.kdl
        check grep -q 'xcursor-theme "Bibata-Modern-Classic"' /home/tester/.config/niri/config.kdl
        check test -f /etc/xdg/xdg-desktop-portal/niri-portals.conf
        ;;
esac
echo "::endgroup::"
(( fail == 0 )) || { echo "install rehearsal for ${flavor}: checks failed" >&2; exit 1; }
echo "install rehearsal for ${flavor}: OK"
