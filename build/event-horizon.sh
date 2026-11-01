#!/usr/bin/env bash
# Build Event Horizon from source (pinned commit, with horizon-forge's local
# patches), install it system-wide, then remove the build toolchain again.
# Shared by the Hyprland and Niri flavors.
set -euo pipefail
# shellcheck source=build/lib.sh
source "${PERIHELION_SRC}/build/lib.sh"

apply_system_files event-horizon
chmod 0755 /usr/bin/horizon-screenshot
rm -f /.gitkeep

log "event-horizon: building (this takes a few minutes)"
# Remember what is installed, so the build-only packages can be removed.
rpm -qa --qf '%{NAME}\n' | sort -u > /tmp/eh-before.txt

# horizon-forge's build script stages everything under /ehroot.
bash "${PERIHELION_SRC}/build/build-event-horizon.sh"
cp -a /ehroot/. /
rm -rf /ehroot /eh-src /tmp/zig /tmp/zig-global-cache /tmp/zig-local-cache

rpm -qa --qf '%{NAME}\n' | sort -u > /tmp/eh-after.txt
mapfile -t build_only < <(comm -13 /tmp/eh-before.txt /tmp/eh-after.txt)
if (( ${#build_only[@]} )); then
    log "event-horizon: removing build-only packages: ${build_only[*]}"
    dnf5 remove -y "${build_only[@]}"
fi
rm -f /tmp/eh-before.txt /tmp/eh-after.txt

for bin in /usr/bin/horizon /usr/bin/horizon-* /usr/bin/eh-ipc; do
    [[ -e "${bin}" ]] || continue
    if ldd "${bin}" 2>/dev/null | grep -F 'not found'; then
        die "${bin} is missing shared libraries"
    fi
done
/usr/bin/horizon --version
install -d /usr/share/perihelion
cp "${PERIHELION_SRC}/build/refs/event-horizon.ref" /usr/share/perihelion/event-horizon.ref

# Screenshot editor for Super+Shift+S (horizon-screenshot).
bash "${PERIHELION_SRC}/build/install-satty.sh"
log "event-horizon: done"
