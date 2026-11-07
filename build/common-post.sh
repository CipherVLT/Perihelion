#!/usr/bin/env bash
# Shared %post for every Perihelion flavor. Runs inside the installed system
# (chroot) after all packages from %packages are in place.
set -euo pipefail
# shellcheck source=build/lib.sh
source "${PERIHELION_SRC}/build/lib.sh"

# Keep the system as lean after install as the ISO made it: dnf (here in
# %post and later for the user) does not pull in "recommended" packages.
# Change install_weak_deps to True in /etc/dnf/dnf.conf to undo.
install -d /etc/dnf
if grep -q '^install_weak_deps=' /etc/dnf/dnf.conf 2>/dev/null; then
    sed -i 's/^install_weak_deps=.*/install_weak_deps=False/' /etc/dnf/dnf.conf
elif grep -q '^\[main\]' /etc/dnf/dnf.conf 2>/dev/null; then
    sed -i '/^\[main\]/a install_weak_deps=False' /etc/dnf/dnf.conf
else
    printf '[main]\ninstall_weak_deps=False\n' >> /etc/dnf/dnf.conf
fi
grep -qx 'install_weak_deps=False' /etc/dnf/dnf.conf

log "common: system files"
apply_system_files common
chmod 0755 /usr/bin/perihelion-os-age /usr/bin/strata /usr/bin/perihelion-doctor \
    /usr/bin/perihelion-power-menu /usr/bin/perihelion-greeter-sync /usr/bin/perihelion-wallpaper-picker /usr/bin/perihelion-drawer /usr/bin/perihelion-keys /usr/bin/perihelion-glass /usr/bin/perihelion-wallpapers /usr/libexec/perihelion-trash /usr/libexec/perihelion-strata-theme

# --- Wine -----------------------------------------------------------------------
# Kron4ek's Wine 11.21 build, shipped compressed by scripts/fetch-wine.sh.
# Checked against its pinned sha256, unpacked to /opt/wine, and every program
# in it linked from /usr/local/bin (wine, winecfg, wineserver, ...).
wine_assets="${PERIHELION_SRC}/assets/wine"
if compgen -G "${wine_assets}/wine-*.tar.xz" >/dev/null; then
    (cd "${wine_assets}" && sha256sum -c --quiet SHA256SUMS) || die "Wine download doesn't match its checksum"
    wine_tar=$(compgen -G "${wine_assets}/wine-*.tar.xz" | head -n 1)
    wine_build=$(basename "${wine_tar}" .tar.xz)
    rm -rf /opt/wine
    install -d /opt/wine /usr/local/bin
    tar -xJf "${wine_tar}" -C /opt/wine --strip-components=1 --no-same-owner
    [[ -x /opt/wine/bin/wine ]] || die "Wine (${wine_build}) has no bin/wine"
    printf '%s\n' "${wine_build}" > /opt/wine/PERIHELION_BUILD
    for prog in /opt/wine/bin/*; do
        [[ -f "${prog}" && -x "${prog}" ]] && ln -sfn "${prog}" "/usr/local/bin/$(basename "${prog}")"
    done
    chmod 0755 /usr/local/bin/winetricks
    log "common: ${wine_build} in /opt/wine ($(du -sh /opt/wine | cut -f1)), winetricks"
else
    log "common: no Wine download in assets/wine (scripts/fetch-wine.sh adds it); skipped"
fi

# --- Wallpapers -----------------------------------------------------------------
# Present only if scripts/fetch-wallpapers.sh ran before the ISO was built
# (they are personal-use artwork and never committed). Without them the login
# screen keeps the theme's background color and desktops start plain.
install -d /usr/share/backgrounds/perihelion /usr/share/perihelion
walls="${PERIHELION_SRC}/branding/wallpapers"
wall_default=
shopt -s nullglob
wall_files=("${walls}"/*.png "${walls}"/*.jpg)
shopt -u nullglob
if (( ${#wall_files[@]} )); then
    install -m644 "${wall_files[@]}" /usr/share/backgrounds/perihelion/
    name=$(cat "${walls}/DEFAULT" 2>/dev/null || basename "${wall_files[0]}")
    [[ -f "/usr/share/backgrounds/perihelion/${name}" ]] || die "DEFAULT wallpaper ${name} not found"
    ln -sfn "${name}" /usr/share/backgrounds/perihelion/default.png
    wall_default=/usr/share/backgrounds/perihelion/default.png
    log "common: wallpapers installed, default ${name}"
else
    log "common: no wallpapers in branding/wallpapers; plain backgrounds"
fi

# --- Login screen: SDDM + Pixie -----------------------------------------------------
theme=/usr/share/sddm/themes/pixie
if [[ -n "${wall_default}" ]]; then
    install -m644 "$(readlink -f "${wall_default}")" "${theme}/assets/background.png"
else
    # Pixie draws its backgroundColor when the image is missing.
    sed -i 's/^background=.*/background=/' "${theme}/theme.conf"
fi
chmod -R u=rwX,go=rX "${theme}"
# The login screen follows the desktop: perihelion-greeter-sync (run on
# wallpaper changes) writes the wallpaper and colors here. usr_t like the
# theme, so the greeter may read it; group wheel may write it.
greeter_dir=/usr/local/share/perihelion/greeter
install -d -m 2775 -g wheel "${greeter_dir}"
ln -sfn "${greeter_dir}/theme.conf.user" "${theme}/theme.conf.user"
install -d /etc/sddm.conf.d
cat > /etc/sddm.conf.d/10-perihelion.conf <<'EOF'
[General]
# The greeter runs on its own small Wayland compositor (Weston), so the
# login screen needs no X server.
DisplayServer=wayland

[Theme]
Current=pixie

CursorTheme=Bibata-Modern-Classic
CursorSize=24

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
    # Images (screenshots, wallpapers) open in imv.
    for mime in image/png image/jpeg image/webp image/gif image/bmp image/tiff image/avif; do
        echo "${mime}=imv.desktop;"
    done
} > /etc/xdg/mimeapps.list
[[ -f /usr/share/applications/imv.desktop ]] || die "imv.desktop not found (image viewer)"

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

# --- Flatpak + Flathub ---------------------------------------------------------------
chmod 0755 /usr/libexec/perihelion-flathub
# Add it now; if the installer has no network, the service adds it at boot.
/usr/libexec/perihelion-flathub || log "WARNING: Flathub not reachable now; perihelion-flathub.service adds it at first boot"
systemctl enable perihelion-flathub.service

# --- Time zone ------------------------------------------------------------------
# A system left on UTC gets the time zone of where it is (Fedora's geoip, as
# the installer uses); the boot service retries if the network is down now.
chmod 0755 /usr/libexec/perihelion-auto-timezone
/usr/libexec/perihelion-auto-timezone --install || true
systemctl enable perihelion-auto-timezone.service
# Internet time (chrony), and a hardware clock in UTC like Fedora's default,
# so the clock is right from boot. A PC that also boots Windows keeps a
# local-time hardware clock, which is what Windows expects.
systemctl enable chronyd.service
if [[ -d /boot/efi/EFI/Microsoft ]]; then
    log "common: Windows found; hardware clock stays in local time"
else
    printf '0.0 0 0.0\n0\nUTC\n' > /etc/adjtime
fi

# --- Look: Numix-Circle icons, Bibata cursor, DejaVu Sans Mono --------------------
# gsettings (GTK 4, portals, Event Horizon) and settings.ini (GTK 3, Event
# Horizon's dock, Strata) both carry it; the compositors set the cursor too.
log "common: icons, cursor, monospace font"
for theme in /usr/share/icons/Numix-Circle /usr/share/icons/Bibata-Modern-Classic; do
    [[ -d "${theme}" ]] || die "missing ${theme}"
done
for theme in /usr/share/icons/Numix /usr/share/icons/Numix-Circle; do
    chmod -R u=rwX,go=rX "${theme}"
    gtk-update-icon-cache -qf "${theme}" || true
done
if [[ ! -f /etc/dconf/profile/user ]]; then
    install -d /etc/dconf/profile
    printf 'user-db:user\nsystem-db:local\n' > /etc/dconf/profile/user
fi
grep -qx 'system-db:local' /etc/dconf/profile/user || echo 'system-db:local' >> /etc/dconf/profile/user
dconf update
seed_user_file /usr/share/perihelion/gtk/settings.ini .config/gtk-3.0/settings.ini
seed_user_file /usr/share/perihelion/gtk/settings.ini .config/gtk-4.0/settings.ini
seed_user_file /usr/share/perihelion/qt6ct/qt6ct.conf .config/qt6ct/qt6ct.conf
# Terminal cava: Catppuccin gradient, PulseAudio input
seed_user_file /usr/share/perihelion/cava/config .config/cava/config

# --- App drawer (nwg-drawer, Super+A) ---------------------------------------------
[[ -x /usr/bin/nwg-drawer ]] || die "nwg-drawer is missing from the image (scripts/build-nwg-drawer.sh did not run)"
chmod 0755 /usr/bin/nwg-drawer
seed_user_file /usr/share/perihelion/nwg-drawer/drawer.css .config/nwg-drawer/drawer.css

# --- fastfetch (Veyl OS layout) --------------------------------------------------
chmod 0644 /etc/profile.d/perihelion-fastfetch.sh
ff_cfg=/usr/share/perihelion/fastfetch/config.jsonc
if [[ "${PERIHELION_FLAVOR}" == mango ]]; then
    # Mango starts Catppuccin Macchiato (https://catppuccin.com/palette/), and
    # perihelion-theme recolors these same values for every wallpaper:
    # title bold blue #8aadf4; section headers bold red #ed8796 (OS), blue
    # #8aadf4 (WM), yellow #eed49f (PC and after); values text tinted blue
    # #c2cef5; separator overlay1 #8087a2. Layout and icons stay Veyl OS's.
    # Logo: color 1 (Fedora's blue body) a darker shade of blue #5f75a6,
    # color 2 (the "f") blue #8aadf4.
    sed -i -e 's/"keyColor": "31"/"keyColor": "1;38;2;237;135;150"/' \
        -e 's/"keyColor": "32"/"keyColor": "1;38;2;138;173;244"/' \
        -e 's/"keyColor": "33"/"keyColor": "1;38;2;238;212;159"/' \
        -e 's/"padding": { "top": 3 }/"padding": { "top": 3 },\n        "color": { "1": "38;2;95;117;166", "2": "38;2;138;173;244" }/' \
        -e 's/"separator": " ➜  "/"separator": " ➜  ",\n          "color": { "title": "1;38;2;138;173;244", "output": "38;2;194;206;245", "separator": "38;2;128;135;162" }/' \
        "${ff_cfg}"
    grep -q '"output": "38;2;194;206;245"' "${ff_cfg}" || die "could not apply Mango's fastfetch colors"
    grep -q '"1": "38;2;95;117;166", "2": "38;2;138;173;244"' "${ff_cfg}" || die "could not color Mango's fastfetch logo"
    [[ $(grep -c '"keyColor": "1;38;2;237;135;150"' "${ff_cfg}") -eq 4 ]] || die "Mango's fastfetch OS section is not red-pink"
    ! grep -qE '"keyColor": "3[123]"' "${ff_cfg}" || die "fastfetch config still has Veyl OS colors"
fi
seed_user_file "${ff_cfg}" .config/fastfetch/config.jsonc

# --- Gaming ------------------------------------------------------------------------
for tool in steam gamescope; do
    command -v "${tool}" >/dev/null || die "missing ${tool}"
done

# --- Identity -------------------------------------------------------------------------
{
    echo "PERIHELION_FLAVOR=${PERIHELION_FLAVOR:?}"
    echo "PERIHELION_FEDORA=$(rpm -E %fedora)"
    echo "PERIHELION_INSTALLED=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    # Commit, ISO build time and Fedora ISO, written by scripts/build-iso.sh
    cat "${PERIHELION_SRC}/BUILD" 2>/dev/null || echo "PERIHELION_COMMIT=unknown"
} > /usr/share/perihelion/release

log "common: done"
