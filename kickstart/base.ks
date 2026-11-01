# Perihelion base kickstart. Not used on its own: scripts/render-ks.sh joins
# it with a flavor (kickstart/flavors/*.ks) and the package lists into one
# file per ISO.
#
# Disk, locale, keyboard, timezone, hostname and the user account stay in
# the Anaconda UI, so nothing here can erase a disk without the user
# reviewing it first.

network --bootproto=dhcp --activate
firstboot --disable
firewall --enabled
# SELinux stays at Fedora's default (enforcing).

# Packages come from the network (Fedora Everything netinstall ISO).
url --metalink="https://mirrors.fedoraproject.org/metalink?repo=fedora-$releasever&arch=$basearch"
repo --name="updates" --metalink="https://mirrors.fedoraproject.org/metalink?repo=updates-released-f$releasever&arch=$basearch" --install
repo --name="fedora-cisco-openh264" --metalink="https://mirrors.fedoraproject.org/metalink?repo=fedora-cisco-openh264-$releasever&arch=$basearch" --install
# Terra, for the install only. The installed system gets Terra's own repo
# file and signing keys from the terra-release package (packages/base.txt).
repo --name="terra-install" --baseurl="https://repos.fyralabs.com/terra$releasever"

bootloader --location=mbr
services --enabled=NetworkManager,firewalld,bluetooth,power-profiles-daemon,sddm
