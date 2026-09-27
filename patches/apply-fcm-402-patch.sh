#!/usr/bin/env bash
# Apply (or re-apply) the fcm 402 -> QUOTA classifier patch.
#
# Idempotent: safe to run repeatedly, including after
# `npm install -g free-coding-models`, which silently reverts in-place
# edits to globally installed packages.
#
# Requires sudo: the target lives under a root-owned global npm prefix.
#
# Usage:  patches/apply-fcm-402-patch.sh [--check|--revert]

set -euo pipefail

PKG_DIR="/usr/local/lib/node_modules/free-coding-models"
TARGET_REL="src/core/router-v2/failure-classifier.js"
TARGET="$PKG_DIR/$TARGET_REL"
PATCH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/fcm-402-to-quota.patch"
BACKUP="$TARGET.orig"
MARKER="[402, FAILURE_KINDS.QUOTA]"

log()  { printf '%s\n' "$*"; }
fail() { printf 'error: %s\n' "$*" >&2; exit 1; }

is_patched() { grep -qF "$MARKER" "$TARGET" 2>/dev/null; }

check_only=0
revert=0
for arg in "$@"; do
  case "$arg" in
    --check)  check_only=1 ;;
    --revert) revert=1 ;;
    -h|--help) sed -n '2,12p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) fail "unknown argument: $arg" ;;
  esac
done

[ -d "$PKG_DIR" ] || fail "package not found at $PKG_DIR (is free-coding-models installed globally?)"
[ -f "$PATCH" ]   || fail "patch not found at $PATCH"

if [ "$revert" -eq 1 ]; then
  [ -f "$BACKUP" ] || fail "no backup at $BACKUP; nothing to revert to"
  sudo cp "$BACKUP" "$TARGET"
  log "reverted $TARGET from $BACKUP"
  log "restart the fcm daemon for it to take effect"
  exit 0
fi

if [ "$check_only" -eq 1 ]; then
  if is_patched; then log "PATCHED   $TARGET"; else log "UNPATCHED $TARGET"; fi
  exit 0
fi

if is_patched; then
  log "already patched, nothing to do"
  log "restart the fcm daemon for it to take effect"
  exit 0
fi

# Keep the pristine original exactly once, so --revert always has a target.
if [ ! -f "$BACKUP" ]; then
  sudo cp "$TARGET" "$BACKUP"
  log "saved pristine backup -> $BACKUP"
fi

# The patch is stored as a plain unified diff with a prose preamble, so feed
# only the hunks to `patch` and run from the package root.
PATCH_ROOT="$(mktemp -d)"
trap 'rm -rf "$PATCH_ROOT"' EXIT
awk '/^--- a\//{f=1} f' "$PATCH" > "$PATCH_ROOT/change.diff"
[ -s "$PATCH_ROOT/change.diff" ] || fail "could not extract diff hunks from $PATCH"

sudo patch -p1 -d "$PKG_DIR" --no-backup-if-mismatch < "$PATCH_ROOT/change.diff" \
  || fail "patch failed to apply (upstream file may have changed; regenerate the diff)"

is_patched || fail "patch reported success but $MARKER is absent from the target"

# Prove the file still parses as ESM and the map really resolves 402 -> QUOTA.
sudo node --input-type=module -e "
  import { classifyStatus, FAILURE_KINDS } from '$TARGET';
  const got = classifyStatus(402);
  const want = FAILURE_KINDS.QUOTA;
  if (got !== want) {
    console.error('FAIL: classifyStatus(402) = ' + got + ', expected ' + want);
    process.exit(1);
  }
  console.log('verified: classifyStatus(402) -> ' + got);
"

log "patched $TARGET"
log "restart the fcm daemon for it to take effect"
