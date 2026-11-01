#!/usr/bin/env bash
# Install Wine from Kron4ek's prebuilt releases
# (https://github.com/Kron4ek/Wine-Builds), vanilla amd64-wow64 build.
#
# Fedora's stable wine trails upstream development releases by months;
# Kron4ek publishes each one within days. The WoW64 build runs 32-bit and
# 64-bit Windows programs without any i686 Linux libraries.
#
# NTSync: Wine 11+ uses /dev/ntsync automatically when it exists. Perihelion
# loads the ntsync module at boot (build/common-post.sh writes
# /etc/modules-load.d/ntsync.conf).
#
# wine.ref pins "<version> <sha256 of the .tar.xz>". The archive is checked
# against that hash before anything is installed, so a changed or tampered
# download fails the build. To update: put the new version and the hash
# from the release notes into wine.ref.
set -euo pipefail
# Show the failing line on the GitHub run page (as an annotation).
trap 'echo "::error title=install-wine.sh::line ${LINENO}: ${BASH_COMMAND}"' ERR

read -r version sha256 < "${PERIHELION_SRC}/build/refs/wine.ref"
if [[ "$(uname -m)" != x86_64 ]]; then
    echo "Wine: no $(uname -m) build pinned, skipping" >&2
    exit 0
fi

package="wine-${version}-amd64-wow64"
url="https://github.com/Kron4ek/Wine-Builds/releases/download/${version}/${package}.tar.xz"
dest=/usr/lib/wine-kron4ek

# Fedora's wine would own the same commands; never ship both.
if rpm -q wine-core >/dev/null 2>&1; then
    dnf5 remove -y 'wine*'
fi

work=$(mktemp -d)
trap 'rm -rf "${work}"' EXIT
curl --fail --location --silent --show-error --retry 3 -o "${work}/wine.tar.xz" "${url}"
echo "${sha256}  ${work}/wine.tar.xz" | sha256sum -c -
tar -xJf "${work}/wine.tar.xz" -C "${work}"

rm -rf "${dest}"
# Headers and the toolchain (winegcc, widl, ...) are for building Winelib
# programs; nobody needs them on a gaming desktop.
rm -rf "${work}/${package}/include"
rm -f "${work}/${package}/bin/"{function_grep.pl,widl,winebuild,winecpp,wineg++,winegcc,winemaker,wmc,wrc,winedump}
cp -a "${work}/${package}" "${dest}"

# Put the user-facing commands on PATH. winetricks (Fedora package) finds
# wine through PATH as well.
for cmd in "${dest}"/bin/*; do
    name=$(basename "${cmd}")
    if [[ -e "/usr/bin/${name}" && ! -L "/usr/bin/${name}" ]]; then
        echo "Wine: /usr/bin/${name} already exists, not replacing it" >&2
        continue
    fi
    ln -sfn "${cmd}" "/usr/bin/${name}"
done

# "Open with Wine" for .exe/.msi files in the file manager.
install -Dm644 "${dest}/share/applications/wine.desktop" /usr/share/applications/wine.desktop
update-desktop-database /usr/share/applications 2>/dev/null || true

printf '%s\n' "${version}" > /usr/share/perihelion/wine-version

# Smoke test: the loader starts and reports the pinned version, and the
# server was built with NTSync support.
"/usr/bin/wine" --version | grep -qx "wine-${version}"
grep -q /dev/ntsync "${dest}/bin/wineserver"
echo "Wine ${version} installed in ${dest}"
