# CONTEXT — mint-dotfiles

Domain vocabulary for this repository. Use these terms exactly; don't drift to
synonyms. `docs/agents/domain.md` explains how agents consume this file.

## What this repo is

Dotfiles for a single Linux Mint machine. Every config file that belongs under
`$HOME` is version-controlled here and deployed into place as a symlink.
Companion repo: `nixarch-dotfiles` (Arch + Nix + Home Manager, separate machine).

## Core terms

**package** — A top-level directory stow deploys as one unit. This repo has
exactly one: `home/`. (The plural in `stow-best-practices.md` is generic
advice; do not read it as this repo's layout.)

**stow source** — `home/`. Contains the *real* files. `$HOME` holds only
symlinks pointing back into it.

**live file** — The path as used from `$HOME`, e.g. `~/.zshrc`. Because it is a
symlink, editing it edits the repo file directly. "Live" and "repo" are the
same bytes for any stowed path.

**tracked file** — A path under `home/` that `git ls-files` reports. This is the
allowlist `sync-from-home.sh` uses. Untracked files under `home/` are never
pulled back, which is deliberate: it keeps vendored checkouts and caches out.

**repo-only file** — Tracked under `home/`, but with no counterpart in `$HOME`
(e.g. `home/.omp/.gitignore`). `sync-from-home.sh` reports these rather than
failing, because a repo-scoped ignore file is legitimate.

**`dotsync`** — Shell alias: `cd ~/mint-dotfiles && ./sync-from-home.sh &&
git diff`. The standard review loop after touching anything under `$HOME`.

**deployed / unstowed** — A file is *deployed* when its symlink exists in
`$HOME`; *unstowed* after `stow -D`. Note `-R` does not undeploy: it restows.

## Boundaries

**What does NOT live here:**

| Lives in | Why not here |
|---|---|
| `~/.home-git` | Separate local-only repo; versions all of `$HOME` *outside* this repo. No remote by design. See `docs/guide/home-git.md`. |
| `~/notes` | Separate git repo, PARA-structured Obsidian vault. |
| `~/projects`, `~/pso`, `~/other-dotfiles`, `~/nixarch-dotfiles` | Independent repos with their own tooling. |

home-git's ignore file excludes `mint-dotfiles/` entirely, so the two systems
never contend over the same file. This is the single most important boundary
in the setup: if a file appears in both, you have lost it.

## Invariants

1. `home/` mirrors `$HOME` path-for-path. No renames, no flattening.
2. Never commit runtime state — caches, indexes, sockets, lock files.
3. Live-tool config (`~/.omp/agent/config.yml`, `~/.zshrc`) is a **symlink into
   this repo**. Tool edits therefore land here unprompted; an `M` on one of
   those paths may be a hotkey press, not a decision. Read the diff.
4. `install.sh` must build the bat theme cache *after* stow, never before.