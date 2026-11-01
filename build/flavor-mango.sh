#!/usr/bin/env bash
# Mango flavor: the compositor as upstream ships it, plus only what its
# default keybinds need to be usable. No bar, no shell, nothing else.
set -euo pipefail
# shellcheck source=build/lib.sh
source "${PERIHELION_SRC}/build/lib.sh"

log "mango: config"
apply_system_files mango
rm -f /.gitkeep

upstream=/etc/mango/config.conf
[[ -f "${upstream}" ]] || die "${upstream} missing; is mangowm installed?"
command -v mango >/dev/null || die "mango binary missing"

# Mango's default config opens foot (Alt+Return) and rofi (Alt+Space).
# Perihelion ships kitty and fuzzel instead; nothing else is changed, so it
# stays upstream's config. The user's copy lives in ~/.config/mango.
cfg=$(mktemp)
sed -e 's/^\(bind=[^,]*,[^,]*,spawn,\)foot$/\1kitty/' \
    -e 's/^\(bind=[^,]*,[^,]*,spawn,\)rofi -show drun$/\1fuzzel/' \
    "${upstream}" > "${cfg}"
grep -q ',spawn,kitty$' "${cfg}" || die "could not point Mango's terminal bind at kitty (upstream config changed?)"
grep -q ',spawn,fuzzel$' "${cfg}" || die "could not point Mango's launcher bind at fuzzel (upstream config changed?)"

# A polkit agent, so password prompts (Steam's, pkexec, ...) can appear.
agent=/usr/libexec/polkit-mate-authentication-agent-1
[[ -x "${agent}" ]] || die "missing ${agent}"
printf '\n# Perihelion: password prompts for apps that ask for admin rights\nexec-once=%s\n' "${agent}" >> "${cfg}"

seed_user_file "${cfg}" .config/mango/config.conf
rm -f "${cfg}"

test -f /usr/share/wayland-sessions/mango.desktop
log "mango: done"
