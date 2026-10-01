# 0004. Link files, not directories, on fresh machines

Date: 2026-10-01

## Status

Accepted

## Context

`install.sh` ran `stow -t "$HOME" -d "$REPO_ROOT" home`. GNU stow folds a
directory into a *single* symlink when that directory does not already exist in
the target, and descends into per-file symlinks when it does.

This machine has `~/.config`, `~/.local` and `~/.omp` as real directories, so
stow descended and produced the file-level layout. A fresh machine has none of
those, so the same command produced nine directory symlinks instead:

```
LINK: .omp => ../../home/mint/mint-dotfiles/home/.omp
```

The working machine was therefore in a stow mode it had never been configured
for. Verified by cloning the repo into a throwaway `$HOME` at matching depth and
running the real `install.sh`: `.config`, `.local` and `.omp` all collapsed to
single directory symlinks, and a write to `$HOME/.config/someapp/config.toml`
resolved to `mint-dotfiles/home/.config/someapp/config.toml`.

Consequences of the folded layout:

- Deleting or moving the repo leaves `$HOME/.config`, `$HOME/.local` and
  `$HOME/.omp` dangling — the entire config surface, from one `rm -rf`.
- Runtime state from every tool lands in the repo. Only `.omp` had a
  `.gitignore` guarding it; caches, logs and sockets had none.
- Git refuses to traverse a symlinked directory, so a `$HOME`-rooted repo
  (`~/.home-git`) sees nothing under `.omp` at all.

## Decision

Pass `--no-folding` to stow in `install.sh`.

On an empty target this changes the plan from 9 links to 2,177, all file-level,
and produces real directories in `$HOME` containing symlinks. Only regular
files fold to a single link, which is the intended behaviour.

A side effect settles an older open question: stow never links `.gitignore`
files (0 of 2,177 links under `--no-folding`), so `home/.omp/.gitignore` is
unreachable and inert. It is retained as defence in depth for anyone running
plain `stow` by hand, but it is no longer load-bearing and should not be
described as protection for the current layout.

## Consequences

- A fresh machine reproduces the layout this machine already has. There is no
  migration, because there is no second mode.
- `$HOME/.config` survives deletion of the repo. The repo can be moved without
  touching the home directory.
- Runtime state stays outside the repo by construction rather than by ignore
  rules. Nothing needs to keep an ignore list current.
- A `$HOME`-rooted repo can walk `.omp` normally.
- **Cost:** a config file an app writes that is *not* already in the repo is no
  longer captured automatically. It must be added via `dotsync`. This is the
  same discipline as today, and `~/.home-git` covers `$HOME` outside the
  dotfiles regardless.
- **Cost:** 2,177 symlinks instead of 9. Install is slower and `$HOME` gains
  inode noise.
- Verifying this required a sandbox, not `stow -nv`. The dry run enumerates
  links; it does not show where a subsequent write lands, and it cannot show
  git's refusal to traverse a symlink. `install.sh` comments record the counts.