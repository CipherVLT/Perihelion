#!/usr/bin/env bash
# Build and install simpbar, the top bar of the Mango flavor.
#
# simpbar by jaytheoutpatient: https://github.com/jaytheoutpatient/simpbar
# A native Zig/Wayland status bar for Hyprland and MangoWM. Only the bar
# (/usr/bin/simpbar) and simpbar-shell (/usr/bin/simpbar-shell: desktop
# widgets and window overview, also native Zig) are installed; its
# Welcome/Config apps, Quickshell app drawer and Arch installer are not.
#
# Built from the commit pinned in build/refs/simpbar.ref with Zig 0.16.0
# (the release tarball from ziglang.org, verified against the Zig Software
# Foundation's minisign key). Build-only packages are removed afterwards.
set -euo pipefail
# shellcheck source=build/lib.sh
source "${PERIHELION_SRC}/build/lib.sh"

SIMPBAR_REPO=https://github.com/jaytheoutpatient/simpbar.git
SIMPBAR_REF=$(tr -d '[:space:]' < "${PERIHELION_SRC}/build/refs/simpbar.ref")
ZIG_VERSION=0.16.0
ZIG_PUBKEY='RWSGOq2NVecA2UPNdBUZykf1CCb147pkmdtYxgb3Ti+JO/wCYvhbAb/U'
# Every x86-64 CPU since ~2009; simpbar's installer otherwise tunes for the
# build machine.
ZIG_CPU=x86_64_v2

log "simpbar: building ${SIMPBAR_REF:0:7}"
rpm -qa --qf '%{NAME}\n' | sort -u > /tmp/simpbar-before.txt

# The bar links wayland-client, freetype2 and gdk-pixbuf. `zig build` also
# compiles simpbar's GTK apps (simpbar-welcome, simpbar-config), so their
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

src="${work}/simpbar"
git -C "${work}" init -q simpbar
git -C "${src}" remote add origin "${SIMPBAR_REPO}"
retry git -C "${src}" fetch -q --depth 1 origin "${SIMPBAR_REF}"
git -C "${src}" checkout -q --detach FETCH_HEAD
# Perihelion's patches: cava as a sound wave in the left group (beside mpris).
for patch in "${PERIHELION_SRC}"/build/patches/simpbar-*.patch; do
    git -C "${src}" apply "${patch}" || die "simpbar patch does not apply: ${patch##*/}"
done

# The bar lives in the simpbar/ subfolder; its Wayland dependency is vendored
# in simpbar/zig-pkg, so the build needs no further downloads.
(
    cd "${src}/simpbar"
    "${zig_dir}/zig" build -Doptimize=ReleaseFast "-Dcpu=${ZIG_CPU}"
)
install -Dm755 "${src}/simpbar/zig-out/bin/simpbar" /usr/bin/simpbar

# simpbar-shell (desktop widgets, window overview); shares the bar's font code.
(
    cd "${src}/simpbar-shell"
    "${zig_dir}/zig" build -Doptimize=ReleaseFast "-Dcpu=${ZIG_CPU}"
)
install -Dm755 "${src}/simpbar-shell/zig-out/bin/simpbar-shell" /usr/bin/simpbar-shell
install -d /usr/share/perihelion
printf '%s\n' "${SIMPBAR_REF}" > /usr/share/perihelion/simpbar.ref
rm -rf "${work}"

rpm -qa --qf '%{NAME}\n' | sort -u > /tmp/simpbar-after.txt
mapfile -t build_only < <(comm -13 /tmp/simpbar-before.txt /tmp/simpbar-after.txt)
if (( ${#build_only[@]} )); then
    log "simpbar: removing build-only packages: ${build_only[*]}"
    dnf5 remove -y "${build_only[@]}"
fi
rm -f /tmp/simpbar-before.txt /tmp/simpbar-after.txt

for bin in /usr/bin/simpbar /usr/bin/simpbar-shell; do
    if ldd "${bin}" | grep -F 'not found'; then
        die "${bin} is missing shared libraries"
    fi
done
log "simpbar: installed /usr/bin/simpbar and /usr/bin/simpbar-shell"
