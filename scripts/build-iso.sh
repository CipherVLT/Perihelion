#!/usr/bin/env bash
# Build a Perihelion installer ISO from Fedora's Everything netinstall ISO.
#
# The output boots the stock Fedora installer (Anaconda) with the flavor's
# kickstart preselected and this repository available at
# /run/install/repo/perihelion. Disk, user, locale and timezone stay
# interactive. Packages are downloaded during installation.
#
# Adapted from dwm-titus scripts/build-dwm-fedora-installer-iso.sh
# (Chris Titus Tech, MIT).
#
# Usage:
#   scripts/build-iso.sh --flavor mango \
#       --input Fedora-Everything-netinst-x86_64-45.iso \
#       --output out/perihelion-mango.iso
#
# Needs (Fedora): xorriso rsync isomd5sum  (pykickstart for ksvalidator)
set -euo pipefail

err() { printf 'build-iso: %s\n' "$*" >&2; }
usage() { sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; }

flavor='' input_iso='' output_iso=''
while (($# > 0)); do
    case "$1" in
        --flavor) flavor=${2:-}; shift 2 ;;
        --input) input_iso=${2:-}; shift 2 ;;
        --output) output_iso=${2:-}; shift 2 ;;
        -h | --help) usage; exit 0 ;;
        *) err "unknown argument: $1"; usage >&2; exit 1 ;;
    esac
done
case "${flavor}" in
    hyprland | niri | mango) ;;
    *) err "--flavor must be hyprland, niri or mango"; exit 1 ;;
esac
[[ -n "${input_iso}" && -n "${output_iso}" ]] || { usage >&2; exit 1; }
[[ -f "${input_iso}" ]] || { err "input ISO not found: ${input_iso}"; exit 1; }
for command in xorriso rsync implantisomd5 checkisomd5; do
    command -v "${command}" >/dev/null 2>&1 || { err "missing required command: ${command}"; exit 1; }
done

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work_dir="$(mktemp -d)"
tmp_output=
trap 'rm -rf "${work_dir}"; [[ -z ${tmp_output} ]] || rm -f "${tmp_output}"' EXIT

ks_file="${work_dir}/perihelion.ks"
"${repo_dir}/scripts/render-ks.sh" "${flavor}" "${ks_file}" >/dev/null

# The payload the installer copies into the new system. Only what the
# %post steps need: no Git history, no build output, no ISOs.
payload_dir="${work_dir}/perihelion"
rsync -a --delete \
    --exclude='.git/' --exclude='out/' --exclude='*.iso' \
    --exclude='.env' --exclude='.env.*' \
    "${repo_dir}/" "${payload_dir}/"

# Fedora x86_64 has separate UEFI and BIOS menus. Add inst.ks to every
# installer entry in both, pointing at the same media stage2 already uses,
# so this works whatever the ISO's volume label is.
grub_args=()
for grub_path in /EFI/BOOT/grub.cfg /boot/grub2/grub.cfg; do
    grub_cfg="${work_dir}/${grub_path//\//_}"
    xorriso -osirrox on -indev "${input_iso}" -extract "${grub_path}" "${grub_cfg}" >/dev/null 2>&1 || {
        err "could not read ${grub_path} from the input ISO"; exit 1; }
    awk '
    /^[[:space:]]*linux(efi)?[[:space:]]/ {
        if (match($0, /inst\.stage2=[^[:space:]]+/)) {
            stage2 = substr($0, RSTART + 12, RLENGTH - 12)
            if (index($0, "inst.ks=") == 0) $0 = $0 " inst.ks=" stage2 ":/perihelion.ks"
        }
    }
    /^[[:space:]]*menuentry[[:space:]]/ { gsub(/Install Fedora/, "Install Perihelion"); gsub(/install Fedora/, "install Perihelion") }
    { print }
    ' "${grub_cfg}" > "${grub_cfg}.patched"
    grep -q 'inst.ks=' "${grub_cfg}.patched" || { err "no installer entry patched in ${grub_path}"; exit 1; }
    grub_args+=(-map "${grub_cfg}.patched" "${grub_path}")
done

output_dir="$(dirname "${output_iso}")"
mkdir -p "${output_dir}"
tmp_output="$(mktemp "${output_dir}/.$(basename "${output_iso}").tmp.XXXXXX")"
rm -f "${tmp_output}"

xorriso -indev "${input_iso}" -outdev "${tmp_output}" \
    -boot_image any replay \
    -map "${ks_file}" /perihelion.ks \
    -map "${payload_dir}" /perihelion \
    "${grub_args[@]}"

# Rewriting the ISO drops Fedora's media checksum, and the default boot
# entry checks it (rd.live.check). Implant and verify a fresh one.
implantisomd5 --force --supported-iso "${tmp_output}"
checkisomd5 "${tmp_output}"

mv -f "${tmp_output}" "${output_iso}"
tmp_output=
printf 'Created %s (%s)\n' "${output_iso}" "${flavor}"
