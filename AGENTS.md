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
- `~/.git` is a one-line gitdir pointer to `~/.home-git`, added 2026-10-08 so git-bug can run in `$HOME`. Plain git from `$HOME` or any non-nested subdir now targets home-git directly: a `git add -A` there needs no exported `GIT_DIR` to land in the home repo. git-bug data lives in `.home-git` as refs (`refs/bugs/*`, `refs/identities/*`), never as worktree files, so it never appears in a snapshot; git-bug identities are per-repo.
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

### Input devices

Linux keeps two independent numbering spaces for input, and conflating them produces a silent bug.
- `/sys/class/input/inputN` and `/dev/input/eventM` are **not** the same index and do not track each other. Here the touchpad is `input30` but its event node is `event5`, while `input5` is `PS/2 Generic Mouse`. Reading `event5` out of `libinput`/`touchegg` output and pasting it as an input index is how `enable-touchpad.sh` came to target the wrong device entirely.
- Resolve by property, never by index: `udevadm info --query=property --path=/sys/class/input/inputN | grep -qx 'ID_INPUT_TOUCHPAD=1'` is the same classification libinput uses, is readable from `/run/udev` without root, and yields the path directly. Confirm the match is unique before acting on it — an external touchpad makes it two.
- **`runtime_status: unsupported` means the device can never be runtime-suspended.** Writing `power/runtime_enabled` or `power/control` at such a device is a no-op, so no autosuspend fix can possibly help. Read `power/runtime_status` before believing one. This touchpad reports `unsupported`; `control` reads `auto` and looks like the smoking gun, but nothing can act on it.
- Only two things actually block input: the `org.cinnamon.desktop.peripherals.touchpad send-events` gsettings key, and the kernel `inhibited` flag (`/sys/class/input/inputN/inhibited`, the mechanism `keyboard-toggle` uses). Everything else in sysfs is decoration.

### Watching a GSettings key from outside its own process

For logging who changes a key cross-process (`~/.local/bin/touchpad-watch.sh`, `touchpad-watch.service`).
- **GSettings has no cross-process change signal.** `org.freedesktop.DBus.Properties.PropertiesChanged` is never emitted for dconf-backed keys, so a `dbus-monitor` filter on it captures nothing and fails silently — the watcher ran, matched nothing, and logged nothing.
- The only cross-process signal is the write itself: `ca.desrt.dconf.Writer.Change`, a method call on `/ca/desrt/dconf/Writer/user`. The key path arrives **hex-encoded** in a byte array wrapped across lines, so match against the accumulated hex, not a decoded string.
- **Do not attribute from `ca.desrt.dconf.Writer.Notify`.** dconf-service emits that itself, so it resolves to dconf-service no matter who wrote the value. Take the `sender` from the `Change` call instead — that is the real writer.
- Each write produces **two** `Change` calls: the client, then dconf-service relaying it. Comparing against the previous value collapses the pair into one log line.
- Resolve `sender` to a PID **first**, before any sleeping or other work: `gsettings` and similar short-lived clients have already exited by then, so a delayed lookup only ever yields a bare bus name. `busctl --user status :1.N | sed -n 's/^PID=//p'`, then read `/proc/$PID/comm`.

### systemd user units that need root

- This machine has `mint ALL=(ALL) NOPASSWD:ALL` in `/etc/sudoers.d/mint`, so a user unit can `sudo` with no prompt. A unit that lost its `sudo` — this one was installed from a stripped copy — fails silently against root-owned sysfs and looks like it did nothing.
- **`ExecStart` must be a leaf.** An installer script that also installs and enables its own unit will loop the moment systemd runs that unit; it took 69s to notice. Keep install and run on separate flags and have the unit call the repair-only one.
- A `--quiet` flag that still installs is the same bug wearing a hat. Route output suppression and action selection through separate variables.

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
