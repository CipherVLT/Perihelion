#!/usr/bin/env bash
# Mango flavor: Veyl OS keybinds, gaps and look translated to Mango, with
# simpbar, swaybg and fuzzel. No Event Horizon.
set -euo pipefail
# shellcheck source=build/lib.sh
source "${PERIHELION_SRC}/build/lib.sh"

log "mango: $(rpm -q mangowm)"
command -v mango >/dev/null || die "mango binary missing"

apply_system_files mango
rm -f /.gitkeep
chmod 0755 /usr/bin/perihelion-wallpaper /usr/bin/perihelion-screenshot /usr/bin/perihelion-keys

# Top bar: simpbar, built from source.
bash "${PERIHELION_SRC}/build/install-simpbar.sh"

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
# simpbar draws text with one TTF file; point it at the installed
# JetBrainsMono Nerd Font (simpbar's own default is Arch's path).
# Regular weight by file name (fontconfig style matching picked ExtraBold).
font=$(fc-list --format '%{file}\n' | grep -m1 '/JetBrainsMonoNerdFont-Regular\.ttf$' || true)
[[ -n "${font}" && -f "${font}" ]] || die "JetBrainsMono Nerd Font not found (needed by simpbar)"
log "mango: simpbar font ${font}"
bar_cfg=$(mktemp)
chmod 644 "${bar_cfg}"
sed "s|@FONT_PATH@|${font}|" "${share}/simpbar/config.json" > "${bar_cfg}"
grep -q "\"font_path\": \"${font}\"" "${bar_cfg}" || die "could not set simpbar's font_path"
install -m644 "${bar_cfg}" "${share}/simpbar/config.json"
rm -f "${bar_cfg}"
seed_user_file "${share}/simpbar/config.json" .config/simpbar/config.json
seed_user_file "${share}/fuzzel/fuzzel.ini" .config/fuzzel/fuzzel.ini

test -f /usr/share/wayland-sessions/mango.desktop
log "mango: done"
