#!/usr/bin/env bash
# Fetch Wine (Kron4ek's builds) and winetricks and stage them into
# system_files/common, so every ISO ships them.
#
# Wine: https://github.com/Kron4ek/Wine-Builds (release 11.21), the
# staging-amd64-wow64 build: Wine Staging's patches, and WoW64, which runs
# 32-bit Windows programs without any 32-bit Linux libraries, so it doesn't
# depend on Fedora's shrinking i686 packages. Wine 11 uses NTSYNC by itself
# when /dev/ntsync is there (see etc/modules-load.d/ntsync.conf). Unpacked to
# /opt/wine, with every program in /opt/wine/bin linked from /usr/local/bin.
# LGPL-2.1.
#
# winetricks: https://github.com/Winetricks/winetricks (release 20260125),
# to /usr/local/bin/winetricks. LGPL-2.1.
#
#   scripts/fetch-wine.sh
set -euo pipefail

WINE_VERSION=11.21
WINE_BUILD="wine-${WINE_VERSION}-staging-amd64-wow64"
WINE_SHA256=a70a9691c42e35f32bab8a8a2deb8f0321aa3081b393c73575727ca76fa503ab
WINETRICKS_VERSION=20260125
WINETRICKS_SHA256=431f82fc74000e6c864409f1d8fb495d696c03928808e3e8acffc45179312a7b

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
root="${repo_dir}/system_files/common"
work=$(mktemp -d)
trap 'rm -rf "${work}"' EXIT

fetch() { # url file sha256
    curl -fsSL --retry 4 --retry-delay 5 -o "$2" "$1"
    echo "$3  $2" | sha256sum -c --quiet - || { echo "checksum mismatch: $1" >&2; exit 1; }
}

# Wine
fetch "https://github.com/Kron4ek/Wine-Builds/releases/download/${WINE_VERSION}/${WINE_BUILD}.tar.xz" \
    "${work}/wine.tar.xz" "${WINE_SHA256}"
rm -rf "${root}/opt/wine"
install -d "${root}/opt/wine"
tar -xJf "${work}/wine.tar.xz" -C "${root}/opt/wine" --strip-components=1
[[ -x "${root}/opt/wine/bin/wine" ]] || { echo "no bin/wine in ${WINE_BUILD}" >&2; exit 1; }
printf '%s\n' "${WINE_BUILD}" > "${root}/opt/wine/PERIHELION_BUILD"

install -d "${root}/usr/local/bin"
find "${root}/usr/local/bin" -maxdepth 1 -lname '/opt/wine/bin/*' -delete
for prog in "${root}"/opt/wine/bin/*; do
    [[ -f "${prog}" && -x "${prog}" ]] || continue
    ln -sfn "/opt/wine/bin/$(basename "${prog}")" "${root}/usr/local/bin/$(basename "${prog}")"
done
license=$(find "${root}/opt/wine" -maxdepth 3 -iname 'LICENSE*' -type f | head -1)
if [[ -n "${license}" ]]; then
    install -Dm644 "${license}" "${root}/usr/share/licenses/wine-kron4ek/LICENSE"
fi
echo "Wine ${WINE_BUILD} staged ($(du -sh "${root}/opt/wine" | cut -f1))"

# winetricks
fetch "https://raw.githubusercontent.com/Winetricks/winetricks/${WINETRICKS_VERSION}/src/winetricks" \
    "${work}/winetricks" "${WINETRICKS_SHA256}"
install -Dm755 "${work}/winetricks" "${root}/usr/local/bin/winetricks"
echo "winetricks ${WINETRICKS_VERSION} staged"
