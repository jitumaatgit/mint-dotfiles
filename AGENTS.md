# mint-dotfiles

## Agent skills

### Issue tracker

Issues and specs are tracked in the repo's GitHub Issues (uses the `gh` CLI). See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical triage roles use their default label names (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context layout: one `CONTEXT.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.
## Learnings

### Neovim config integration

### home-git (`~/.home-git`)

Versions everything in `$HOME` this repo does not own. No remote by design. Full workflow in `docs/guide/home-git.md`.
- `hsnap` no-ops on a clean tree, so run it reflexively before any risky change; `hgit diff` after shows exactly what changed.
- Never `export GIT_DIR`/`GIT_WORK_TREE` in a persistent shell — an incidental `git add` then lands in home-git. The scripts set them internally only.
- A full `hrestore <old-rev>` rewrites the hook and the scripts themselves, because they are tracked inside the tree they operate on. Prefer `hrestore -- <path>`.
- Exclude content-addressed stores. An early snapshot pulled in hister's index: 5,271 files, 40% of the commit, growing on every reindex until `hgit diff` was unreadable.
- Adding an ignore rule does not untrack; it also needs `hgit rm --cached -- <path>`, plus `-f` for gitlinks.

### Live config writes land in this repo

`~/.omp/agent/config.yml` and `~/.zshrc` are symlinks into `home/`. Tool writes and hotkey presses modify tracked files unprompted — an `M` on those paths is often not a decision anyone made. Read the diff before staging.

### Stow

- `-R` restows (re-applies the package), `-D` unstows, `-d` is `--dir`. Only `-D` removes links.
- Files added under `home/` are not deployed until `stow -R` runs. `sync-from-home.sh` reports tracked-but-absent paths as "repo-only".
- `home/.omp/.gitignore` is the one tracked-but-undeployed file. Nothing enforces that — there is no `.stow-local-ignore` in the repo, so `./install.sh` on a fresh machine can symlink it into `$HOME/.omp/`.
- Do not put `AGENTS.md` (or any file that does not belong in `$HOME`) under `home/` — stow links the whole package, so it would appear as `~/AGENTS.md`.

### Companion repos

- `~/notes` has two writers: this machine and phone Obsidian sync. Expect non-fast-forward, merge rather than force-push, and never force-push `main`.
- Its remote is `origin`. It was previously named `main`, which made `git push origin` fail confusingly — do not reintroduce a branch-named remote.
