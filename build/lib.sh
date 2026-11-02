# Shared helpers for the Perihelion %post scripts. Sourced, not executed.
# shellcheck shell=bash

: "${PERIHELION_SRC:?PERIHELION_SRC must point at the copied repository}"

log() { printf '[perihelion] %s\n' "$*"; }
die() { printf '[perihelion] ERROR: %s\n' "$*" >&2; exit 1; }

# Copy a flavor's system_files tree onto /.
# Never `cp -a`: it also copies SELinux labels (security.selinux xattrs),
# which stamps the installer's temporary-file label onto /etc, /usr/bin and
# friends; with SELinux enforcing, journald, logind and the login screen
# then fail at boot. Copy content and modes only, then let the policy label
# everything (relabel_system at the end of %post).
apply_system_files() {
    local tree="${PERIHELION_SRC}/system_files/$1"
    [[ -d "${tree}" ]] || die "missing system_files/$1"
    cp -R --preserve=mode,timestamps --no-preserve=ownership,context,xattr "${tree}/." /
}

# Give everything Perihelion wrote its correct SELinux label. Runs last in
# %post; also schedules a full relabel on first boot as a safety net.
relabel_system() {
    if command -v restorecon >/dev/null 2>&1; then
        log "selinux: restoring labels"
        restorecon -RF /etc /usr /var/lib /var/tmp /home /root 2>&1 | tail -n 5 || true
    fi
    if [[ -f /etc/selinux/config ]] && ! grep -q '^SELINUX=disabled' /etc/selinux/config; then
        touch /.autorelabel
        log "selinux: full relabel scheduled for first boot (one extra reboot)"
    fi
}

# Regular accounts Anaconda created (UID 1000-59999 with a /home directory).
regular_users() {
    awk -F: '$3 >= 1000 && $3 < 60000 && $6 ~ "^/home/" && $7 !~ /(nologin|false)$/ { print $1 }' /etc/passwd
}

# seed_user_file SOURCE RELATIVE_PATH
# Anaconda creates the user before %post runs, so files added to /etc/skel
# here never reach that account. Install into /etc/skel (future accounts)
# and into each existing account, without replacing a file that exists.
seed_user_file() {
    local src=$1 rel=$2 user home group
    install -Dm644 "${src}" "/etc/skel/${rel}"
    while read -r user; do
        [[ -n "${user}" ]] || continue
        home=$(getent passwd "${user}" | cut -d: -f6)
        group=$(id -gn "${user}")
        [[ -e "${home}/${rel}" ]] && continue
        install -d -o "${user}" -g "${group}" "$(dirname "${home}/${rel}")"
        # install -d only sets owner on the last directory; fix the parents
        # it may have created under the home folder.
        local d
        d=$(dirname "${rel}")
        while [[ "${d}" != . && "${d}" != / ]]; do
            chown "${user}:${group}" "${home}/${d}"
            d=$(dirname "${d}")
        done
        install -m644 -o "${user}" -g "${group}" "${src}" "${home}/${rel}"
    done < <(regular_users)
}

# Retry a command a few times (mirrors and ziglang.org time out now and then).
retry() {
    local try
    for try in 1 2 3; do
        "$@" && return 0
        log "attempt ${try} failed: $*"
        sleep $((try * 15))
    done
    return 1
}
