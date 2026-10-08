#!/usr/bin/env bash
# Apply (or re-apply) the cinnamon-screensaver `Gib` -> `Gio` typo patch.
#
# The target is owned by the cinnamon-screensaver package, so it is diverted:
# dpkg then installs future upstream versions to authClient.py.distrib and
# leaves our patched copy at authClient.py alone. If upstream ever fixes the
# typo, re-running this script drops the diversion and restores their file.
#
# Idempotent: safe to run repeatedly, and safe to run after an `apt upgrade`.
#
# Requires sudo.
#
# Usage:  patches/apply-cinnamon-screensaver-gib-patch.sh [--check|--revert]

set -euo pipefail

PKG="cinnamon-screensaver"
PKG_ROOT="/usr/share/cinnamon-screensaver"
TARGET="$PKG_ROOT/pamhelper/authClient.py"
DISTRIB="$TARGET.distrib"
PATCH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/cinnamon-screensaver-gib-typo.patch"

log()  { printf '%s\n' "$*"; }
fail() { printf 'error: %s\n' "$*" >&2; exit 1; }

has_bug() { grep -qF 'Gib.IOErrorEnum' "$1" 2>/dev/null; }
# Here-string, not a pipe: `dpkg-divert --list | grep -q` dies of SIGPIPE (141)
# under `set -o pipefail`, which would read as "not diverted".
is_diverted() { grep -qF "diversion of $TARGET" <<< "$(dpkg-divert --list 2>/dev/null)"; }

# Unload: drop the diversion. `dpkg-divert --remove --rename` refuses to
# overwrite an existing differing file, so hand $TARGET back in two steps.
unload_patch() {
    if is_diverted; then
        # --no-rename explicit: dpkg 1.20.x flips the default to --rename.
        sudo dpkg-divert --remove --no-rename --package "$PKG" "$TARGET" \
            || fail "could not remove diversion for $TARGET"
        log "removed diversion for $TARGET"
    fi
}

# Reload: take the packaged file from the divert path. Plain cp keeps the
# destination inode, so root:root and mode survive.
reload_packaged() {
    if [ -f "$DISTRIB" ]; then
        sudo cp "$DISTRIB" "$TARGET" || fail "could not restore $TARGET from $DISTRIB"
        sudo rm -f "$DISTRIB"
        log "restored $TARGET from $DISTRIB"
    fi
}

# Verify by exercising the actual failure path: drive message_to_child() with an
# in_pipe whose flush() raises a non-cancelled GLib.Error. Unpatched, the
# handler raises NameError and this fails.
verify() {
    # compile() rather than py_compile: __pycache__ is root-owned and the check
    # must not try to write bytecode into the package directory.
    python3 -c 'import sys; compile(open(sys.argv[1]).read(), sys.argv[1], "exec")' "$TARGET" \
        || fail "patched file does not compile"
    GI_TYPELIB_PATH=/usr/libexec/cinnamon-screensaver/girepository-1.0 \
    LD_LIBRARY_PATH=/usr/libexec/cinnamon-screensaver \
    python3 - "$TARGET" <<'PY' || fail "verification failed"
import importlib.util, os, sys
target = sys.argv[1]
sys.path.insert(0, "/usr/share/cinnamon-screensaver")
os.chdir("/usr/share/cinnamon-screensaver")
import gi
gi.require_version('Gtk', '3.0')
gi.require_version('GdkX11', '3.0')
gi.require_version('CScreensaver', '1.0')
from gi.repository import Gio, GLib
spec = importlib.util.spec_from_file_location("authClient_under_test", target)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

class BrokenPipe:
    def write_bytes(self, data):
        return 1
    def flush(self, cancellable):
        raise GLib.Error.new_literal(Gio.io_error_quark(),
                                    Gio.IOErrorEnum.BROKEN_PIPE,
                                    "stub broken pipe")

client = mod.AuthClient()
client.initialized = True
client.cancellable = Gio.Cancellable()
client.in_pipe = BrokenPipe()

try:
    client.message_to_child("hunter2\n")
except Exception as e:
    print("FAIL: %s escaped message_to_child: %s" % (type(e).__name__, e))
    sys.exit(1)
print("verified: flush() error handled, no NameError")
PY
}

report() {
    if is_diverted && [ -f "$DISTRIB" ] && ! has_bug "$DISTRIB"; then
        log "UPSTREAM-FIXED  $TARGET (diverted copy has no typo; run without --check to revert)"
    elif is_diverted && ! has_bug "$TARGET"; then
        log "PATCHED         $TARGET"
    elif ! has_bug "$TARGET"; then
        log "CLEAN           $TARGET (upstream file, no diversion, nothing to do)"
    else
        log "UNPATCHED       $TARGET"
    fi
}

check_only=0
revert=0
for arg in "$@"; do
    case "$arg" in
        --check)  check_only=1 ;;
        --revert) revert=1 ;;
        -h|--help) sed -n '2,14p' "${BASH_SOURCE[0]}"; exit 0 ;;
        *) fail "unknown argument: $arg" ;;
    esac
done

[ -f "$TARGET" ] || fail "target not found at $TARGET (is $PKG installed?)"
[ -f "$PATCH" ] || fail "patch not found at $PATCH"

if [ "$check_only" -eq 1 ]; then
    report
    exit 0
fi

if [ "$revert" -eq 1 ]; then
    unload_patch
    reload_packaged
    report
    exit 0
fi

# Upstream fixed it: drop our copy and take theirs back.
if is_diverted && [ -f "$DISTRIB" ] && ! has_bug "$DISTRIB"; then
    log "upstream $PKG no longer has the typo -- reverting to the packaged file"
    unload_patch
    reload_packaged
    report
    exit 0
fi

if ! has_bug "$TARGET"; then
    log "already patched, nothing to do"
    verify
    log "verification passed"
    exit 0
fi

# Load: divert first, so apt installs future versions to $DISTRIB and leaves
# ours alone. dpkg-divert refuses to rename a file the diverting package owns
# ("Ignoring request to rename..."), so the pristine copy is made here.
if ! is_diverted; then
    sudo dpkg-divert --add --rename --package "$PKG" "$TARGET" \
        || fail "could not add diversion"
    log "diverted $TARGET -> $DISTRIB"
    reload_packaged
fi
if [ ! -f "$DISTRIB" ]; then
    sudo cp -a "$TARGET" "$DISTRIB"
    log "saved pristine copy -> $DISTRIB"
fi

PATCH_ROOT="$(mktemp -d)"
trap 'rm -rf "$PATCH_ROOT"' EXIT
awk '/^--- a\//{f=1} f' "$PATCH" > "$PATCH_ROOT/change.diff"
[ -s "$PATCH_ROOT/change.diff" ] || fail "could not extract diff hunks from $PATCH"

sudo patch -p1 -d "$PKG_ROOT" --no-backup-if-mismatch < "$PATCH_ROOT/change.diff" \
    || fail "patch failed (upstream file may have changed; regenerate the diff)"

if has_bug "$TARGET"; then
    fail "patch reported success but the typo is still present in $TARGET"
fi

verify
log "patched $TARGET"
log "verification passed"
log "takes effect for the next screensaver activation (no service restart needed)"