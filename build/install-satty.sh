#!/usr/bin/env bash
# Screenshot editor: Satty (https://github.com/gabm/Satty, MPL-2.0).
# Super+Shift+S runs /usr/bin/horizon-screenshot: slurp dims the screen for
# a region pick, grim captures it, Satty opens it with crop/draw/text/blur and
# Copy / Save / Save as.
#
# Fedora and Terra first. If neither packages Satty, install the official
# x86_64 release pinned in satty.ref ("<version> <sha256 of the .tar.gz>"),
# checked before anything is installed.
set -euo pipefail
trap 'echo "::error title=install-satty.sh::line ${LINENO}: ${BASH_COMMAND}"' ERR

if dnf5 install -y --enable-repo=terra satty >/tmp/satty-dnf.log 2>&1; then
    echo "Satty: installed from Fedora/Terra ($(rpm -q satty))"
else
    echo "Satty: not in Fedora/Terra, using the pinned upstream release"
    read -r version sha256 < "${PERIHELION_SRC}/build/refs/satty.ref"
    dnf5 install -y gtk4 libadwaita fontconfig
    work=$(mktemp -d)
    trap 'rm -rf "${work}"' EXIT
    curl --fail --location --silent --show-error --retry 3 -o "${work}/satty.tar.gz" \
        "https://github.com/gabm/Satty/releases/download/v${version}/satty-x86_64-unknown-linux-gnu.tar.gz"
    echo "${sha256}  ${work}/satty.tar.gz" | sha256sum -c -
    tar -xzf "${work}/satty.tar.gz" -C "${work}"
    install -Dm755 "${work}/satty" /usr/bin/satty
    install -Dm644 "${work}/satty.desktop" /usr/share/applications/satty.desktop
    install -Dm644 "${work}/assets/satty.svg" /usr/share/icons/hicolor/scalable/apps/satty.svg
    install -Dm644 "${work}/man/satty.1" /usr/share/man/man1/satty.1
    install -Dm644 "${work}/completions/satty.bash" /usr/share/bash-completion/completions/satty
    install -Dm644 "${work}/completions/satty.fish" /usr/share/fish/vendor_completions.d/satty.fish
    install -Dm644 "${work}/LICENSE" /usr/share/licenses/satty/LICENSE
fi

if ldd /usr/bin/satty | grep -F 'not found'; then
    echo "Satty is missing shared libraries" >&2
    exit 1
fi
satty --version
