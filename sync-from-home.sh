#!/usr/bin/env bash
# sync-from-home.sh - pull live config changes from $HOME into the repo

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_HOME="$SCRIPT_DIR/home"

echo "🔄 Syncing tracked files from $HOME to $REPO_HOME"

# Build the allowlist from files git actually tracks under home/, as paths
# relative to $REPO_HOME. Using `find` here would sweep in untracked files
# (vendored checkouts, caches, scratch) that were never meant to be synced.
mapfile -d '' -t tracked < <(git -C "$SCRIPT_DIR" ls-files -z -- home/)

if [[ ${#tracked[@]} -eq 0 ]]; then
  echo "⚠️  No tracked files under home/" >&2
  exit 1
fi

# Split into files we can pull and files that are repo-only. A tracked file with
# no counterpart in $HOME cannot be pulled; passing it to rsync would emit a
# link_stat error per file. Some are legitimate (e.g. home/.omp/.gitignore is a
# repo-scoped ignore file, never deployed to $HOME); others are real drift worth
# seeing. Report them either way instead of failing the sync.
pullable=()
repo_only=()
for f in "${tracked[@]}"; do
  rel="${f#home/}"
  if [[ -e "$HOME/$rel" || -L "$HOME/$rel" ]]; then
    pullable+=("./$rel")
  else
    repo_only+=("$rel")
  fi
done

if [[ ${#repo_only[@]} -gt 0 ]]; then
  echo "ℹ️  ${#repo_only[@]} tracked file(s) have no counterpart in \$HOME (not synced):"
  printf '      %s\n' "${repo_only[@]}"
fi

# -aL: archive mode + dereference symlinks (copy content, not link structure)
# --files-from --from0: restrict transfer to the allowlist only
if [[ ${#pullable[@]} -gt 0 ]]; then
  if ! rsync -aL --from0 --files-from=<(printf '%s\0' "${pullable[@]}") "$HOME/" "$REPO_HOME/"; then
    echo "⚠️  rsync reported issues - some tracked files may be missing from \$HOME" >&2
    exit 1
  fi
  echo "✅ Synced ${#pullable[@]} file(s) from \$HOME"
else
  echo "✅ Nothing to sync (no tracked files present in \$HOME)"
fi

echo "💡 Review changes with: git diff && git add -p"
