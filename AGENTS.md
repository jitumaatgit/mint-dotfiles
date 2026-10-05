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

### Patching package-owned files

A one-line fix to a distro package (`patches/apply-cinnamon-screensaver-gib-patch.sh`) needs `dpkg-divert`, not just an edit: without it `apt upgrade` silently reverts. Two traps make the obvious commands fail.
- `dpkg-divert --add --rename` **refuses to rename** a file the diverting package owns ("Ignoring request to rename…"), so the pristine copy has to be made with `cp -a` to the divert path.
- `dpkg-divert --remove --rename` **refuses to overwrite** an existing differing file, so revert must drop the diversion first and then `cp` the packaged file into place.
- The diverted copy is what `apt upgrade` refreshes, which makes it the signal for "upstream fixed this": `--check` then reports `UPSTREAM-FIXED` and a plain run hands the file back.
- Under `set -o pipefail`, `dpkg-divert --list | grep -q` dies of SIGPIPE (141) and reads as "not diverted". Use a here-string.

### Cinnamon themes have a dark fallback

Cinnamon layers the selected theme over its **own dark stylesheet**: `Main.loadTheme()` builds `new St.Theme({fallback_stylesheet: /usr/share/cinnamon/theme/cinnamon.css})` and then loads the theme's `cinnamon.css` on top. Anything the theme does not declare resolves against that dark sheet. So a GTK2-era theme renders partly correct and partly dark, and **it is not dark mode** — check `org.gnome.desktop.interface color-scheme` once and then stop looking.

- There is **no user stylesheet override**. `Main.setThemeStylesheet()` takes one path, from `org.cinnamon.theme name`, so theme fixes must be appended inside the theme directory — which home-git ignores. Hence `patches/cinnamon6-override.css` plus an idempotent applier. See `docs/guide/chicago95-cinnamon-port.md`.
- **Re-run the applier after re-extracting any theme from upstream.** That edit is the one thing that does not survive on its own.
- Reload without logging out: `gsettings set org.cinnamon.theme name 'Adapta-Nokto'` then back to the real name. It re-reads from disk.
- **Never verify a stylesheet change with `background-color`.** St draws `border-image` over the background, so on any widget using a border image a changed background is invisible while having applied. Use a layout property; it cannot be occluded.
- An absent effect is evidence about *which element paints*, not that the change failed. Confirm with a second probe. The panel's `background-color` did nothing on `.panel-top`/`#panel`, while `font-size` on the same `#panel` rule worked — the visible surface was `#panelLeft`/`#panelCenter`/`#panelRight`.
- `patches/cinnamon6-coverage.py --gate` fails if Cinnamon ships a selector the theme does not declare. It reports widgets and selectors separately on purpose: collapsing pseudo-classes estimates the job, exact matching tells you what to write. A widget themed at rest but not on hover is covered by the first and still-to-do by the second. `./smoke.sh` runs it.

### Stow

- `-R` restows (re-applies the package), `-D` unstows, `-d` is `--dir`. Only `-D` removes links.
- Files added under `home/` are not deployed until `stow -R` runs. `sync-from-home.sh` reports tracked-but-absent paths as "repo-only".
- `install.sh` passes `--no-folding`; do not remove it. stow's default folds a whole directory into one symlink when the target lacks it, so a fresh machine would get `~/.config` pointing at the repo — every app write and all runtime state would land there, and deleting the repo would dangle `$HOME`. Per-file linking (2177 links, not 9) matches the layout this machine already has. ADR-0004.
- `--no-folding` is **absent from `stow --help`** and `--version` even though it works, so the CLI help will not tell you it exists. It *is* documented in the manual: §3 Invoking Stow, with the folding rules in §5.1 folding, §5.2 unfolding and §6.1 refolding. Manual, NEWS and project page are in hister under `label:research:stow`.
- stow never links a `.gitignore` file individually. Under plain stow `~/.omp` folds to a symlink on the repo dir, so `home/.omp/.gitignore` *is* deployed and is what keeps omp's runtime state out of the repo there; under `--no-folding` it is never deployed and is not needed, because runtime stays in `$HOME` regardless.
- Do not put `AGENTS.md` (or any file that does not belong in `$HOME`) under `home/` — stow links every file in the package, so it would appear as `~/AGENTS.md`. `home/.gitkeep` already deploys to `~/.gitkeep`.
- Verify stow changes in a throwaway `$HOME`, not `stow -nv`. The dry run lists links; it does not show where a later write lands, nor that git refuses to traverse a symlinked directory (`fatal: pathspec ... is beyond a symbolic link`, exit 128 — which reads as "not ignored" if you test with `if`).
- A sandbox `$HOME` must sit at the **same directory depth** as the real one. stow writes relative links, so a temp dir at a different depth produces links that resolve outside the sandbox (and stow refuses a target that does not exist).

### Companion repos

- `~/notes` has two writers: this machine and phone Obsidian sync. Expect non-fast-forward, merge rather than force-push, and never force-push `main`.
- Its remote is `origin`. It was previously named `main`, which made `git push origin` fail confusingly — do not reintroduce a branch-named remote.
