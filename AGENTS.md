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

Nvim on this build is a **client-server pair**, documented in `:h tui.txt`: running `nvim` starts the builtin **UI client** (owns the terminal, has **no** socket) which starts a **`nvim --embed` server** child (loads the config, holds the buffers, owns the socket). Anything that talks to a running nvim has to account for that, and every obvious heuristic gets it wrong.
- The socket is named `$XDG_RUNTIME_DIR/nvim.<pid>.<counter>` (`:h serverstart()`), and the pid in the name is the **server's**. The process `ps` shows for the pane — the client — has no socket at all.
- So **do not select a socket by "has a controlling tty"**. The server reports `tty_nr` 0 and `tpgid` -1, which is indistinguishable from an unrelated hidden `nvim --embed` that other tooling may spawn; a float opened in one of those is invisible. Match the socket's owner against the tmux pane's process tree by **ancestry** (`pane → client → server`) instead. `~/.local/bin/nvim-tangent-capture --diagnose` prints that decision.
- `nvim --server <sock> --remote-expr …` loads the **user's config** in its own process, so it fires `VimEnter` hooks and leaves a dead `nvim.<pid>.0` socket in `$XDG_RUNTIME_DIR` behind. Stale socket files therefore accumulate; `kill -0` on the name's pid *and* a real round trip are both required before trusting one.
- `serverstart()` in a TUI session produces a **second** socket (counter `.1`), not the first: the server already publishes `.0` so that `:detach` can reattach to it later.
- **Insert mode is not per-window.** Closing a floating window that was in insert mode leaves the window underneath in insert mode, so the next keystrokes land in the note. Enter a float with `startinsert` and `stopinsert` on close — and note that `stopinsert` is deferred, so a test must assert the mode after a wait rather than immediately.

### Tangent capture

`<leader>nT` in nvim, `<Super>t` on the desktop, and `Ctrl+Space Shift+T` in wezterm all append a tangent to today's daily note's `## Tangent Parking Lot` without leaving the current note. Workflow, config knobs and troubleshooting: `docs/guide/tangent-capture.md`. Self-check: `home/.config/nvim/lua/custom/tangent-capture_test.lua`, run by `./smoke.sh`.
- That section is the inbox, deliberately, instead of a new file: the weekly note template and `~/notes/scripts/extract_weekly_tangents.py` already read exactly it.
- Timestamps are **local time**. Every other date in the vault — daily-note filenames, `## Log` — is local, and a UTC stamp dates an evening tangent to the next day.
- Entries go after the section's last non-blank line, not directly under the heading: a trailing `### Goal:` heading then captures the entry, which is how the weekly note groups them, and the blank line before the next `##` heading stays put.
- The write goes **through the buffer** when the target file is already open in one (writing the file underneath would make its next `:w` silently revert the tangent), and through a temp-file + rename otherwise so a crash cannot truncate a note.

### Daily note navigation and capture

`<leader>nD` / `<Super>d` / `Leader d` go to today's daily note; `<leader>nA` / `<Super>a` / `<Leader>D` append a task or log entry to it. Workflow, config knobs and troubleshooting: `docs/guide/daily-note.md`. Self-check: `home/.config/nvim/lua/custom/daily-note_test.lua`, run by `./smoke.sh`.
- The capture float has **two modes and one keystroke**: `<Tab>` switches Task (`#### Tasks`, a `- [ ]` checkbox) and Log (`## Log`, a `- **HH:MM**` line). Which section an entry lands in is never a question in the UI, so a hotkey press cannot land in the wrong place.
- Going to the note means **focusing the window that already shows it**, not `:edit`. `:edit` on an already-displayed note leaves the same buffer in two windows, which then diverge on the next save of either. A loaded-but-hidden buffer goes in the current window instead.
- Tasks are checkboxes because the vault's own tooling reads them: `task-auto-complete.lua` relocates `- [x]` lines to `## Completed` on save, and `obsidian-task-filter.lua` greps `- [ ]`.
- All three note hotkeys (tangent, daily note, capture) share one dconf install script and one editor-resolution library. `gsettings` writes a keybinding slot's schema and its `custom-list` membership separately, so a slot that is configured but not listed is inert and looks configured — that is why the script owns both and `--check` is not optional.
- **The capture has to focus the note's window too**, or the float opens over whatever window is current and the entry lands in a note nobody is looking at — which reads as "the hotkey did nothing" and is exactly what it looked like when `<Super>a` was pressed from another window. A *floating* window is current while it is open, so a test has to close it and assert where focus returned.
- **A keybinding has no terminal to print to**, so a hotkey that only writes stdout is silent in both directions: you cannot tell a capture that worked from one that failed. The scripts now notify on both. And the resolution prints *exactly* the socket address, because the caller reads stdout with a command substitution — a line printed by the raise helpers would be handed on as part of that address. `./smoke.sh` asserts nothing extra reaches stdout.
- **Never let a test redirect the vault late.** A scratch note has to be in place before the editor loads (a `daily_note_path` override in the test's `init.lua`, or `g:tangent_parking_lot_path`), not hoped for afterwards. Two runs of mine wrote test lines into the real `## Tangent Parking Lot`.
- A **duplicate keybinding is silently dropped** by wezterm's key table, which is why `home/.config/wezterm/note_keys_test.py` loads the config and asserts no two entries claim the same key combination.

### Bringing a terminal window to the front

What the note hotkeys do after they reach the editor, and the only part of it that is not nvim's business (`~/.local/lib/nvim-editor-socket.sh`).
- **`wezterm cli activate-pane` cannot raise a background window.** It activates a pane inside the *focused* GUI window and leaves `_NET_ACTIVE_WINDOW` where it was — exit 0, nothing happens. `activate-tab` is the same. The X window has to be raised directly (`xdotool windowactivate` / `wmctrl -i -a`).
- **The only link from a wezterm pane to its X window is the title**: wezterm names a window after the tab it is showing. So pane title → `xdotool search --onlyvisible --name` → exact re-check with `getwindowname`. Ambiguity is left alone rather than guessed at; two windows can both be `nvim`.
- **`wmctrl` zero-pads window ids and `xprop` does not.** `0x02e000f1` and `0x2e000f1` are the same window and a string comparison fails, which reads as "the raise did nothing" when it did. Compare numerically.
- **The Desktop and conky windows are not focusable**, so `wmctrl -i -a` on one returns 0 and changes nothing. Activate a window you know is a terminal.
- **`wezterm start` runs the command in the GUI's environment, not the caller's** — the spawn is a request to the running GUI, so an env var set on the command line never reaches the program in the pane. Test hooks that need the editor's environment have to be set another way.
- **`nvim --remote-expr` is Vimscript**, not Lua. A Lua body must go through `execute("luafile …")`; for a single query `luaeval("…")` with `vim.fn.*` calls (VimL functions such as `bufnr` are *not* globals inside `luaeval`).
- **`environ()` is unavailable here** (E118, too many arguments), so the server's env has to be read as `$WEZTERM_PANE` rather than `environ("WEZTERM_PANE")`.

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

### Desktop hotkeys

Cinnamon custom keybindings are the convention for OS-level hotkeys here (`custom1` = `<Super>q` → wezterm; `custom2` = `<Super>t`, `custom3` = `<Super>d`, `custom4` = `<Super>a`, all installed by `patches/apply-cinnamon-note-keybindings.sh`). One script owns all three note hotkeys, because the slot bookkeeping is the part that is easy to get subtly wrong once — and it is identical every time.
- Registration is **two** writes: the slot's own relocatable schema path (`org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/customN/`) and membership in `org.cinnamon.desktop.keybindings custom-list`. A slot that is configured but absent from `custom-list` is inert, and looks configured.
- `gsettings get` returns the value with GVariant's syntax attached: strings come back quoted (`'/path/to/thing'`), lists bracketed (`['<Super>t']`). Comparing a read-back string against a bare path always fails.
- The command runs as the **user**, with the session's `DISPLAY` and `PATH`. That is why this beat keyd for the job: keyd's `command()` bindings run as root, so reaching a socket in `$XDG_RUNTIME_DIR` would mean dropping privileges and rebuilding the environment first.
- It is unversioned state (dconf, not this repo), so `--check` is the only thing that notices drift or a binding that was never applied. `./smoke.sh` runs it.

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

### Rootless Docker (installed 2026-10-08)

Installed from Docker's **upstream apt repo on the `noble` branch** (Mint 22.3 is Ubuntu 24.04 — `ID_LIKE=ubuntu`, `UBUNTU_CODENAME=noble`), key verified against the published fingerprint before being trusted. Rootless only: rootful `docker.service`/`docker.socket` **and** the system `containerd.service` are disabled; only the user unit runs. `docker-ce` 29.9.0, containerd 2.4.1, buildx 0.38.0, compose 5.6.0.

- **The package postinstall starts the rootful daemon once, before you can disable it.** That start left a host `docker0` (172.17.0.1/16) and a stale `/var/run/docker.sock` behind even after `systemctl disable --now docker`. Both are leftovers, not the rootless plumbing: the rootless bridge and its veths live in a **detached netns**. Read `/proc/<rootlesskit-holder>/net/dev` to see it — it lists `lo tap0 docker0`, while the host namespace's copy showed **no** ports attached. `ss -lx` is what separates a stale socket file from a live listener; the socket file alone proves nothing.
- **`--detach-netns` puts `dockerd` itself in the host netns**, so `docker0` existing on the host cannot be read as "the rootless bridge is here". Only veths answer that (`ip -br link show master docker0` stayed empty for a running rootless container).
- **`net.ipv4.ping_group_range` defaults to `1 0`, an empty range**, so ICMP sockets fail inside a rootless container while DNS and TCP work perfectly. `ping` reports 100% packet loss and looks like a routing outage; `wget` on the same container returns OK. Fixed with `/etc/sysctl.d/99-docker-rootless.conf`: `net.ipv4.ping_group_range = 0 2147483647` and `net.ipv4.ip_unprivileged_port_start = 0` (the latter is what allows publishing ports below 1024 — verified by binding host `127.0.0.1:80` from a container). Both are host-wide, not per-container.
- **Published ports default to loopback** via `~/.config/docker/daemon.json` → `{"ip": "127.0.0.1"}`. Verified with `ss`: a plain `-p 8099:80` listens on `127.0.0.1:8099`, an explicit `-p 0.0.0.0:8098:80` on `0.0.0.0:8098`. ufw's `deny (incoming)` does **not** protect rootless publishing — rootlesskit binds the host socket itself, outside the daemon's netns — so this config, not the firewall, is the control.
- **Native `overlayfs` works** on this kernel (7.0.0-38-generic supports unprivileged overlay mounts), so `fuse-overlayfs` is installed but unused. `docker info` reports `driver=overlayfs`; if it ever silently falls back to fuse, that is a kernel change, not a Docker change.
- **`DOCKER_HOST` is exported in `home/.zshrc`**, derived from `XDG_RUNTIME_DIR` rather than a hardcoded uid. Consequence to remember: while it is set, `docker context use` no longer changes which daemon the CLI talks to — non-CLI tools (compose, testcontainers) are the reason it is there.
- **Boot start is linger, not `enable`.** `systemctl --user enable docker` plus `Linger=yes` for the user is what starts it without a login; the unit alone only starts at login.
- The setuptool refuses to run without `XDG_RUNTIME_DIR` once systemd is detected, so a non-login shell needs: `XDG_RUNTIME_DIR=/run/user/1001 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus dockerd-rootless-setuptool.sh install`.
