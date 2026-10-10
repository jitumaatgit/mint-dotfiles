# tangent capture — parking a thought without leaving the note

The tangent that arrives while you are doing something else goes into today's
daily note without a buffer switch, a window change, or a saved file standing
between you and the thought. One keystroke in, one line out, and you are back.

## Triggers

| Trigger | Where it works |
|---|---|
| `<leader>nT` | inside nvim |
| `Ctrl+Space` then `Shift+T` | inside wezterm |
| `<Super>t` | anywhere in the Cinnamon session |
| `nvim-tangent-capture` | any shell, including one with no nvim running |

`<CR>` saves and closes; `<Esc>` and `<C-c>` close and change nothing. With no
nvim running, the script starts one whose only job is the float, and it quits
again on save or cancel.

## Where it lands

Today's daily note, in the `## Tangent Parking Lot` section:

```
## Tangent Parking Lot

<!-- Optional: group entries under '### Goal: <name>' — the weekly note then groups them by goal. -->
- the thought that arrived (2026-10-08 17:57)

## Operations
```

That section rather than a new file because it is already the pipeline: the
weekly note template pulls tangents from each daily note into its own
`## Tangent Parking Lot`, and `~/notes/scripts/extract_weekly_tangents.py` turns
them into inbox stubs (dry-run by default; `--write` to apply). A second capture
file would be a second convention for the same idea.

Rules the format follows:

- The entry goes after the **last non-blank line of the section**, not directly
  under the heading. A trailing `### Goal: <name>` heading therefore captures
  the entry — which is how the weekly note is able to group them — and the blank
  line separating the section from the next `##` heading stays put.
- A missing section is appended at the end of the file. A missing *file* is
  created: obsidian.nvim makes it first, so it gets the vault's template and
  frontmatter, and the template file is copied verbatim only if that is
  unavailable.
- The timestamp is **local time**, matching the daily-note filename and the
  `## Log` stamps it sits beside. Nothing else in this vault is UTC-based, and a
  UTC stamp would date an evening tangent to the next day.
- Pasting a paragraph indents the continuation lines by two spaces, the shape
  existing multi-line tangents already use.
- `<CR>` on blank input writes nothing and says nothing: an empty float is a
  cancel, not an entry.

## Configuration

| `g:` variable | Default | Effect |
|---|---|---|
| `tangent_parking_lot_path` | (unset) | Absolute path, or `~`-prefixed, to append to instead of today's daily note. Set it and the whole daily-note path is skipped; a file without the section gets one. |
| `tangent_timestamp` | `1` | `0` writes the bare bullet. |
| `tangent_timestamp_utc` | `0` | `1` stamps UTC instead of local time. |
| `tangent_prompt` | `"Tangent > "` | Border label on the float. |

Commands: `:TangentCapture` (float), `:TangentCapture!` (float, quit when done —
this is what a cold start runs), `:TangentAppend <text>` (no UI, for scripts).

| What | Where |
|---|---|
| Float, insert rules, write path, RPC entry point | `home/.config/nvim/lua/custom/note-capture.lua` |
| Tangent's section choice and entry shape | `home/.config/nvim/lua/custom/tangent-capture.lua` |
| Self-check | `home/.config/nvim/lua/custom/tangent-capture_test.lua` |
| System-wide trigger | `home/.local/bin/nvim-tangent-capture` |
| Editor resolution shared with the daily note | `home/.local/lib/nvim-editor-socket.sh` |
| OS hotkey registration | `patches/apply-cinnamon-note-keybindings.sh` |
| WezTerm binding | `home/.config/wezterm/wezterm.lua` |

## How the system-wide trigger finds your editor

`nvim-tangent-capture` resolves, in order:

1. `$NVIM` — we are inside nvim's `:terminal`.
2. The tmux pane running nvim, attached and focused panes first, matched by
   **process ancestry**.
3. Any editor whose process tree reaches a terminal, newest first.
4. Nothing: start one.

The ancestry rule is not decoration. On this build nvim is a client-server
program (`:h tui.txt`): running `nvim` starts a builtin UI client, which starts
a `nvim --embed` server child that loads the config, holds the buffers, and owns
the socket. So the process holding the terminal has no socket, and the process
holding the socket has no controlling terminal — it looks exactly like an
unrelated hidden `nvim --embed` that other tooling may spawn, and a float opened
in one of those is invisible. Matching a socket to the pane's process tree
(pane → client → server) is what makes the choice exact.

`--diagnose` prints that decision without capturing anything, which is the tool
to reach for when a hotkey seems to do nothing:

```sh
nvim-tangent-capture --diagnose
```

A fresh nvim restarts the module; an editor started before this was installed
answers to none of it and is reported as such:

```
tmux %1 pid 6978 (rank 1) -> /run/user/1001/nvim.148565.0 pid 148565
  /run/user/1001/nvim.148565.0: answered, but has no :TangentCapture (started before this was installed?)
```

## Why the write is shaped this way

- **Buffer when the target is open, file when it is not.** Writing the file
  under a loaded buffer leaves that buffer stale, and its next `:w` silently
  reverts the tangent; when the file *is* open the text is appended through the
  buffer and written with it, so pending edits survive too.
- **Temp file plus rename.** A crash between `<CR>` and the bytes landing can
  never leave a truncated note. `writefile`'s 0644 is corrected to the note's own
  mode first, because `rename` replaces the inode.
- **Insert mode is restored.** Insert mode is not per-window, so closing a float
  that was typing does not clear it and the note underneath would start
  swallowing keystrokes. `close_float` leaves insert mode unless the capture
  started from insert (which the RPC entry point can).
- **Nothing else moves.** The float is its own scratch buffer, nothing is
  yanked, and the write uses `nvim_buf_set_lines` — no register, mark, jumplist
  entry, undo state, or cursor position of the note you were in is touched. The
  self-check asserts each of those.

## Install and verify

`./install.sh` deploys the Lua module and the scripts (stow). The three note
hotkeys live outside the repo, in dconf, and one script manages all of them:

```sh
./patches/apply-cinnamon-note-keybindings.sh            # register <Super>t and friends
./patches/apply-cinnamon-note-keybindings.sh --check    # already part of ./smoke.sh
./patches/apply-cinnamon-note-keybindings.sh --remove   # unbind
```

`<Super>t` keeps the slot it always had (`custom2`); `<Super>d` and `<Super>a`
took the next free ones. See `docs/guide/daily-note.md` for the other two.

Then **restart nvim** — the module is loaded at startup.

```sh
nvim --headless -u NONE -i NONE -l home/.config/nvim/lua/custom/tangent-capture_test.lua
nvim-tangent-capture --diagnose
./smoke.sh
```
