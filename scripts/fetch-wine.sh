#!/usr/bin/env bash
# Fetch Wine (Kron4ek's builds) and winetricks, so every ISO ships them.
# Wine stays the compressed download (assets/wine/, ~1/5 of its 820 MB
# unpacked: the ISO carries this repo uncompressed); build/common-post.sh
# checks and unpacks it during the install.
#
# Wine: https://github.com/Kron4ek/Wine-Builds (release 11.21), the
# staging-amd64-wow64 build: Wine Staging's patches, and WoW64, which runs
# 32-bit Windows programs without any 32-bit Linux libraries, so it doesn't
# depend on Fedora's shrinking i686 packages. Wine 11 uses NTSYNC by itself
# when /dev/ntsync is there (see etc/modules-load.d/ntsync.conf). Installed
# to /opt/wine, with every program in /opt/wine/bin linked from /usr/local/bin.
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

# Wine: the release file as is, plus what the installer checks it against
assets="${repo_dir}/assets/wine"
rm -rf "${assets}"
install -d "${assets}"
fetch "https://github.com/Kron4ek/Wine-Builds/releases/download/${WINE_VERSION}/${WINE_BUILD}.tar.xz" \
    "${assets}/${WINE_BUILD}.tar.xz" "${WINE_SHA256}"
tar -tJf "${assets}/${WINE_BUILD}.tar.xz" "${WINE_BUILD}/bin/wine" >/dev/null ||
    { echo "no bin/wine in ${WINE_BUILD}" >&2; exit 1; }
printf '%s  %s\n' "${WINE_SHA256}" "${WINE_BUILD}.tar.xz" > "${assets}/SHA256SUMS"
echo "Wine ${WINE_BUILD} staged ($(du -h "${assets}/${WINE_BUILD}.tar.xz" | cut -f1) compressed)"

# winetricks
fetch "https://raw.githubusercontent.com/Winetricks/winetricks/${WINETRICKS_VERSION}/src/winetricks" \
    "${work}/winetricks" "${WINETRICKS_SHA256}"
install -Dm755 "${work}/winetricks" "${root}/usr/local/bin/winetricks"
echo "winetricks ${WINETRICKS_VERSION} staged"
