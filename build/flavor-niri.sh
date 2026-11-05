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
# niri's own default config with Event Horizon instead of waybar, and its
# binds block (niri allows exactly one) replaced by Perihelion's Veyl OS set
# from /usr/share/perihelion/niri/binds.kdl.
sed -e 's/^spawn-at-startup "waybar"$/spawn-at-startup "horizon"/' "${default_cfg}" |
    awk '/^binds \{$/ { skip = 1; next } skip && /^\}$/ { skip = 0; next } !skip' > "${cfg}"
grep -q '^spawn-at-startup "horizon"$' "${cfg}" || die "could not start Event Horizon from niri's config"
grep -q '^binds {' "${cfg}" && die "could not remove niri's default binds block"
cat /usr/share/perihelion/niri/binds.kdl >> "${cfg}"
# Always-glass apps, then glass mode (Super+G writes glass.kdl).
cat >> "${cfg}" <<'EOF'

// Always-glass apps (see-through). Add your own the same way
// (app ids: niri msg windows).
window-rule {
    match app-id=r#"^moe\.launcher\.the-honkers-railway-launcher$"#
    opacity 0.85
}

// Floating terminal (Super+Shift+Return): half the screen, bottom-right.
window-rule {
    match app-id="^perihelion-float$"
    open-floating true
    default-column-width { proportion 0.5; }
    default-window-height { proportion 0.55; }
    default-floating-position x=12 y=12 relative-to="bottom-right"
}

// Wallpaper picker (Super+Shift+W): floating.
window-rule {
    match app-id=r#"^io\.github\.perihelion\.Wallpapers$"#
    open-floating true
    default-column-width { proportion 0.75; }
    default-window-height { proportion 0.72; }
}

// Glass mode: Super+G (perihelion-glass) writes glass.kdl.
include optional=true "glass.kdl"
EOF
# Cursor: Bibata Modern Classic, 24 px (niri passes it on to apps). Qt apps
# take their look from qt6ct.
cat >> "${cfg}" <<'EOF'

cursor {
    xcursor-theme "Bibata-Modern-Classic"
    xcursor-size 24
}

environment {
    QT_QPA_PLATFORMTHEME "qt6ct"
}
EOF
[[ $(grep -c '^binds {' "${cfg}") -eq 1 ]] || die "niri config must have exactly one binds block"
niri validate -c "${cfg}" || die "Perihelion's niri config does not validate with $(niri --version)"
seed_user_file "${cfg}" .config/niri/config.kdl
rm -f "${cfg}"

test -f /usr/share/wayland-sessions/niri.desktop
log "niri: done"
