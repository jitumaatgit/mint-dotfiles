#!/usr/bin/env bash
# Apply (or re-apply) the Chicago95 Cinnamon 6.x selector override.
#
# Cinnamon has no user stylesheet override, so these rules must live inside the
# theme's own stylesheet. This script keeps a versioned copy in the repo and
# reconciles the two. Idempotent: safe to run repeatedly, and safe to re-run
# after re-extracting the theme from upstream, which deletes any hand-edits.
#
# Usage:  patches/apply-cinnamon6-override.sh [--check|--revert|--status]
#
#   (no args)  sync the live stylesheet with the versioned payload
#   --check    exit 0 if in sync, 1 otherwise; never writes
#   --revert   remove the managed block, restoring upstream's stylesheet
#   --status   print the current state, always exit 0
#
# After changing the stylesheet, reload the shell without logging out:
#   gsettings set org.cinnamon.theme name 'Adapta-Nokto'
#   gsettings set org.cinnamon.theme name 'Chicago95'

set -euo pipefail

THEME_DIR="${CHICAGO95_THEME_DIR:-$HOME/.themes/Chicago95}"
STYLESHEET="$THEME_DIR/cinnamon/cinnamon.css"
PAYLOAD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/cinnamon6-override.css"

BEGIN_MARK="/* >>> cinnamon6-override BEGIN - managed, do not edit in place >>> */"
END_MARK="/* <<< cinnamon6-override END <<< */"

# The block appended by hand before this script existed. It has no sentinel, so
# the only way to retire it is to match a line unique to it. Deliberately not
# matched on the '#' rule, which the theme's own header also uses.
LEGACY_MARK="* Cinnamon 6.x menu applet"

log()  { printf '%s\n' "$*"; }
fail() { printf 'error: %s\n' "$*" >&2; exit 1; }

usage() { sed -n '3,16p' "${BASH_SOURCE[0]}" | sed 's/^#\{1,\} \{0,1\}//'; }

# Emits exactly the managed block's contents, markers excluded.
extract_block() {
  awk -v b="$BEGIN_MARK" -v e="$END_MARK" '
    index($0, b) { inside = 1; next }
    index($0, e) { inside = 0 }
    inside      { print }
  ' "$STYLESHEET"
}

# Emits the stylesheet with any managed block and any legacy block removed.
# The legacy block runs to end of file because it was appended last.
strip_all() {
  awk -v b="$BEGIN_MARK" -v e="$END_MARK" -v l="$LEGACY_MARK" '
    index($0, b) { skip = 1; next }
    index($0, e) { skip = 0; next }
    skip         { next }
    index($0, l) { exit }
    { print }
  ' "$STYLESHEET"
}

# Prints one of: upstream | legacy | managed-stale | managed-current
stylesheet_state() {
  local has_begin=0 has_end=0 legacy=0

  if grep -qF "$BEGIN_MARK" "$STYLESHEET" 2>/dev/null; then has_begin=1; fi
  if grep -qF "$END_MARK"   "$STYLESHEET" 2>/dev/null; then has_end=1; fi
  if grep -qF "$LEGACY_MARK" "$STYLESHEET" 2>/dev/null; then legacy=1; fi

  if [ "$has_begin" -ne "$has_end" ]; then
    fail "markers are unbalanced in $STYLESHEET (BEGIN=$has_begin END=$has_end); refusing to touch it"
  fi

  if [ "$has_begin" -eq 1 ]; then
    if extract_block | cmp -s - "$PAYLOAD"; then
      echo managed-current
    else
      echo managed-stale
    fi
  elif [ "$legacy" -eq 1 ]; then
    echo legacy
  else
    echo upstream
  fi
}

apply() {
  local state tmp
  state="$(stylesheet_state)"

  case "$state" in
    managed-current) log "already in sync with $PAYLOAD"; return 0 ;;
    managed-stale)   log "managed block is out of date; re-applying" ;;
    legacy)          log "retiring the hand-appended block from before this script existed" ;;
    upstream)        log "no override present; applying" ;;
  esac

  tmp="$(mktemp)"
  strip_all > "$tmp"

  # Exactly one blank line between upstream's last rule and the managed block.
  if [ -s "$tmp" ] && [ "$(tail -c1 "$tmp" | wc -l)" -eq 0 ]; then
    printf '\n' >> "$tmp"
  fi

  printf '%s\n' "$BEGIN_MARK"  >> "$tmp"
  cat "$PAYLOAD"               >> "$tmp"
  printf '%s\n' "$END_MARK"    >> "$tmp"

  cp "$STYLESHEET" "$STYLESHEET.bak-cinnamon6"
  mv "$tmp" "$STYLESHEET"

  # Trust nothing: confirm the block landed byte-identical.
  extract_block | cmp -s - "$PAYLOAD" || fail "applied block does not match the payload"
  grep -qF "$BEGIN_MARK" "$STYLESHEET" || fail "BEGIN marker missing after apply"
  grep -qF "$END_MARK"   "$STYLESHEET" || fail "END marker missing after apply"
  rm -f "$STYLESHEET.bak-cinnamon6"

  log "applied to $STYLESHEET"
  log "reload the shell: gsettings set org.cinnamon.theme name 'Adapta-Nokto' && \\"
  log "                gsettings set org.cinnamon.theme name 'Chicago95'"
}

check() {
  local state
  state="$(stylesheet_state)"
  case "$state" in
    managed-current) log "IN SYNC"; return 0 ;;
    managed-stale)   log "STALE";   return 1 ;;
    legacy)          log "LEGACY";  return 1 ;;
    upstream)        log "ABSENT";  return 1 ;;
  esac
}

revert() {
  local state tmp
  state="$(stylesheet_state)"

  case "$state" in
    upstream) log "already upstream; nothing to revert"; return 0 ;;
    legacy)   log "removing the hand-appended block" ;;
    *)        log "removing the managed block" ;;
  esac

  tmp="$(mktemp)"
  strip_all > "$tmp"
  cp "$STYLESHEET" "$STYLESHEET.bak-cinnamon6"
  mv "$tmp" "$STYLESHEET"

  # awk exits 0 whether or not it printed anything, so assert on the output.
  if [ -n "$(extract_block)" ]; then fail "block still present after revert"; fi
  rm -f "$STYLESHEET.bak-cinnamon6"

  log "reverted $STYLESHEET to upstream"
  log "reload the shell to see the change"
}

mode=apply
for arg in "$@"; do
  case "$arg" in
    --check)  mode=check  ;;
    --revert) mode=revert ;;
    --status) mode=status ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown argument: $arg (try --help)" ;;
  esac
done

[ -f "$PAYLOAD" ]    || fail "payload not found at $PAYLOAD"
[ -f "$STYLESHEET" ] || fail "stylesheet not found at $STYLESHEET (is Chicago95 installed? set CHICAGO95_THEME_DIR to point at it)"

case "$mode" in
  apply)  apply  ;;
  check)  check  ;;
  revert) revert ;;
  status) log "$(stylesheet_state)  $STYLESHEET" ;;
esac
