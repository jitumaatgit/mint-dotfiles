# mint-dotfiles

## Agent skills

### Issue tracker
Issues/specs in GitHub Issues (gh). See `docs/agents/issue-tracker.md`.

### Triage labels
Canonical roles use default label names (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs
Single-context layout: one `CONTEXT.md` + `docs/adr/` at repo root. See `docs/agents/domain.md`.

## Learnings

### Neovim config integration
Nvim is a client-server pair (`:h tui.txt`): `nvim` starts the UI client (owns terminal, no socket) which starts an `nvim --embed` server (loads config, owns socket). Every obvious heuristic gets this wrong.
- Socket `$XDG_RUNTIME_DIR/nvim.<pid>.<counter>`; pid is the **server's**. Don't select by "has controlling tty" — server reports tty_nr 0/tpgid -1, indistinguishable from a hidden embed. Match by ancestry (pane→client→server). `~/.local/bin/nvim-tangent-capture --diagnose` prints the decision.
- `nvim --server <sock> --remote-expr` loads user config → fires VimEnter, leaves dead socket. Stale sockets accumulate; require `kill -0` on pid **and** a real round trip.
- `serverstart()` in TUI yields a second socket (`.1`); `.0` is the detach socket.
- Insert mode isn't per-window: closing a float left in insert mode leaves the underlying window in insert mode. `startinsert` on enter, `stopinsert` on close (deferred → assert mode after a wait).

### Tangent capture
`<leader>nT`/`<Super>t`/`Ctrl+Space Shift+T` append to today's daily note `## Tangent Parking Lot`. Workflow: `docs/guide/tangent-capture.md`; self-check `home/.config/nvim/lua/custom/tangent-capture_test.lua` (`./smoke.sh`).
- Section is the inbox deliberately; weekly note template + `~/notes/scripts/extract_weekly_tangents.py` read exactly it.
- Timestamps local (vault dates are local; UTC misdates evening tangents).
- Entries go after the section's last non-blank line (trailing `### Goal:` then captures; blank before next `##` stays).
- Write through the buffer if file already open (else file write gets reverted on next `:w`); otherwise temp-file + rename.

### Daily note navigation and capture
`<leader>nD`/`<Super>d`/`Leader d` → today's note; `<leader>nA`/`<Super>a`/`<Leader>D` → append task/log. Workflow: `docs/guide/daily-note.md`; self-check `daily-note_test.lua`.
- Capture float: `<Tab>` toggles Task (`#### Tasks`, `- [ ]`) vs Log (`## Log`, `- **HH:MM**`).
- "Go to note" = focus the window already showing it, not `:edit` (avoids same buffer in two windows diverging).
- Tasks are checkboxes: `task-auto-complete.lua` moves `- [x]` to `## Completed` on save; `obsidian-task-filter.lua` greps `- [ ]`.
- Note hotkeys share one dconf install script + editor-socket lib. `gsettings` writes slot schema and `custom-list` membership separately → a configured-but-unlisted slot is inert. Script owns both; `--check` not optional.
- Capture must focus the note's window too, or float opens over current window (looks like "did nothing"). Floating window is current while open → test must close it and assert focus return.
- Keybindings have no terminal: stdout-only is silent both ways. Scripts notify on success/failure. Resolution prints exactly the socket address (caller reads via command substitution; raise-helper output would be absorbed). `./smoke.sh` asserts nothing extra on stdout.
- Scratch note must exist before editor loads (`daily_note_path` override in test init.lua, or `g:tangent_parking_lot_path`). Never redirect the vault late — two runs wrote test lines into the real parking lot.
- Duplicate wezterm keybinding silently dropped → `note_keys_test.py` asserts no duplicate key combos.

### Bringing a terminal window to the front
`~/.local/lib/nvim-editor-socket.sh`. `wezterm cli activate-pane`/`activate-tab` only activate a pane in the *focused* GUI window; raise the X window directly (`xdotool windowactivate`/`wmctrl -i -a`).
- Pane→X window link is the title (wezterm names window after shown tab): title → `xdotool search --onlyvisible --name` → exact `getwindowname` re-check; leave ambiguity alone.
- `wmctrl` zero-pads ids, `xprop` doesn't (`0x02e000f1` == `0x2e000f1`); compare numerically.
- Desktop/conky windows aren't focusable; `wmctrl -i -a` returns 0 and changes nothing.
- `wezterm start` runs in GUI env, not caller's; env vars set on the command line don't reach the pane.
- `nvim --remote-expr` is Vimscript; Lua body via `execute("luafile …")`, single query via `luaeval("…")` with `vim.fn.*` (VimL funcs like `bufnr` aren't globals in luaeval).
- `environ()` unavailable (E118); read server env as `$WEZTERM_PANE`.

### home-git (`~/.home-git`)
Versions everything in `$HOME` this repo doesn't own. No remote. Workflow: `docs/guide/home-git.md`.
- `hsnap` no-ops on clean tree → run before risky changes; `hgit diff` after.
- Never `export GIT_DIR`/`GIT_WORK_TREE` in a persistent shell (incidental `git add` lands in home-git). Scripts set them internally.
- `~/.git` is a one-line gitdir pointer to `~/.home-git` (2026-10-08) so git-bug runs in `$HOME`. Plain git from `$HOME`/non-nested subdir targets home-git directly. git-bug data lives as refs, never worktree files; identities per-repo.
- Full `hrestore <old-rev>` rewrites hook+scripts (they're tracked inside the tree they operate on). Prefer `hrestore -- <path>`.
- Exclude content-addressed stores (hister index once = 5271 files/40% of commit). Ignore rule alone doesn't untrack → `hgit rm --cached -- <path>` (+`-f` for gitlinks).

### Live config writes land in this repo
`~/.omp/agent/config.yml` and `~/.zshrc` are symlinks into `home/`. Tool writes/hotkey presses modify tracked files unprompted. Read the diff before staging.

### Patching package-owned files
One-line fix to a distro package (`patches/apply-cinnamon-screensaver-gib-patch.sh`) needs `dpkg-divert`, not just an edit (else `apt upgrade` reverts). Traps: `--add --rename` refuses to rename a file the package owns → `cp -a` pristine to divert path. `--remove --rename` refuses to overwrite a differing file → drop diversion first, then `cp`. Diverted copy is what `apt upgrade` refreshes → `--check` reports `UPSTREAM-FIXED`, plain run hands file back. Under `set -o pipefail`, `dpkg-divert --list | grep -q` dies SIGPIPE (141) → use here-string.

### Input devices
`/sys/class/input/inputN` and `/dev/input/eventM` are independent indices (touchpad here is input30/event5). Resolve by property, never index: `udevadm info --query=property --path=/sys/class/input/inputN | grep -qx 'ID_INPUT_TOUCHPAD=1'` (libinput's classification, readable from `/run/udev` without root); confirm unique (external touchpad → two). `runtime_status: unsupported` means never runtime-suspendable — writing `power/runtime_enabled`/`control` is a no-op (this touchpad is `unsupported`; `control` reads `auto` but nothing acts). Only two blockers: `org.cinnamon.desktop.peripherals.touchpad send-events` gsettings key and kernel `inhibited` flag. Everything else in sysfs is decoration.

### Watching a GSettings key cross-process
`~/.local/bin/touchpad-watch.sh`, `touchpad-watch.service`. GSettings has no cross-process change signal (`PropertiesChanged` never emitted for dconf keys). Only cross-process signal is the write itself: `ca.desrt.dconf.Writer.Change` method call on `/ca/desrt/dconf/Writer/user`; key path arrives hex-encoded in a byte array wrapped across lines → match accumulated hex. Don't attribute via `Notify` (dconf-service emits it itself). Each write → two `Change` calls (client + relay); compare to previous value to collapse. Resolve `sender` to PID first (short-lived clients exit) via `busctl --user status :1.N`, then `/proc/$PID/comm`.

### Desktop hotkeys
Cinnamon custom keybindings are the convention (`custom1`=`<Super>q`→wezterm, `custom2`=`<Super>t`, `custom3`=`<Super>d`, `custom4`=`<Super>a`; installed by `patches/apply-cinnamon-note-keybindings.sh`). One script owns all three note hotkeys (slot bookkeeping is subtle).
- Registration = two writes: slot's relocatable schema path + membership in `custom-list`. Configured-but-unlisted slot is inert.
- `gsettings get` returns GVariant syntax (quoted strings, bracketed lists); comparing read-back to bare path always fails.
- Command runs as user with session DISPLAY/PATH (why this beat keyd: keyd `command()` runs as root).
- Unversioned (dconf); `--check` is the only drift detector. `./smoke.sh` runs it.

### systemd user units needing root
`mint ALL=(ALL) NOPASSWD:ALL` in `/etc/sudoers.d/mint` → user unit can sudo. Unit that lost sudo fails silently against root-owned sysfs.
- `ExecStart` must be a leaf (installer that installs+enables its own unit loops; took 69s to notice). Separate install vs run flags.
- `--quiet` that still installs is the same bug. Separate output suppression from action selection.

### Cinnamon themes (dark fallback)
Cinnamon layers selected theme over its own dark stylesheet (`Main.loadTheme()` builds `St.Theme({fallback_stylesheet: /usr/share/cinnamon/theme/cinnamon.css})` then loads theme's `cinnamon.css`). GTK2-era theme → partly correct, partly dark; not dark mode (check `color-scheme` once). No user stylesheet override → fixes appended inside theme dir (home-git ignores) via `patches/cinnamon6-override.css` + idempotent applier; `docs/guide/chicago95-cinnamon-port.md`.
- Re-run applier after re-extracting a theme.
- Reload without logout: `gsettings set org.cinnamon.theme name 'Adapta-Nokto'` then back.
- Never verify stylesheet change via `background-color` (St draws `border-image` over it). Use a layout property.
- Absent effect = evidence about which element paints, not failure. Confirm with second probe (panel: `background-color` did nothing on `.panel-top`/`#panel`, `font-size` on `#panel` worked → surface was `#panelLeft`/`#panelCenter`/`#panelRight`).
- `patches/cinnamon6-coverage.py --gate` fails if Cinnamon ships an undeclared selector. Widgets vs selectors reported separately. `./smoke.sh` runs it.

### Stow
`-R` restows, `-D` unstows, `-d`=`--dir`; only `-D` removes links. Files under `home/` not deployed until `stow -R`; `sync-from-home.sh` reports repo-only paths.
- `install.sh` passes `--no-folding` (do not remove): default folds a whole dir into one symlink → fresh machine gets `~/.config` → repo, all app writes/runtime state land there, deleting repo dangles `$HOME`. Per-file linking (2177 links). ADR-0004.
- `--no-folding` absent from `--help`/`--version` but works; documented manual §3, folding §5.1/§5.2/§6.1.
- Stow manual no longer claimable via `label:research:stow` (0 results); GNU pages not in web index. Search `stow manual`.
- stow never links `.gitignore` individually. Plain stow folds `~/.omp`→repo so `home/.omp/.gitignore` is deployed (keeps omp runtime out); under `--no-folding` not needed.
- Don't put `AGENTS.md` (or anything not belonging in `$HOME`) under `home/` → deploys as `~/AGENTS.md`. `home/.gitkeep`→`~/.gitkeep`.
- Verify stow in throwaway `$HOME` at same directory depth (relative links); `stow -nv` only lists links.

### Companion repos
`~/notes`: two writers (this machine + phone Obsidian sync). Expect non-fast-forward; merge, never force-push `main`. Remote is `origin` (was `main` — don't reintroduce branch-named remote).

### Rootless Docker (2026-10-08)
Upstream apt `noble` branch (Mint 22.3=Ubuntu 24.04), key verified. Rootless only: rootful `docker.service`/`docker.socket` + system `containerd.service` disabled; only user unit runs. docker-ce 29.9.0, containerd 2.4.1, buildx 0.38.0, compose 5.6.0.
- Package postinstall starts rootful daemon once → leaves host `docker0` (172.17.0.1/16) + stale `/var/run/docker.sock` even after disable. Rootless bridge/veths live in detached netns; read `/proc/<rootlesskit-holder>/net/dev` (lists `lo tap0 docker0`). `ss -lx` distinguishes stale socket from live listener.
- `--detach-netns` puts dockerd in host netns, so host `docker0` ≠ "rootless bridge here"; only veths prove it.
- `net.ipv4.ping_group_range` defaults `1 0` (empty) → ICMP fails in rootless container while DNS/TCP work (`ping` 100% loss, `wget` OK). Fixed via `/etc/sysctl.d/99-docker-rootless.conf`: `ping_group_range = 0 2147483647`, `ip_unprivileged_port_start = 0` (allows publishing <1024). Host-wide.
- Published ports default loopback via `~/.config/docker/daemon.json` → `{"ip":"127.0.0.1"}`. `ss`: plain `-p 8099:80` → `127.0.0.1:8099`; explicit `-p 0.0.0.0:8098:80` → `0.0.0.0:8098`. ufw doesn't protect rootless publishing (rootlesskit binds host socket outside daemon netns) → config, not firewall, is the control.
- Native overlayfs works on this kernel → fuse-overlayfs installed but unused; `docker info` → `driver=overlayfs`. Silent fallback to fuse = kernel change.
- `DOCKER_HOST` exported in `home/.zshrc` from `XDG_RUNTIME_DIR` → while set, `docker context use` no longer changes target daemon.
- Boot start = linger, not enable: `systemctl --user enable docker` + `Linger=yes`. Unit alone starts only at login.
- setuptool refuses without `XDG_RUNTIME_DIR` once systemd detected → non-login shell needs `XDG_RUNTIME_DIR=/run/user/1001 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus dockerd-rootless-setuptool.sh install`.
