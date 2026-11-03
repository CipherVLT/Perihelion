#!/usr/bin/env bash
# Build nwg-drawer (the Super+A app drawer) and stage it into
# system_files/common, so the ISO ships a ready binary.
#
# Fedora retired its nwg-drawer package after Fedora 43 and Terra does not
# carry it, so it is built here from a pinned upstream release. It is a
# Go + GTK3 program that takes several minutes to compile, which is why this
# runs once in CI instead of on every install.
#
# Run on Fedora (CI runs it in the fedora:45 container before the rehearsal).
#   scripts/build-nwg-drawer.sh
set -euo pipefail

version=v0.7.5
commit=6f2accf085a34cc7d82eb620f023639c87ec12bb

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dest="${repo_dir}/system_files/common"
work=$(mktemp -d)
trap 'rm -rf "${work}"' EXIT

dnf5 install -y --setopt=install_weak_deps=False \
    git-core golang gtk3-devel gtk-layer-shell-devel

git clone -q --depth 1 --branch "${version}" https://github.com/nwg-piotr/nwg-drawer "${work}/src"
got=$(git -C "${work}/src" rev-parse HEAD)
[[ "${got}" == "${commit}" ]] || { echo "nwg-drawer ${version} is ${got}, expected ${commit}" >&2; exit 1; }

# go.sum pins every module; -mod=readonly refuses anything not listed there,
# and GOTOOLCHAIN=local stops Go from downloading a different compiler.
(
    cd "${work}/src"
    export GOTOOLCHAIN=local GOFLAGS=-mod=readonly CGO_ENABLED=1
    go build -trimpath -ldflags='-s -w' -o "${work}/nwg-drawer" .
)

install -Dm755 "${work}/nwg-drawer" "${dest}/usr/bin/nwg-drawer"
rm -rf "${dest}/usr/share/nwg-drawer"
install -d "${dest}/usr/share/nwg-drawer"
cp -R "${work}/src/desktop-directories" "${work}/src/img" "${dest}/usr/share/nwg-drawer/"
install -Dm644 "${work}/src/drawer.css" "${dest}/usr/share/nwg-drawer/drawer.css"
install -Dm644 "${work}/src/LICENSE" "${dest}/usr/share/licenses/nwg-drawer/LICENSE"
install -Dm644 "${work}/src/LICENSE-gotk4" "${dest}/usr/share/licenses/nwg-drawer/LICENSE-gotk4"

"${dest}/usr/bin/nwg-drawer" -h 2>&1 | head -3 || true
echo "nwg-drawer ${version} staged in system_files/common"
