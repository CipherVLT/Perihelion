#!/usr/bin/env bash
# Check that every package a flavor needs exists, before building an ISO.
# Run on Fedora (or in a fedora:45 container). Uses the same repositories as
# the kickstart: Fedora, updates, openh264, Terra, and the flavor's COPR.
#
# Usage: scripts/check-packages.sh <hyprland|niri|mango|all>
#   podman run --rm -v "$PWD":/src:Z -w /src registry.fedoraproject.org/fedora:45 \
#       scripts/check-packages.sh all
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target=${1:-all}
flavors=(hyprland niri mango)
[[ "${target}" == all ]] || flavors=("${target}")

releasever=$(rpm -E %fedora)
repos=(
    --repofrompath "terra,https://repos.fyralabs.com/terra${releasever}"
    --repofrompath "copr-hyprland,https://download.copr.fedorainfracloud.org/results/nett00n/hyprland/fedora-${releasever}-x86_64/"
    --setopt=terra.gpgcheck=0 --setopt=copr-hyprland.gpgcheck=0
)

status=0
for flavor in "${flavors[@]}"; do
    lists=$(sed -n 's/^# PACKAGES:[[:space:]]*//p' "${repo_dir}/kickstart/flavors/${flavor}.ks")
    missing=()
    for list in ${lists}; do
        while read -r pkg; do
            [[ -n "${pkg}" ]] || continue
            if [[ "${pkg}" == @* ]]; then
                dnf5 group info "${repos[@]}" "${pkg#@}" >/dev/null 2>&1 || missing+=("${pkg} (${list})")
            elif [[ -z "$(dnf5 repoquery -q "${repos[@]}" --latest-limit=1 "${pkg}" 2>/dev/null)" ]]; then
                missing+=("${pkg} (${list})")
            fi
        done < <(sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "${repo_dir}/packages/${list}.txt")
    done
    if (( ${#missing[@]} )); then
        printf '%s: MISSING %s\n' "${flavor}" "${missing[*]}"
        status=1
    else
        printf '%s: all packages found (Fedora %s)\n' "${flavor}" "${releasever}"
    fi
done
exit "${status}"
