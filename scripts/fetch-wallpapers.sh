#!/usr/bin/env bash
# Download the default wallpapers into branding/wallpapers/ for a local build.
#
# These are Kurzgesagt – In a Nutshell artwork (some color-shifted to
# Catppuccin Mocha), collected in https://github.com/teowelton/Wallpapers.
# Kurzgesagt has not released them under an open license: they are free for
# private, personal use. That is why they are not stored in this repository
# and are .gitignored. An ISO built with them is for your own machines only;
# do not publish one without Kurzgesagt's permission.
#
# Without wallpapers the build still works: the login screen uses the Pixie
# theme's plain background color and the desktops start without a picture.
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dest="${repo_dir}/branding/wallpapers"
base=https://raw.githubusercontent.com/teowelton/Wallpapers/main

# <file name in branding/wallpapers> <path in teowelton/Wallpapers>
# The first line becomes the default wallpaper (login screen and desktop).
wallpapers=(
    "black-hole-2-mocha.png catppuccin/mocha/kurzgesagt/Black_Hole_2-Catppuccin_Mocha.png"
    "black-hole-3-mocha.png catppuccin/mocha/kurzgesagt/Black_Hole_3-Catppuccin_Mocha.png"
    "black-hole-1.png unthemed/kurzgesagt/Black_Hole_1.png"
)

echo "These wallpapers are Kurzgesagt artwork, free for private, personal use."
echo "ISOs built with them are for your own machines; don't publish them."
mkdir -p "${dest}"
for entry in "${wallpapers[@]}"; do
    read -r name path <<<"${entry}"
    if [[ -s "${dest}/${name}" ]]; then
        echo "have ${name}"
        continue
    fi
    curl --fail --location --silent --show-error --retry 3 -o "${dest}/${name}.part" "${base}/${path}"
    mv -f "${dest}/${name}.part" "${dest}/${name}"
    echo "got  ${name}"
done
read -r default_name _ <<<"${wallpapers[0]}"
printf '%s\n' "${default_name}" > "${dest}/DEFAULT"
echo "default: ${default_name}"
