#!/usr/bin/env bash
# Fetch the Numix and Numix-Circle icon themes and stage them into
# system_files/common/usr/share/icons, so the ISO ships them.
#
# Fedora retired numix-icon-theme after Fedora 40, and numix-icon-theme-circle
# (which builds on it) is not in Fedora 45, so both come from the Numix
# project's own repositories at pinned release commits. GPL-3.0.
#
#   scripts/fetch-numix.sh
set -euo pipefail

# repo  tag  commit  theme folders to ship
themes=(
    "numix-icon-theme        25.12.15 df8de01a9d022904c4668d12e4fa8fd547e177b5 Numix"
    "numix-icon-theme-circle 26.02.21 6d4a4aad60994e688ab9dc8f021cb4ec86e9e532 Numix-Circle"
)

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
icons="${repo_dir}/system_files/common/usr/share/icons"
licenses="${repo_dir}/system_files/common/usr/share/licenses"
work=$(mktemp -d)
trap 'rm -rf "${work}"' EXIT

for entry in "${themes[@]}"; do
    read -r repo tag commit folder <<<"${entry}"
    git -c advice.detachedHead=false clone -q --depth 1 --branch "${tag}" \
        "https://github.com/numixproject/${repo}" "${work}/${repo}"
    got=$(git -C "${work}/${repo}" rev-parse HEAD)
    [[ "${got}" == "${commit}" ]] || { echo "${repo} ${tag} is ${got}, expected ${commit}" >&2; exit 1; }
    [[ -f "${work}/${repo}/${folder}/index.theme" ]] || { echo "${repo} has no ${folder}/index.theme" >&2; exit 1; }
    rm -rf "${icons:?}/${folder}"
    install -d "${icons}"
    cp -R "${work}/${repo}/${folder}" "${icons}/${folder}"
    license=$(find "${work}/${repo}" -maxdepth 1 -iname 'license*' -type f | head -1)
    install -Dm644 "${license}" "${licenses}/${repo}/LICENSE"
    echo "${folder} (${repo} ${tag}) staged"
done
