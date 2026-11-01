#!/usr/bin/env bash
# Install Strata (https://github.com/lgse/strata, MIT), a GTK4 file manager,
# from its official x86_64 release archive.
#
# strata.ref pins "<version> <sha256 of the .tar.gz>". The archive is checked
# against that hash before anything is installed, so a changed or tampered
# download fails the build. To update: put the new version and the hash from
# the release's .tar.gz.sha256 asset into strata.ref.
#
# Strata is the file manager: the folder handler in every session
# (build/common-post.sh writes mimeapps.list) and the
# org.freedesktop.FileManager1 D-Bus service that "Show in folder" in
# Firefox, Steam and others calls. It is also the Open/Save dialog of every
# app in every session (the XDG FileChooser portal), with the GTK
# dialog as fallback.
set -euo pipefail
# Show the failing line on the GitHub run page (as an annotation).
trap 'echo "::error title=install-strata.sh::line ${LINENO}: ${BASH_COMMAND}"' ERR

read -r version sha256 < "${PERIHELION_SRC}/build/refs/strata.ref"
arch=$(uname -m)
if [[ "${arch}" != x86_64 ]]; then
    echo "Strata: no ${arch} build pinned, skipping" >&2
    exit 0
fi

package="strata-${version}-x86_64-unknown-linux-gnu"
url="https://github.com/lgse/strata/releases/download/v${version}/${package}.tar.gz"

# Runtime libraries the binary links against (gtk4, gtksourceview5,
# poppler-glib, gstreamer). Already in packages/base.txt; listed again so
# this script also works on its own. Thumbnailers are left out on purpose.
dnf5 install -y \
    gtk4 \
    gtksourceview5 \
    poppler-glib \
    graphene \
    gstreamer1 \
    gstreamer1-plugins-base \
    gvfs \
    bubblewrap \
    xdg-utils \
    desktop-file-utils

work=$(mktemp -d)
trap 'rm -rf "${work}"' EXIT
curl --fail --location --silent --show-error --retry 3 -o "${work}/strata.tar.gz" "${url}"
echo "${sha256}  ${work}/strata.tar.gz" | sha256sum -c -
tar -xzf "${work}/strata.tar.gz" -C "${work}"
src="${work}/${package}"

# The binary lives in /usr/libexec; /usr/bin/strata (system_files) is a
# wrapper that runs a copy in ~/.local/bin so Strata's own updater works.
install -Dm755 "${src}/strata" /usr/libexec/strata/strata
test -x /usr/bin/strata
install -Dm644 "${src}/io.github.lgse.Strata.desktop" \
    /usr/share/applications/io.github.lgse.Strata.desktop
install -Dm644 "${src}/io.github.lgse.Strata.svg" \
    /usr/share/icons/hicolor/scalable/apps/io.github.lgse.Strata.svg
install -Dm644 -t /usr/share/licenses/strata \
    "${src}/LICENSE" "${src}/THIRD_PARTY_LICENSES.md" "${src}/UnRAR.txt"
install -Dm644 "${src}/SOURCE_COMMIT" /usr/share/licenses/strata/SOURCE_COMMIT

# "Show in folder" from other apps. dbus-broker wants the file named after
# the bus name it provides.
install -Dm644 "${src}/io.github.lgse.Strata.FileManager1.service" \
    /usr/share/dbus-1/services/org.freedesktop.FileManager1.service
grep -q '^Exec=/usr/bin/strata ' /usr/share/dbus-1/services/org.freedesktop.FileManager1.service

# Open/Save dialogs (xdg-desktop-portal FileChooser). Portal metadata and
# the backend's D-Bus activation, system-wide.
install -Dm644 "${src}/portal/strata.portal" \
    /usr/share/xdg-desktop-portal/portals/strata.portal
sed 's|@STRATA_EXECUTABLE@|/usr/bin/strata|' \
    "${src}/portal/org.freedesktop.impl.portal.desktop.strata.service.in" \
    > /usr/share/dbus-1/services/org.freedesktop.impl.portal.desktop.strata.service
chmod 644 /usr/share/dbus-1/services/org.freedesktop.impl.portal.desktop.strata.service
grep -qx 'Exec=/usr/bin/strata --portal' \
    /usr/share/dbus-1/services/org.freedesktop.impl.portal.desktop.strata.service
# Prefer Strata for Open/Save in every compositor session the system ships
# (hyprland-, niri- or mango-portals.conf), keeping each one's other portal
# choices. /etc/xdg overrides the copy in /usr/share; a user's own
# ~/.config/xdg-desktop-portal file still wins.
install -d /etc/xdg/xdg-desktop-portal
shopt -s nullglob
for portals in /usr/share/xdg-desktop-portal/{hyprland,niri,mango}-portals.conf; do
    out="/etc/xdg/xdg-desktop-portal/$(basename "${portals}")"
    {
        grep -v '^org\.freedesktop\.impl\.portal\.FileChooser=' "${portals}"
        echo "org.freedesktop.impl.portal.FileChooser=strata;gtk"
    } > "${out}"
    echo "--- ${out}"; cat "${out}"
done
shopt -u nullglob

desktop-file-validate /usr/share/applications/io.github.lgse.Strata.desktop
if ldd /usr/libexec/strata/strata | grep -F 'not found'; then
    echo "Strata is missing shared libraries" >&2
    exit 1
fi
echo "Installed Strata ${version} ($(cat "${src}/SOURCE_COMMIT"))"
