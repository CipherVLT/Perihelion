#!/usr/bin/env bash
# Niri flavor: niri (Fedora) + Event Horizon. The config is niri's own
# default with Perihelion's apps swapped in and Event Horizon instead of
# waybar.
set -euo pipefail
# shellcheck source=build/lib.sh
source "${PERIHELION_SRC}/build/lib.sh"

command -v niri >/dev/null || die "niri binary missing"
log "niri: $(niri --version)"

apply_system_files niri
bash "${PERIHELION_SRC}/build/event-horizon.sh"

# niri writes its built-in default to ~/.config/niri/config.kdl on first
# start; Fedora's package also ships that file as documentation. Seed an
# edited copy instead, so the binds open apps that are installed.
# Prefer the copy matching the installed niri; fall back to the one shipped
# with Perihelion (niri 26.04) when docs aren't installed.
default_cfg=$(find /usr/share/doc -path '*niri*' -name default-config.kdl -print -quit 2>/dev/null || true)
if [[ -z "${default_cfg}" ]]; then
    default_cfg=/usr/share/perihelion/niri/default-config.kdl
    log "niri: no default-config.kdl in /usr/share/doc; using Perihelion's copy (niri 26.04)"
fi
[[ -f "${default_cfg}" ]] || die "no niri default config found"
cfg=$(mktemp)
chmod 644 "${cfg}"
sed -e 's/spawn "alacritty"/spawn "kitty"/; s/Open a Terminal: alacritty/Open a Terminal: kitty/' \
    -e 's/^spawn-at-startup "waybar"$/spawn-at-startup "horizon"/' \
    -e 's/spawn "swaylock"/spawn "loginctl" "lock-session"/; s/Lock the Screen: swaylock/Lock the Screen/' \
    "${default_cfg}" > "${cfg}"
grep -q 'spawn "kitty"' "${cfg}" || die "could not point niri's terminal bind at kitty"
grep -q '^spawn-at-startup "horizon"$' "${cfg}" || die "could not start Event Horizon from niri's config"
# Super+Shift+S: region screenshot into the editor (Satty). niri's own Print
# binds stay as they are. Added inside the existing binds block, since niri
# allows only one; fails if upstream ever binds Mod+Shift+S itself.
grep -q 'Mod+Shift+S ' "${cfg}" && die "niri's default config already binds Mod+Shift+S"
sed -i '0,/^binds {$/s//binds {\n    \/\/ Perihelion: region screenshot into the editor (Satty).\n    Mod+Shift+S hotkey-overlay-title="Screenshot to editor" { spawn "horizon-screenshot"; }\n/' "${cfg}"
grep -q 'spawn "horizon-screenshot"' "${cfg}" || die "could not add the screenshot bind"
seed_user_file "${cfg}" .config/niri/config.kdl
rm -f "${cfg}"

test -f /usr/share/wayland-sessions/niri.desktop
log "niri: done"
