#!/usr/bin/env bash
# Compile Event Horizon (the Zig rewrite) and stage it under /ehroot.
# The final image copies /ehroot and does not keep this toolchain.
#
# Upstream: https://github.com/Event-Horizon-desktop-environment/Event-Horizon
# (MIT). The earlier C++/Meson repository (Event-Horizon-Shell) is gone; the
# Zig tree replaced it. event-horizon.ref pins the upstream commit.
#
# Upstream's build.sh auto-detects the build CPU's x86-64 level, which would
# tune the binaries for a GitHub runner. This script pins x86-64-v2 instead
# (every x86-64 CPU since ~2009), so the image runs on all supported hardware.
set -eoux pipefail
# Show the failing line on the GitHub run page (as an annotation).
trap 'echo "::error title=build-event-horizon.sh::line ${LINENO}: ${BASH_COMMAND}"' ERR

EH_REPO="${EH_REPO:-https://github.com/Event-Horizon-desktop-environment/Event-Horizon.git}"
EH_REF="$(tr -d '[:space:]' < "${PERIHELION_SRC}/build/refs/event-horizon.ref")"
EH_CPU=x86_64_v2
# ReleaseFast like upstream's build.sh. ReleaseSafe also builds (see the
# _FORTIFY_SOURCE note below) and is handy for chasing crashes.
EH_OPTIMIZE=ReleaseFast

# Zig toolchain: the release tarball from ziglang.org, verified against the
# Zig Software Foundation's minisign key before use.
ZIG_VERSION=0.16.0
ZIG_PUBKEY='RWSGOq2NVecA2UPNdBUZykf1CCb147pkmdtYxgb3Ti+JO/wCYvhbAb/U'

dnf5 install -y \
    git \
    curl \
    xz \
    minisign \
    pkgconf-pkg-config \
    wayland-devel \
    wayland-protocols-devel \
    libxkbcommon-devel \
    cairo-devel \
    pango-devel \
    librsvg2-devel \
    libwebp-devel \
    pipewire-devel

zig_dir=/tmp/zig
mkdir -p "${zig_dir}"
zig_ok=0
for name in "zig-x86_64-linux-${ZIG_VERSION}" "zig-linux-x86_64-${ZIG_VERSION}"; do
    url="https://ziglang.org/download/${ZIG_VERSION}/${name}.tar.xz"
    if curl --fail --location --silent --show-error --retry 3 -o "${zig_dir}/zig.tar.xz" "${url}" &&
        curl --fail --location --silent --show-error --retry 3 -o "${zig_dir}/zig.tar.xz.minisig" "${url}.minisig"; then
        zig_ok=1
        break
    fi
done
(( zig_ok )) || { echo "could not download Zig ${ZIG_VERSION}" >&2; exit 1; }
minisign -V -P "${ZIG_PUBKEY}" -m "${zig_dir}/zig.tar.xz" -x "${zig_dir}/zig.tar.xz.minisig"
sha256sum "${zig_dir}/zig.tar.xz"
tar -xJf "${zig_dir}/zig.tar.xz" -C "${zig_dir}" --strip-components=1
ZIG="${zig_dir}/zig"
"${ZIG}" version
export ZIG_GLOBAL_CACHE_DIR=/tmp/zig-global-cache ZIG_LOCAL_CACHE_DIR=/tmp/zig-local-cache

src=/eh-src
rm -rf "${src}"
mkdir -p "${src}"
git -C "${src}" init
git -C "${src}" remote add origin "${EH_REPO}"
git -C "${src}" fetch --depth 1 origin "${EH_REF}"
git -C "${src}" checkout --detach FETCH_HEAD
git -C "${src}" submodule update --init --recursive --depth 1

cd "${src}"
# Safe builds turn on glibc's _FORTIFY_SOURCE wrappers, and Zig's C
# translation cannot handle some of them (gethostname: "expected c_int,
# found bool"). Undefine it inside every @cImport for non-fast builds; Zig's
# own safety checks, the reason for the safe build, are unaffected.
if [[ "${EH_OPTIMIZE}" != ReleaseFast ]]; then
    grep -rl --include='*.zig' '@cImport({' src | while read -r f; do
        sed -i 's/@cImport({/@cImport({ @cUndef("_FORTIFY_SOURCE");/' "${f}"
    done
    grep -rl --include='*.zig' '@cImport(@cInclude(' src | while read -r f; do
        sed -i -E 's/@cImport\(@cInclude\(("[^"]+")\)\)/@cImport({ @cUndef("_FORTIFY_SOURCE"); @cInclude(\1); })/' "${f}"
    done
fi

# Local patch: double free in the dock's audio poll. With pactl installed
# (pulseaudio-utils ships it), live_audio.query() moves the four `pactl list` outputs
# into the returned Queried (q.sinks_text = sinks_text, ...) but also frees
# them on return with `defer`. Queried.deinit frees them again on the next
# poll, so horizon-dock aborts every few seconds ("double free or corruption")
# and the parsed device names point at freed memory meanwhile. Drop the four
# defers: Queried owns the buffers. Fails the build if upstream changes the
# code, so the patch is re-checked instead of silently skipped.
python3 - <<'PY'
import pathlib, sys
p = pathlib.Path("src/desktop_shell/controlcenter/live_audio.zig")
s = p.read_text()
for name in ("sinks_text", "sources_text", "in_text", "out_text"):
    target = f"    defer if ({name}) |s| alloc.free(s);\n"
    owner = f"    q.{name} = {name};\n"
    if s.count(target) != 1 or s.count(owner) != 1:
        sys.exit(f"horizon-forge audio patch: expected one '{target.strip()}' and one '{owner.strip()}' in {p}")
    s = s.replace(target, f"    // horizon-forge: owned by Queried (freed in deinit), no defer free\n")
p.write_text(s)
print("horizon-forge: patched double free in live_audio.query")
PY

# Local patch: the network/Bluetooth card ("pear") and the control-center
# panel open as overlay layers with EXCLUSIVE keyboard interactivity. While an
# exclusive layer is mapped, Hyprland routes the pointer only to it, so
# clicks on the dock (which would close the card) and everywhere else go
# nowhere and the desktop looks frozen until Esc. The dock's other cards only
# ask for exclusive focus when they need typing. Use ON_DEMAND (2) for these
# two: keyboard when clicked into, the rest of the screen stays usable.
python3 - <<'PY'
import pathlib, sys
want = {
    "src/desktop_shell/pear/host.zig": 1,
    "src/desktop_shell/controlcenter/host.zig": 2,
}
target = "self.surface.setKeyboardInteractivity(1);"
for path, n in want.items():
    p = pathlib.Path(path)
    s = p.read_text()
    if s.count(target) != n:
        sys.exit(f"horizon-forge popup patch: expected {n} x '{target}' in {p}, found {s.count(target)}")
    p.write_text(s.replace(target, "self.surface.setKeyboardInteractivity(2); // horizon-forge: on-demand, not exclusive"))
print("horizon-forge: pear + control-center popups use on-demand keyboard focus")
PY

# Local patch: a component whose Wayland connection died (the compositor
# disconnected it, e.g. for a protocol error) kept running with no surfaces:
# the dock vanished for good because the supervisor still saw it alive, and
# the reason was lost with stderr. On a fatal display error, log the errno and
# the offending interface#id to ~/EH-logs, then exit so the supervisor
# respawns it. Upstream's polkit agent already does this for itself.
python3 - <<'PY'
import pathlib, sys
p = pathlib.Path("src/wl/connection.zig")
s = p.read_text()
old = """    pub fn flush(self: *Connection) bool {
        if (self.display) |d| return wl.wl_display_flush(d) >= 0;
        return false;
    }
"""
new = """    pub fn flush(self: *Connection) bool {
        if (self.display) |d| {
            if (wl.wl_display_flush(d) >= 0) return true;
            // horizon-forge: fatal display error -> log why, exit for respawn.
            const code = wl.wl_display_get_error(d);
            if (code != 0) {
                var iface: [*c]const wl.struct_wl_interface = null;
                var id: u32 = 0;
                const perr = wl.wl_display_get_protocol_error(d, &iface, &id);
                const name: []const u8 = if (iface != null and iface.*.name != null)
                    std.mem.span(@as([*:0]const u8, @ptrCast(iface.*.name)))
                else
                    "?";
                @import("../logz.zig").err(
                    "display connection lost: errno={d} protocol_error={d} on {s}#{d}; exiting for supervisor respawn",
                    .{ code, perr, name, id },
                );
                std.process.exit(1);
            }
            return false;
        }
        return false;
    }
"""
if s.count(old) != 1:
    sys.exit(f"horizon-forge disconnect patch: Connection.flush changed upstream in {p}")
p.write_text(s.replace(old, new))
print("horizon-forge: components log and exit on a lost Wayland connection")
PY

# Local patch: Event Horizon reads the keyboard itself (evdev, under
# Hyprland) and runs its own capture for Super+Shift+S (region), Print (the
# monitor under the pointer) and Alt+Print (every monitor). That capture has
# no editor or save dialog yet ("--preview ... no GUI for it yet"), and it
# races any Hyprland binding for the same keys. Point the three hotkeys at
# /usr/bin/horizon-screenshot (slurp + grim + Satty: annotate, copy, save,
# save as). `eh-ipc screenshot` and `horizon --eh-screenshot` are unchanged.
python3 - <<'PY'
import pathlib, sys
p = pathlib.Path("src/bootstrap/runner.zig")
s = p.read_text()
calls = {
    'spawnScreenshot(sh.gpa, &.{ "--select", "--preview" })': 'spawnHorizonScreenshot("region")',
    'spawnScreenshot(sh.gpa, &.{"--preview"})': 'spawnHorizonScreenshot("screen")',
    'spawnScreenshot(sh.gpa, &.{ "--all-monitors", "--preview" })': 'spawnHorizonScreenshot("full")',
}
for old, new in calls.items():
    if s.count(old) != 1:
        sys.exit(f"horizon-forge screenshot patch: expected one '{old}' in {p}")
    s = s.replace(old, new)
anchor = "fn spawnScreenshot(alloc: std.mem.Allocator, args: []const []const u8) i64 {\n"
if s.count(anchor) != 1:
    sys.exit(f"horizon-forge screenshot patch: spawnScreenshot signature changed in {p}")
helper = """/// horizon-forge: the screenshot hotkeys open /usr/bin/horizon-screenshot
/// (slurp + grim + Satty: annotate, copy, save, save as). Detached in its
/// own session like spawnScreenshot. Returns the child pid, or a negative errno.
fn spawnHorizonScreenshot(mode: [*:0]const u8) i64 {
    const bin: [*:0]const u8 = "/usr/bin/horizon-screenshot";
    const argv = [_][*c]u8{ @constCast(bin), @constCast(mode), null };
    if (builtin.is_test) return 0;
    var pid: std.posix.pid_t = 0;
    var attr: spawn_c.posix_spawnattr_t = undefined;
    if (spawn_c.posix_spawnattr_init(&attr) != 0) return -@as(i64, @intFromEnum(linux.E.NOMEM));
    defer _ = spawn_c.posix_spawnattr_destroy(&attr);
    if (spawn_c.posix_spawnattr_setflags(&attr, spawn_c.POSIX_SPAWN_SETSID) != 0) return -@as(i64, @intFromEnum(linux.E.INVAL));
    const rc = spawn_c.posix_spawnp(&pid, bin, null, &attr, &argv, std.c.environ);
    if (rc != 0) return -@as(i64, rc);
    return pid;
}

"""
s = s.replace(anchor, helper + anchor)
p.write_text(s)
print("horizon-forge: screenshot hotkeys open horizon-screenshot (Satty)")
PY

# Local patch: Wi-Fi networks never listed unless Wi-Fi was already
# connected. live_network.query() skips every NetworkManager device that is
# not activated, the access-point list included, so on Ethernet (or with
# nothing connected) the dock's network card had no network to join. List
# the access points of an idle Wi-Fi adapter too. And the settings app's
# "Scan for networks" button has no action yet: open nmtui's network picker
# in kitty until Event Horizon builds that page.
python3 - <<'PY'
import pathlib, sys
p = pathlib.Path("src/desktop_shell/controlcenter/live_network.zig")
s = p.read_text()
skip = "        if (dstate != NM_DEVICE_STATE_ACTIVATED) continue;\n"
fn_anchor = "pub fn query(alloc: std.mem.Allocator) ?Queried {\n"
if s.count(skip) != 1 or s.count(fn_anchor) != 1:
    sys.exit(f"horizon-forge wifi patch: query() changed upstream in {p}")
s = s.replace(skip, """        if (dstate != NM_DEVICE_STATE_ACTIVATED) {
            // horizon-forge: an idle Wi-Fi adapter still lists nearby networks.
            if (dtype == NM_DEVICE_TYPE_WIFI) appendIdleWifiAps(&conn, alloc, &q, d.object_path);
            continue;
        }
""")
helper = """/// horizon-forge: nearby networks for a Wi-Fi adapter that isn't connected,
/// so the card has something to join when Wi-Fi is idle.
fn appendIdleWifiAps(conn: *conn_mod.Conn, alloc: std.mem.Allocator, q: *Queried, dev_path: []const u8) void {
    const aps = getPaths(conn, alloc, dev_path, wifi_iface, "GetAccessPoints") orelse return;
    defer {
        for (aps) |a| if (a == .object_path) alloc.free(a.object_path);
        alloc.free(aps);
    }
    for (aps) |a| {
        if (a != .object_path) continue;
        if (q.ap_list.items.len >= 8) break;
        var ssid_buf: [128]u8 = undefined;
        const ssid = apSsid(conn, alloc, a.object_path, &ssid_buf);
        if (ssid.len == 0) continue;
        const strength = getU32(conn, alloc, a.object_path, ap_iface, "Strength");
        const flags = getU32(conn, alloc, a.object_path, ap_iface, "Flags");
        const wpa = getU32(conn, alloc, a.object_path, ap_iface, "WpaFlags");
        const rsn = getU32(conn, alloc, a.object_path, ap_iface, "RsnFlags");
        q.ap_list.append(alloc, .{
            .ssid = alloc.dupe(u8, ssid) catch "",
            .strength = @intCast(@min(strength, 100)),
            .secured = (flags & 0x1) != 0 or wpa != 0 or rsn != 0,
            .active = false,
        }) catch {};
    }
}

"""
s = s.replace(fn_anchor, helper + fn_anchor)
p.write_text(s)

p = pathlib.Path("src/ux/settings2/window.zig")
s = p.read_text()
btn = """            .button => |label| {
                if (std.mem.eql(u8, label, "Test notification")) {"""
if s.count(btn) != 1:
    sys.exit(f"horizon-forge wifi patch: settings button handler changed upstream in {p}")
s = s.replace(btn, """            .button => |label| {
                // horizon-forge: no Wi-Fi page yet; open NetworkManager's picker.
                if (std.mem.eql(u8, label, "Scan for networks")) {
                    @import("../../services/autostart.zig").spawnDetached(self.io, &.{ "kitty", "--title", "Wi-Fi networks", "nmtui", "connect" }) catch |e| {
                        logz.log("settings: could not open nmtui: {s}", .{@errorName(e)});
                    };
                    return;
                }
                if (std.mem.eql(u8, label, "Test notification")) {""")
p.write_text(s)
print("horizon-forge: idle Wi-Fi lists networks; settings Scan opens nmtui")
PY

# Local patch: the wallpaper gallery only ever showed the first page of
# thumbnails. Its decode worker sleeps on a condition variable once its queue
# is empty, and request() queued new work without signalling it, so every
# thumbnail asked for after the first batch (page 2 onward) waited forever.
python3 - <<'PY'
import pathlib, sys
for rel in ("src/ux/settings2/wallpaper_thumbs.zig", "src/ux/settings/wallpaper_thumbs.zig"):
    p = pathlib.Path(rel)
    if not p.exists():
        continue
    s = p.read_text()
    old = """        self.requested.put(owned, {}) catch {
            self.alloc.free(owned);
            self.pend_len -= 1;
            return false;
        };
        return true;
    }"""
    if s.count(old) != 1:
        sys.exit(f"horizon-forge thumbnail patch: request() changed upstream in {p}")
    s = s.replace(old, """        self.requested.put(owned, {}) catch {
            self.alloc.free(owned);
            self.pend_len -= 1;
            return false;
        };
        // horizon-forge: wake the worker, which may be idle on the condvar.
        _ = c.pthread_cond_signal(&self.cond);
        return true;
    }""")
    p.write_text(s)
    print(f"horizon-forge: wallpaper thumbnail worker woken on new requests ({rel})")
PY

# Local patch: the dock's Trash button did nothing. Its slot has no click or
# menu action in the dock (only the taskbar's trash widget has one). Left
# click opens the Trash (Strata), right click asks to empty it; both go
# through /usr/libexec/perihelion-trash.
python3 - <<'PY'
import pathlib, sys
p = pathlib.Path("src/bin/dock.zig")
s = p.read_text()
click = """                    .overview => {
                        self.showOverview();
                        return;
                    },
"""
menu = """            .tray => blk: {
                self.buildTrayMenu(s) catch |e| {"""
if s.count(click) != 1 or s.count(menu) != 1:
    sys.exit(f"horizon-forge trash patch: dock click/menu dispatch changed upstream in {p}")
s = s.replace(click, """                    .trash => {
                        // horizon-forge: open the Trash.
                        if (!app_launch.launchExec(self.app.gpa, self.app.io, "/usr/libexec/perihelion-trash open")) {
                            logz.err("activate: could not open the Trash", .{});
                        }
                        return;
                    },
""" + click)
s = s.replace(menu, """            .trash => blk: {
                // horizon-forge: right click asks to empty the Trash.
                _ = app_launch.launchExec(self.app.gpa, self.app.io, "/usr/libexec/perihelion-trash empty");
                break :blk false;
            },
""" + menu)
p.write_text(s)
print("horizon-forge: dock Trash button opens / empties the Trash")
PY

# Compiler errors as GitHub annotations, so they show on the run page.
if ! "${ZIG}" build "-Doptimize=${EH_OPTIMIZE}" "-Dcpu=${EH_CPU}" 2>/tmp/zig-build.err; then
    cat /tmp/zig-build.err >&2
    grep -E 'error:|note:' /tmp/zig-build.err | head -n 12 | sed 's/^/::error title=zig build::/'
    exit 1
fi

# Install exactly the binaries upstream's build.sh installs, read from it so
# a new component is picked up automatically. The supervisor (horizon)
# starts its components from its own directory, so they all go in /usr/bin.
mapfile -t binaries < <(awk '/^INSTALL_BINARIES=\(/{f=1; next} f && /^\)/{exit} f {gsub(/^[ \t]+|[ \t]+$/, ""); if ($0 != "") print}' build.sh)
(( ${#binaries[@]} > 0 )) || { echo "could not read INSTALL_BINARIES from upstream build.sh" >&2; exit 1; }
rm -rf /ehroot
install -d /ehroot/usr/bin /ehroot/usr/share
for name in "${binaries[@]}"; do
    install -m755 "zig-out/bin/${name}" "/ehroot/usr/bin/${name}"
done
"${ZIG}" build install-icons --prefix /ehroot/usr/share

test -x /ehroot/usr/bin/horizon
echo "Staged Event Horizon ${EH_REF}: ${binaries[*]}"
