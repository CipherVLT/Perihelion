#!/usr/bin/env bash
# Build and install Perihelion Shell, the bar and desktop of the Mango flavor.
#
# Perihelion Shell (https://github.com/CipherVLT/perihelion-shell): Perihelion
# Bar, a native Zig/Wayland bar for MangoWM and Hyprland (credits: NOTICE). Installed: Perihelion Bar
# (/usr/bin/perihelion-bar, also the dock), Perihelion Shell
# (/usr/bin/perihelion-shell: desktop widgets and window overview),
# Perihelion Settings (/usr/bin/perihelion-settings), and perihelion-theme (Catppuccin colors matched to the
# wallpaper). Not installed: perihelionbar's Welcome app, Quickshell app drawer and
# Arch installer. Perihelion's changes are commits in the fork.
#
# Built from the commit pinned in build/refs/perihelionbar.ref with Zig 0.16.0
# (the release tarball from ziglang.org, verified against the Zig Software
# Foundation's minisign key). Build-only packages are removed afterwards.
set -euo pipefail
# shellcheck source=build/lib.sh
source "${PERIHELION_SRC}/build/lib.sh"

PERIHELIONBAR_REPO=https://github.com/CipherVLT/perihelion-shell.git
PERIHELIONBAR_REF=$(tr -d '[:space:]' < "${PERIHELION_SRC}/build/refs/perihelionbar.ref")
ZIG_VERSION=0.16.0
ZIG_PUBKEY='RWSGOq2NVecA2UPNdBUZykf1CCb147pkmdtYxgb3Ti+JO/wCYvhbAb/U'
# Every x86-64 CPU since ~2009; perihelionbar's installer otherwise tunes for the
# build machine.
ZIG_CPU=x86_64_v2

log "perihelion-shell: building ${PERIHELIONBAR_REF:0:7}"
rpm -qa --qf '%{NAME}\n' | sort -u > /tmp/perihelionbar-before.txt

# The bar links wayland-client, freetype2 and gdk-pixbuf. `zig build` also
# compiles perihelionbar's GTK apps (perihelionbar-welcome, perihelionbar-config), so their
# headers are needed for the build even though only the bar is installed.
dnf5 install -y --setopt=install_weak_deps=False \
    git-core curl xz minisign pkgconf-pkg-config \
    wayland-devel wayland-protocols-devel freetype-devel gdk-pixbuf2-devel libxkbcommon-devel \
    gtk4-devel libadwaita-devel glib2-devel

work=$(mktemp -d)
zig_dir="${work}/zig"
mkdir -p "${zig_dir}"
zig_ok=0
for name in "zig-x86_64-linux-${ZIG_VERSION}" "zig-linux-x86_64-${ZIG_VERSION}"; do
    url="https://ziglang.org/download/${ZIG_VERSION}/${name}.tar.xz"
    if curl --fail --location --silent --show-error --retry 3 -o "${zig_dir}/zig.tar.xz" "${url}" &&
        curl --fail --location --silent --show-error --retry 3 -o "${zig_dir}/zig.tar.xz.minisig" "${url}.minisig"; then
        zig_ok=1
        break
    fi
done
(( zig_ok )) || die "could not download Zig ${ZIG_VERSION}"
minisign -V -P "${ZIG_PUBKEY}" -m "${zig_dir}/zig.tar.xz" -x "${zig_dir}/zig.tar.xz.minisig"
tar -xJf "${zig_dir}/zig.tar.xz" -C "${zig_dir}" --strip-components=1
export ZIG_GLOBAL_CACHE_DIR="${work}/zig-global-cache" ZIG_LOCAL_CACHE_DIR="${work}/zig-local-cache"

src="${work}/perihelionbar"
git -C "${work}" init -q perihelionbar
git -C "${src}" remote add origin "${PERIHELIONBAR_REPO}"
retry git -C "${src}" fetch -q --depth 1 origin "${PERIHELIONBAR_REF}"
git -C "${src}" checkout -q --detach FETCH_HEAD
# The bar lives in the perihelionbar/ subfolder; its Wayland dependency is vendored
# in perihelionbar/zig-pkg, so the build needs no further downloads.
(
    cd "${src}/perihelionbar"
    "${zig_dir}/zig" build -Doptimize=ReleaseFast "-Dcpu=${ZIG_CPU}"
)
install -Dm755 "${src}/perihelionbar/zig-out/bin/perihelion-bar" /usr/bin/perihelion-bar
# Perihelion Settings (GTK): the bar's look, modules and colors, and a
# switch for each desktop widget (only its Bar pages are shown).
install -Dm755 "${src}/perihelionbar/zig-out/bin/perihelion-settings" /usr/bin/perihelion-settings
install -Dm644 "${src}/perihelion-settings.desktop" /usr/share/applications/perihelion-settings.desktop
# Its icon, the solar gear: PNGs at every size (fuzzel, the dock, the app
# drawer and GTK all read them), under the launcher's icon name and the
# window's app ID (window lists, task bars, GTK 4's window icon). The old
# scalable cog is removed so no theme lookup can prefer it.
rm -f /usr/share/icons/hicolor/scalable/apps/perihelion-settings.svg \
    /usr/share/icons/hicolor/scalable/apps/io.github.ciphervlt.perihelion.Settings.svg
for png in "${src}"/assets/icons/perihelion-settings/*.png; do
    size=$(basename "${png}" .png)
    for name in perihelion-settings io.github.ciphervlt.perihelion.Settings; do
        install -Dm644 "${png}" "/usr/share/icons/hicolor/${size}x${size}/apps/${name}.png"
    done
done

# Perihelion Shell (desktop widgets, window overview); shares the bar's font code.
(
    cd "${src}/perihelionbar-shell"
    "${zig_dir}/zig" build -Doptimize=ReleaseFast "-Dcpu=${ZIG_CPU}"
)
install -Dm755 "${src}/perihelionbar-shell/zig-out/bin/perihelion-shell" /usr/bin/perihelion-shell
# Catppuccin theming: runs on every wallpaper change (perihelion-wallpaper)
# and from Perihelion Settings. perihelionbar-matugen is the name the bar itself calls.
install -Dm755 "${src}/perihelion-theme" /usr/bin/perihelion-theme
# Its palettes (Event Horizon's colour themes and more, one JSON file each,
# with NOTICE.md crediting them); perihelion-theme looks in
# /usr/share/perihelion/palettes, then ~/.local/share/perihelion/palettes.
rm -rf /usr/share/perihelion/palettes
install -d /usr/share/perihelion/palettes
cp -r "${src}/theme/palettes/." /usr/share/perihelion/palettes/
find /usr/share/perihelion/palettes -type d -exec chmod 755 {} + -o -type f -exec chmod 644 {} +
install -Dm755 "${src}/perihelion-trash" /usr/bin/perihelion-trash  # the dock's trash
install -Dm755 "${src}/perihelion-dock-pin" /usr/bin/perihelion-dock-pin  # the app drawer's "Pin to dock"
# The app drawer (Quickshell): apps, wallpapers with previews (local, Bing,
# Wallhaven), Bluetooth and the power menu. `appdrawer` toggles it over IPC
# (the daemon starts at login); Quickshell reads configs only from
# ~/.config/quickshell/<name>, so the QML is kept here and seeded per user.
install -Dm755 "${src}/appdrawer" /usr/bin/appdrawer
install -d /usr/share/perihelion/quickshell/appdrawer
install -m644 "${src}"/quickshell/appdrawer/*.qml /usr/share/perihelion/quickshell/appdrawer/
# Its wallpaper engine (list, Bing, Wallhaven); applying is handed on to
# perihelion-wallpaper, Perihelion's one wallpaper owner.
install -Dm755 "${src}/perihelionbar-wallpaper" /usr/bin/perihelionbar-wallpaper
# The dock's trash: the icon theme's own user-trash first; these stand in
# for a theme without one.
for v in "" "-full"; do
    install -Dm644 "${src}/assets/icons/perihelion-trash${v}.svg" \
        "/usr/share/icons/hicolor/scalable/apps/perihelion-trash${v}.svg"
done
printf '#!/bin/sh\n# perihelionbar calls this after a wallpaper change; Perihelion themes with Catppuccin.\nexec perihelion-theme --force "$@"\n' > /usr/bin/perihelionbar-matugen
chmod 755 /usr/bin/perihelionbar-matugen
install -d /usr/share/perihelion
printf '%s\n' "${PERIHELIONBAR_REF}" > /usr/share/perihelion/perihelionbar.ref
rm -rf "${work}"

rpm -qa --qf '%{NAME}\n' | sort -u > /tmp/perihelionbar-after.txt
mapfile -t build_only < <(comm -13 /tmp/perihelionbar-before.txt /tmp/perihelionbar-after.txt)
if (( ${#build_only[@]} )); then
    log "perihelionbar: removing build-only packages: ${build_only[*]}"
    dnf5 remove -y "${build_only[@]}"
fi
rm -f /tmp/perihelionbar-before.txt /tmp/perihelionbar-after.txt

for bin in /usr/bin/perihelion-bar /usr/bin/perihelion-shell /usr/bin/perihelion-settings; do
    if ldd "${bin}" | grep -F 'not found'; then
        die "${bin} is missing shared libraries"
    fi
done
log "perihelionbar: installed perihelionbar, perihelionbar-shell and perihelionbar-config"
