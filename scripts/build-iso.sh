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
# The input must be a Fedora Everything netinstall ISO whose SHA256 is
# listed in scripts/fedora-netinst.ref; anything else is refused.
#
# Usage:
#   scripts/build-iso.sh --flavor mango --download --output out/perihelion-mango.iso
#   scripts/build-iso.sh --flavor mango --input Fedora-Everything-netinst-x86_64-45.iso \
#       --output out/perihelion-mango.iso
#
#   --download   fetch the pinned ISO (last line of fedora-netinst.ref) into
#                out/ if it isn't there yet, verify it, and use it as input
#
# Needs (Fedora): xorriso rsync isomd5sum curl  (pykickstart for ksvalidator)
set -euo pipefail

err() { printf 'build-iso: %s\n' "$*" >&2; }
usage() { sed -n '2,23p' "$0" | sed 's/^# \{0,1\}//'; }

flavor='' input_iso='' output_iso='' download=0
while (($# > 0)); do
    case "$1" in
        --flavor) flavor=${2:-}; shift 2 ;;
        --input) input_iso=${2:-}; shift 2 ;;
        --output) output_iso=${2:-}; shift 2 ;;
        --download) download=1; shift ;;
        -h | --help) usage; exit 0 ;;
        *) err "unknown argument: $1"; usage >&2; exit 1 ;;
    esac
done
case "${flavor}" in
    hyprland | niri | mango) ;;
    *) err "--flavor must be hyprland, niri or mango"; exit 1 ;;
esac
[[ -n "${output_iso}" ]] || { usage >&2; exit 1; }
(( download )) || [[ -n "${input_iso}" ]] || { err "give --input ISO or --download"; exit 1; }
for command in xorriso rsync implantisomd5 checkisomd5 sha256sum; do
    command -v "${command}" >/dev/null 2>&1 || { err "missing required command: ${command}"; exit 1; }
done

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
pins="${repo_dir}/scripts/fedora-netinst.ref"
pin_lines=$(grep -v -e '^#' -e '^[[:space:]]*$' "${pins}")
[[ -n "${pin_lines}" ]] || { err "no ISOs pinned in ${pins}"; exit 1; }

if (( download )); then
    read -r pin_name pin_sha pin_url pin_checksum <<<"$(tail -n 1 <<<"${pin_lines}")"
    input_iso="${repo_dir}/out/$(basename "${pin_url}")"
    if [[ ! -f "${input_iso}" ]]; then
        command -v curl >/dev/null || { err "missing required command: curl"; exit 1; }
        mkdir -p "${repo_dir}/out"
        printf 'Downloading Fedora %s netinstall...\n' "${pin_name}"
        curl --fail --location --retry 3 -C - -o "${input_iso}.part" "${pin_url}"
        mv -f "${input_iso}.part" "${input_iso}"
    fi
    # Fedora's GPG-signed CHECKSUM file must list the same SHA256 as the pin.
    if [[ -n "${pin_checksum:-}" ]]; then
        release=${pin_name%%-*}
        # Fedora's release key, wherever fedora-gpg-keys puts it.
        key=$(rpm -ql fedora-gpg-keys 2>/dev/null | grep -E "RPM-GPG-KEY-fedora-${release}-(primary|x86_64)\$" | head -n 1)
        if [[ -n "${key}" && -f "${key}" ]] && command -v gpgv >/dev/null && command -v gpg >/dev/null; then
            sums="${repo_dir}/out/$(basename "${pin_checksum}")"
            curl --fail --location --retry 3 -s -o "${sums}" "${pin_checksum}"
            gpg --dearmor < "${key}" > "${sums}.key"
            if ! gpgv --keyring "${sums}.key" "${sums}" 2>/dev/null; then
                err "the GPG signature on $(basename "${sums}") does not check out with ${key}"
                exit 1
            fi
            if ! grep -qE "^SHA256 \($(basename "${pin_url}")\) = ${pin_sha}\$" "${sums}"; then
                err "Fedora's signed CHECKSUM file does not list ${pin_sha} for $(basename "${pin_url}")"
                exit 1
            fi
            printf "Fedora's signed CHECKSUM file confirms %s\n" "${pin_sha}"
            rm -f "${sums}.key"
        else
            if [[ -n "${PERIHELION_REQUIRE_SIGNED:-}" ]]; then
                err "cannot check Fedora's signed CHECKSUM (no gpgv, or no Fedora ${release} key in fedora-gpg-keys)"
                rpm -ql fedora-gpg-keys 2>/dev/null | grep -- "-${release}" >&2 || true
                exit 1
            fi
            printf 'note: no gpgv or Fedora %s key here; skipping the signed CHECKSUM check\n' "${release}"
        fi
    fi
fi
[[ -f "${input_iso}" ]] || { err "input ISO not found: ${input_iso}"; exit 1; }

# Only a pinned, unmodified Fedora installer is accepted.
printf 'Checking %s...\n' "$(basename "${input_iso}")"
input_sha=$(sha256sum "${input_iso}" | cut -d' ' -f1)
fedora_release=$(awk -v sha="${input_sha}" '$2 == sha { print $1; exit }' <<<"${pin_lines}")
if [[ -z "${fedora_release}" ]]; then
    err "${input_iso} (sha256 ${input_sha}) is not a pinned Fedora netinstall ISO; see ${pins}"
    exit 1
fi
printf 'Input is Fedora Everything netinstall %s\n' "${fedora_release}"
work_dir="$(mktemp -d)"
tmp_output=
trap 'rm -rf "${work_dir}"; [[ -z ${tmp_output} ]] || rm -f "${tmp_output}"' EXIT

if compgen -G "${repo_dir}/branding/wallpapers/*.png" >/dev/null; then
    printf 'Including the wallpapers in branding/wallpapers (personal-use artwork:\n'
    printf 'this ISO is for your own machines; do not publish it).\n'
else
    printf 'No wallpapers in branding/wallpapers (scripts/fetch-wallpapers.sh adds them); plain backgrounds.\n'
fi

ks_file="${work_dir}/perihelion.ks"
"${repo_dir}/scripts/render-ks.sh" "${flavor}" "${ks_file}" >/dev/null

# The payload the installer copies into the new system. Only what the
# %post steps need: no Git history, no build output, no ISOs.
payload_dir="${work_dir}/perihelion"
rsync -a --delete \
    --exclude='.git/' --exclude='out/' --exclude='*.iso' \
    --exclude='.env' --exclude='.env.*' \
    "${repo_dir}/" "${payload_dir}/"

# Record exactly which Perihelion commit this ISO was built from; the
# installed system keeps it in /usr/share/perihelion/release.
commit=${PERIHELION_COMMIT:-}
if [[ -z "${commit}" ]]; then
    commit=$(git -C "${repo_dir}" rev-parse --short HEAD 2>/dev/null || echo unknown)
    if [[ "${commit}" != unknown && -n "$(git -C "${repo_dir}" status --porcelain 2>/dev/null)" ]]; then
        commit="${commit}-modified"
    fi
fi
cat > "${payload_dir}/BUILD" <<EOF
PERIHELION_COMMIT=${commit}
PERIHELION_ISO_BUILT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
PERIHELION_FEDORA_ISO=${fedora_release}
EOF
printf 'Perihelion commit %s\n' "${commit}"

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
printf 'Created %s (%s, from Fedora %s)\n' "${output_iso}" "${flavor}" "${fedora_release}"
