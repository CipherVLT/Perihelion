#!/usr/bin/env bash
# Hyprland flavor: Hyprland (nett00n/hyprland COPR) + Event Horizon, with the
# session and default config from horizon-forge / Veyl OS.
set -euo pipefail
# shellcheck source=build/lib.sh
source "${PERIHELION_SRC}/build/lib.sh"

# The seeded config is Lua: Hyprland 0.57 reads only Lua, 0.56 is the first
# release that can. Refuse anything older before building anything.
hypr_ver=$(rpm -q --qf '%{VERSION}' hyprland)
if [[ "$(printf '%s\n0.56\n' "${hypr_ver}" | sort -V | head -n 1)" != "0.56" ]]; then
    die "Hyprland ${hypr_ver} can't read the Lua config (needs 0.56 or newer)"
fi
log "hyprland: Hyprland ${hypr_ver}"

# Keep Hyprland updating from the same COPR it was installed from.
retry dnf5 copr enable -y nett00n/hyprland || die "could not enable the nett00n/hyprland COPR"

apply_system_files hyprland
chmod 0755 /usr/bin/event-horizon-session

bash "${PERIHELION_SRC}/build/event-horizon.sh"

# The default config must at least be valid Lua (Hyprland can't run here).
had_lua=0
rpm -q lua >/dev/null 2>&1 && had_lua=1
dnf5 install -y lua
luac -p /usr/share/event-horizon/skel/hypr/hyprland.lua
(( had_lua )) || dnf5 remove -y lua
if grep -qx "$(sha256sum /usr/share/event-horizon/skel/hypr/hyprland.lua | cut -d' ' -f1)" \
        /usr/share/event-horizon/skel/hypr/previous-defaults.sha256; then
    die "skel hyprland.lua is listed in previous-defaults.sha256"
fi

# One login entry: Event Horizon. The plain Hyprland entries would start the
# same config without the session setup (GPU env, first-login seeding).
rm -f /usr/share/wayland-sessions/hyprland.desktop /usr/share/wayland-sessions/hyprland-uwsm.desktop
test -f /usr/share/wayland-sessions/event-horizon.desktop
test -x /usr/bin/horizon
log "hyprland: done"
