#!/usr/bin/env bash
# sync-from-home.sh - pull live config changes from $HOME into the repo

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_HOME="$SCRIPT_DIR/home"

echo "🔄 Syncing tracked files from $HOME to $REPO_HOME"

# Build the allowlist from files already tracked in the repo (NUL-safe)
mapfile -d '' -t tracked < <(cd "$REPO_HOME" && find . -type f -print0)

if [[ ${#tracked[@]} -eq 0 ]]; then
  echo "⚠️  No files found in $REPO_HOME" >&2
  exit 1
fi

# -aL: archive mode + dereference symlinks (copy content, not link structure)
# --files-from --from0: restrict transfer to repo-tracked paths only
if ! rsync -aL --from0 --files-from=<(printf '%s\0' "${tracked[@]}") "$HOME/" "$REPO_HOME/"; then
  echo "⚠️  rsync reported issues - some tracked files may be missing from $HOME" >&2
fi

echo "✅ Sync complete!"
echo "💡 Review changes with: git diff && git add -p"