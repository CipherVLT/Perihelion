#!/usr/bin/env bash
# Shared %post for every Perihelion flavor. Runs inside the installed system
# (chroot) after all packages from %packages are in place.
set -euo pipefail
# shellcheck source=build/lib.sh
source "${PERIHELION_SRC}/build/lib.sh"

log "common: system files"
apply_system_files common
chmod 0755 /usr/bin/strata /usr/libexec/perihelion-trash /usr/libexec/perihelion-strata-theme

# --- Wallpapers -----------------------------------------------------------------
install -d /usr/share/backgrounds/perihelion
install -m644 "${PERIHELION_SRC}/branding/wallpapers/perihelion-horizon.png" \
    /usr/share/backgrounds/perihelion/default.png
install -m644 "${PERIHELION_SRC}/branding/wallpapers/perihelion-galaxies.png" \
    /usr/share/backgrounds/perihelion/galaxies.png

# --- Login screen: SDDM + Pixie -----------------------------------------------------
theme=/usr/share/sddm/themes/pixie
install -m644 /usr/share/backgrounds/perihelion/default.png "${theme}/assets/background.png"
chmod -R u=rwX,go=rX "${theme}"
install -d /etc/sddm.conf.d
cat > /etc/sddm.conf.d/10-perihelion.conf <<'EOF'
[General]
# The greeter runs on its own small Wayland compositor (Weston), so the
# login screen needs no X server.
DisplayServer=wayland

[Theme]
Current=pixie

[Users]
MinimumUid=1000
MaximumUid=60000
EOF
systemctl enable sddm.service
systemctl set-default graphical.target

# --- Strata: file manager, "Show in folder", Open/Save dialogs, Trash -------------
log "common: Strata"
bash "${PERIHELION_SRC}/build/install-strata.sh"
systemctl --global enable perihelion-strata-theme.path

# Default applications for every session. /etc/xdg/mimeapps.list is read by
# xdg-open and GIO apps; a user's ~/.config/mimeapps.list still wins.
firefox_desktop=
for name in org.mozilla.firefox.desktop firefox.desktop; do
    if [[ -f "/usr/share/applications/${name}" ]]; then
        firefox_desktop=${name}
        break
    fi
done
[[ -n "${firefox_desktop}" ]] || die "Firefox desktop file not found"
{
    echo '[Default Applications]'
    echo 'inode/directory=io.github.lgse.Strata.desktop;'
    for mime in text/html application/xhtml+xml x-scheme-handler/http \
        x-scheme-handler/https x-scheme-handler/about x-scheme-handler/unknown \
        application/pdf; do
        echo "${mime}=${firefox_desktop};"
    done
} > /etc/xdg/mimeapps.list

# Firefox: Open/Save dialogs through xdg-desktop-portal (Strata).
ff_done=0
for ff in /usr/lib64/firefox /usr/lib/firefox; do
    [[ -d "${ff}/browser" ]] || continue
    install -d "${ff}/browser/defaults/preferences"
    printf '%s\n' \
        '// Perihelion: Open/Save dialogs through xdg-desktop-portal (Strata).' \
        'pref("widget.use-xdg-desktop-portal.file-picker", 1);' \
        'pref("widget.use-xdg-desktop-portal.open-uri", 1);' \
        > "${ff}/browser/defaults/preferences/perihelion-portal.js"
    ff_done=1
done
(( ff_done )) || die "Firefox install folder not found"

# GTK 3 and Electron apps: use the portal dialog in every session.
cat > /etc/profile.d/perihelion-portal.sh <<'EOF'
# Perihelion: GTK 3 / Electron apps use the system Open/Save dialog (Strata).
export GTK_USE_PORTAL=1
EOF

# Strata must be the only "Show in folder" handler.
mapfile -t fm1 < <(grep -l -x 'Name=org.freedesktop.FileManager1' /usr/share/dbus-1/services/*.service)
(( ${#fm1[@]} == 1 )) || die "FileManager1 is provided by: ${fm1[*]}"

# --- Gaming head start ------------------------------------------------------------
log "common: gaming"
# Wine 11+ uses NTSync automatically when /dev/ntsync exists.
echo ntsync > /etc/modules-load.d/ntsync.conf
install -d /usr/share/perihelion
bash "${PERIHELION_SRC}/build/install-wine.sh"
for tool in steam gamescope mangohud gamemoderun wine winetricks; do
    command -v "${tool}" >/dev/null || die "missing ${tool}"
done

# --- Flathub ------------------------------------------------------------------------
# System-wide remote so users can add apps without hunting for the URL.
retry flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo \
    || log "WARNING: could not add Flathub (no network?); run the same command later"

# --- Identity -------------------------------------------------------------------------
cat > /usr/share/perihelion/release <<EOF
PERIHELION_FLAVOR=${PERIHELION_FLAVOR:?}
PERIHELION_FEDORA=$(rpm -E %fedora)
PERIHELION_BUILT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

log "common: done"
