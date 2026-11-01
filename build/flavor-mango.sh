#!/usr/bin/env bash
# Mango flavor: Veyl OS keybinds, gaps and look translated to Mango, with
# Waybar, swaybg and fuzzel. No Event Horizon.
set -euo pipefail
# shellcheck source=build/lib.sh
source "${PERIHELION_SRC}/build/lib.sh"

log "mango: $(rpm -q mangowm)"
command -v mango >/dev/null || die "mango binary missing"

apply_system_files mango
rm -f /.gitkeep
chmod 0755 /usr/bin/perihelion-wallpaper /usr/bin/perihelion-screenshot /usr/bin/perihelion-keys

share=/usr/share/perihelion
cfg="${share}/mango/config.conf"

# The config must parse with the Mango that was just installed. `mango -p`
# only reads the file; it needs no display.
if ! out=$(mango -p -c "${cfg}" 2>&1); then
    printf '%s\n' "${out}" >&2
    die "Perihelion's Mango config does not parse with $(rpm -q mangowm)"
fi

# Every program the config launches must be installed.
while read -r prog; do
    [[ -n "${prog}" ]] || continue
    command -v "${prog}" >/dev/null 2>&1 || [[ -x "${prog}" ]] || die "Mango config launches ${prog}, which is not installed"
done < <(sed -n -E 's/^(bind[a-z]*|mousebind|axisbind|gesturebind)=[^,]*,[^,]*,spawn,([^ ,]+).*/\2/p; s/^exec_once=([^ ]+).*/\1/p' "${cfg}" | sort -u)

# Each user gets their own editable copies (existing files are kept).
seed_user_file "${cfg}" .config/mango/config.conf
seed_user_file "${share}/waybar/config.jsonc" .config/waybar/config.jsonc
seed_user_file "${share}/waybar/style.css" .config/waybar/style.css
seed_user_file "${share}/fuzzel/fuzzel.ini" .config/fuzzel/fuzzel.ini

test -f /usr/share/wayland-sessions/mango.desktop
log "mango: done"
