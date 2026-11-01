# Hyprland flavor: install-time COPR for Hyprland 0.56+. The installed
# system enables the same COPR with dnf (build/flavor-hyprland.sh) so
# Hyprland keeps updating.
repo --name="copr-nett00n-hyprland-install" --baseurl="https://download.copr.fedorainfracloud.org/results/nett00n/hyprland/fedora-$releasever-$basearch/"
# PACKAGES: base gaming event-horizon hyprland
