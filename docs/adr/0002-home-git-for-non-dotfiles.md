# 0002. Track $HOME outside the dotfiles in a separate local-only repo

Date: 2026-09-26

## Status

Accepted

## Context

`home/` covers only what stow deploys. The large majority of `$HOME` is not
that: agent configs, tool state, scripts, dotfile-adjacent files with no
symlink. Two options for versioning them.

**Fold them into this repo** by widening the stow source. Rejected: stow's
contract is that `home/` mirrors `$HOME`, and the hook refuses embedded repos,
so unrelated content would either break the layout or need a second package
that is never actually stowed.

**A second git repo rooted at `$HOME`** (`~/.home-git`, bare, with
`core.worktree=/home/mint`). It snapshots everything the dotfiles repo does not
own, so `hsnap` before a risky change and `hgit diff` after yields exactly what
changed — the snapshot/diff loop documented in `docs/guide/home-git.md`.

## Decision

Keep `~/.home-git` as a separate bare repo with no remote. Its ignore file
(`~/.config/home-git/ignore`, itself tracked) excludes `mint-dotfiles/`,
`notes/`, `projects/`, `pso/`, `other-dotfiles/`, `nixarch-dotfiles/` and
`.nvm/`.

## Consequences

- Two systems, one file each, no overlap. The ignore file is the enforcement
  point: if a path ever appears in both repos, one of them is wrong.
- **No remote, deliberately.** The repo versions live credentials (`.ssh/`,
  `.npmrc`, `.dmrc`, fcm tokens) that are pending rotation. It is exactly as
  private as the disk, and pushing it anywhere would change that.
- `hgit`/`hsnap`/`hrestore` set `GIT_DIR`/`GIT_WORK_TREE` internally only.
  Exporting them in a persistent shell redirects incidental `git` commands into
  this repo — it has happened.
- A full `hrestore` to an old revision rewrites the tooling itself, because the
  hook and scripts are tracked inside the tree they operate on. Restore
  individual paths instead where possible.
- Excluding runtime state is not optional here. An early snapshot captured
  hister's index: 5,271 files, 40% of the commit, growing on every reindex
  because the store is content-addressed. `hgit diff` became unreadable.