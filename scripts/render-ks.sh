#!/usr/bin/env bash
# Render the complete kickstart for one flavor:
#   kickstart/base.ks + kickstart/flavors/<flavor>.ks
#   + one %packages section built from the lists the flavor names
#   + kickstart/post.ks
#
# Usage: scripts/render-ks.sh <hyprland|niri|mango> [OUTPUT]
# Default output: out/perihelion-<flavor>.ks
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
flavor=${1:-}
case "${flavor}" in
    hyprland | niri | mango) ;;
    *) echo "usage: $0 <hyprland|niri|mango> [OUTPUT]" >&2; exit 1 ;;
esac
output=${2:-"${repo_dir}/out/perihelion-${flavor}.ks"}
flavor_ks="${repo_dir}/kickstart/flavors/${flavor}.ks"

lists=$(sed -n 's/^# PACKAGES:[[:space:]]*//p' "${flavor_ks}")
[[ -n "${lists}" ]] || { echo "${flavor_ks}: no '# PACKAGES:' line" >&2; exit 1; }

mkdir -p "$(dirname "${output}")"
{
    echo "# Perihelion ${flavor} kickstart, rendered by scripts/render-ks.sh. Do not edit;"
    echo "# change kickstart/ and packages/ instead."
    echo
    cat "${repo_dir}/kickstart/base.ks"
    echo
    cat "${flavor_ks}"
    echo
    echo "%packages"
    for list in ${lists}; do
        file="${repo_dir}/packages/${list}.txt"
        [[ -f "${file}" ]] || { echo "missing package list: ${file}" >&2; exit 1; }
        echo "# --- packages/${list}.txt"
        # Drop comments and blank lines; keep one name per line.
        sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "${file}"
    done
    echo "%end"
    echo
    sed "s/@FLAVOR@/${flavor}/g" "${repo_dir}/kickstart/post.ks"
} > "${output}"

# The same package may be listed twice across lists; that is harmless for
# Anaconda but usually a mistake, so say so.
dupes=$(sed -n '/^%packages$/,/^%end$/p' "${output}" | grep -v -e '^%' -e '^#' | sort | uniq -d)
[[ -z "${dupes}" ]] || echo "note: listed more than once: ${dupes//$'\n'/ }" >&2

if command -v ksvalidator >/dev/null 2>&1; then
    ksvalidator "${output}"
fi
echo "${output}"
