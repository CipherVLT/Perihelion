# Shared %post sections. scripts/render-ks.sh replaces @FLAVOR@.

# The ISO exposes this repository at /run/install/repo/perihelion. Copy it
# into the new system for the chroot steps; it is removed again at the end.
%post --nochroot --erroronfail --log=/mnt/sysimage/root/perihelion-copy.log
set -eu
rm -rf /mnt/sysimage/var/tmp/perihelion
cp -a /run/install/repo/perihelion /mnt/sysimage/var/tmp/perihelion
%end

%post --erroronfail --log=/root/perihelion-post.log
set -eu
export PERIHELION_SRC=/var/tmp/perihelion
export PERIHELION_FLAVOR=@FLAVOR@
bash "$PERIHELION_SRC/build/common-post.sh"
bash "$PERIHELION_SRC/build/flavor-@FLAVOR@.sh"
# Icon caches after everything that installs icons, then SELinux labels on
# everything %post wrote (see build/lib.sh).
bash -c 'source "$PERIHELION_SRC/build/lib.sh" && refresh_icon_caches && relabel_system'
rm -rf "$PERIHELION_SRC"
dnf5 clean all
%end
