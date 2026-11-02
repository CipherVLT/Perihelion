#!/usr/bin/env bash
# Rehearse a flavor's installation inside a Fedora container, so mistakes in
# the %post scripts fail here instead of in the installer.
#
# Installs the flavor's %packages exactly as the kickstart lists them (no
# weak dependencies, same repositories), creates a regular user the way
# Anaconda does, then runs build/common-post.sh and build/flavor-<f>.sh.
# What a container can't do (boot, start the desktop) is not covered.
#
# Run as root in a throwaway fedora:45 container, never on a real system:
#   podman run --rm -v "$PWD":/src:Z -w /src registry.fedoraproject.org/fedora:45 \
#       scripts/test-install.sh mango
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
flavor=${1:-}
case "${flavor}" in
    hyprland | niri | mango) ;;
    *) echo "usage: $0 <hyprland|niri|mango>" >&2; exit 1 ;;
esac
[[ -f /run/.containerenv || -f /.dockerenv || "${PERIHELION_TEST_ANYWAY:-}" == 1 ]] || {
    echo "refusing to run outside a container: this installs packages and changes system files" >&2
    exit 1
}

releasever=$(rpm -E %fedora)
ks=$(mktemp)
"${repo_dir}/scripts/render-ks.sh" "${flavor}" "${ks}" >/dev/null
mapfile -t packages < <(sed -n '/^%packages/,/^%end$/p' "${ks}" | grep -v -e '^%' -e '^#' -e '^$')

repos=(
    --repofrompath "terra-install,https://repos.fyralabs.com/terra${releasever}"
    --setopt=terra-install.gpgcheck=0
)
if grep -q 'copr-nett00n-hyprland-install' "${ks}"; then
    repos+=(
        --repofrompath "copr-hyprland-install,https://download.copr.fedorainfracloud.org/results/nett00n/hyprland/fedora-${releasever}-x86_64/"
        --setopt=copr-hyprland-install.gpgcheck=0
    )
fi

# Containers have no SELinux, so label mistakes can't show up below. Guard
# the one known way to cause them: copying files onto the system with
# `cp -a`, which carries the source's SELinux label along.
if grep -rnE '\bcp +-[a-zA-Z]*a' "${repo_dir}/build" "${repo_dir}/kickstart" | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' | grep -v '/mnt/sysimage/var/tmp/perihelion'; then
    echo "install scripts must not use cp -a onto the system (copies SELinux labels); use cp -R --preserve=mode,timestamps --no-preserve=ownership,context,xattr" >&2
    exit 1
fi

echo "::group::Install ${#packages[@]} packages (no weak dependencies)"
# tsflags= : container images skip documentation; Anaconda installs it.
dnf5 install -y --setopt=install_weak_deps=False --setopt=tsflags= "${repos[@]}" "${packages[@]}"
echo "::endgroup::"

# Anaconda creates the user before %post runs; do the same.
useradd -m -u 1000 -G wheel tester

echo "::group::%post: common + ${flavor}"
rm -rf /var/tmp/perihelion
cp -a "${repo_dir}" /var/tmp/perihelion
rm -rf /var/tmp/perihelion/.git /var/tmp/perihelion/out
printf 'PERIHELION_COMMIT=%s\n' "${PERIHELION_COMMIT:-test}" > /var/tmp/perihelion/BUILD
# Also exercise the local-build path with wallpapers (scripts/fetch-wallpapers.sh):
# two stand-in 1x1 PNGs, the second marked as the default.
if [[ "${PERIHELION_TEST_WALLPAPERS:-1}" == 1 ]]; then
    for name in test-a.png test-b.png; do
        printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\rIDATx\x9cc\xf8\x0f\x00\x00\x01\x01\x00\x05\x18\xd8N\x00\x00\x00\x00IEND\xaeB`\x82' \
            > "/var/tmp/perihelion/branding/wallpapers/${name}"
    done
    echo test-b.png > /var/tmp/perihelion/branding/wallpapers/DEFAULT
fi
export PERIHELION_SRC=/var/tmp/perihelion PERIHELION_FLAVOR="${flavor}"
bash "${PERIHELION_SRC}/build/common-post.sh"
bash "${PERIHELION_SRC}/build/flavor-${flavor}.sh"
bash -c 'source "${PERIHELION_SRC}/build/lib.sh" && relabel_system'
echo "::endgroup::"

echo "::group::Checks"
fail=0
check() { if "$@"; then echo "  ok    $*"; else echo "  FAIL  $*"; fail=1; fi; }
check test -x /usr/libexec/strata/strata
check grep -q 'inode/directory=io.github.lgse.Strata.desktop' /etc/xdg/mimeapps.list
check grep -qx 'install_weak_deps=False' /etc/dnf/dnf.conf
check grep -q "PERIHELION_FLAVOR=${flavor}" /usr/share/perihelion/release
check test -L /etc/systemd/system/display-manager.service
check test -x /usr/bin/perihelion-doctor
if [[ "${PERIHELION_TEST_WALLPAPERS:-1}" == 1 ]]; then
    check test "$(readlink /usr/share/backgrounds/perihelion/default.png)" = test-b.png
    check test -s /usr/share/sddm/themes/pixie/assets/background.png
fi
case "${flavor}" in
    mango)
        check test -f /home/tester/.config/mango/config.conf
        check test -x /usr/bin/simpbar
        check test -f /home/tester/.config/simpbar/config.json
        check test -f "$(sed -n 's/.*"font_path": "\([^"]*\)".*/\1/p' /home/tester/.config/simpbar/config.json)"
        check grep -q '/JetBrainsMonoNerdFont-Regular.ttf"' /home/tester/.config/simpbar/config.json
        check ldd /usr/bin/simpbar
        check test -f /home/tester/.config/fuzzel/fuzzel.ini
        check mango -p -c /home/tester/.config/mango/config.conf
        check test "$(stat -c %U /home/tester/.config/mango/config.conf)" = tester
        check test -f /etc/xdg/xdg-desktop-portal/mango-portals.conf
        ;;
    hyprland)
        check test -x /usr/bin/horizon
        check test -f /usr/share/wayland-sessions/event-horizon.desktop
        check test -f /etc/xdg/xdg-desktop-portal/hyprland-portals.conf
        ;;
    niri)
        check test -x /usr/bin/horizon
        check test -f /home/tester/.config/niri/config.kdl
        check niri validate -c /home/tester/.config/niri/config.kdl
        check test -f /etc/xdg/xdg-desktop-portal/niri-portals.conf
        ;;
esac
echo "::endgroup::"
(( fail == 0 )) || { echo "install rehearsal for ${flavor}: checks failed" >&2; exit 1; }
echo "install rehearsal for ${flavor}: OK"
