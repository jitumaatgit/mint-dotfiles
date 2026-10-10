# daily note — going to today, and catching what lands in it

Two keystrokes, both about today's daily note. One takes you there whether or
not it is already open; the other puts a task or a log line into it while you
are looking at something else.

The tangent capture (`docs/guide/tangent-capture.md`) is the sibling feature and
shares its whole write path. What this page adds is the *other* half of the day:
the note itself.

## Triggers

| Trigger | Where | What it does |
|---|---|---|
| `<Leader>d` | inside wezterm | go to today's note |
| `<Leader>D` | inside wezterm | float for a task or log entry |
| `<Super>d` | anywhere in the Cinnamon session | go to today's note |
| `<Super>a` | anywhere in the Cinnamon session | float for a task or log entry |
| `<Leader>nD` | inside nvim | go to today's note |
| `<Leader>nA` | inside nvim | float for a task or log entry |
| `:DailyNote` | inside nvim | go to today's note |
| `:DailyNoteCapture [task\|log]` | inside nvim | the same float, optionally starting in one mode |
| `nvim-daily-note [capture]` | any shell | what the two system-wide hotkeys run |

`<CR>` saves and closes; `<Esc>` and `<C-c>` close and change nothing. `<Tab>`
switches the float between task and log, and the border says which one the next
keystroke will be.

## Going to the daily note

`:DailyNote` and `nvim-daily-note` look for the note rather than assuming it
needs opening:

1. **A window already showing it** — that window is focused. This is the whole
   requirement: `:edit` on an already-displayed note would leave the same buffer
   in two windows at once, and the second view would then diverge from the first
   on the next save. Any tabpage counts, because a note opened earlier today is
   usually still sitting in whatever tab you left it in.
2. **A loaded buffer in no window** — it is put in the current window.
3. **Nothing at all** — obsidian.nvim creates today's note, applying the vault's
   folder, frontmatter and template rules, and opens it. This is the same path a
   capture uses, so a cold start cannot produce a note without a `## Log`.

`nvim-daily-note` with no editor running starts one whose only job is the note,
and it stays open: unlike the capture float, there is nothing to return to.
With a shell it takes over the current terminal; otherwise it spawns a wezterm
window.

### What the hotkey does to your windows

Pressing `<Super>a` or `<Super>d` while an nvim is already running means the
note's window comes to the front and the float opens there — never a second
window. That is two separate lookups, because the editor and the window holding
it are found by different means:

1. **Inside nvim**, the window (in any tabpage) already showing the note is
   focused, and the float opens on it. A note left open in another split or tab
   is the note the hotkey means; a float that appears somewhere else looks like
   the hotkey did nothing, while the entry still lands silently.
2. **Outside nvim**, the terminal window holding that editor is raised. tmux
   panes are selected first, then the X window is activated; `wezterm cli
   activate-pane` cannot do this part, because it only acts inside the *focused*
   GUI window and leaves the X11 focus where it was.

A new window appears only when no editor can be reached at all, and it takes
focus on its own — that is the feedback. Every other outcome is reported with
a desktop notification, because a keybinding has no terminal to print to and a
capture that lands in a background window is indistinguishable from one that
never happened. The notification says which of the two happened, and a failure
says why.

Limitation worth knowing: the X window is found by its name, which wezterm sets
to the title of the tab it is showing. If two visible windows are titled the
same, the raise is skipped rather than guessed at, and the notification reports
what happened.

## Catching a task or a log entry

One float, two modes. `<Tab>` switches between them and the border label
follows:

```
╭─ Task > ─────────────────────────────────╮
│ call VOA back about 503-802-9101          │
╰───────────────────────────────────────────╯
```

Where the entry goes is not a choice in the UI — it is which mode the float is
in, and each mode has a fixed destination, so a keystroke never needs a
decision:

| Mode | Section | Shape |
|---|---|---|
| Task | `#### Tasks` (under `### To-Do`) | `- [ ] call VOA back about 503-802-9101` |
| Log | `## Log` | `- **17:29** read for an hour` |

The shapes are the vault's, not this feature's invention:

- A task is a **checkbox**, because that is what the rest of the tooling reads.
  `task-auto-complete.lua` moves `- [x]` lines into `## Completed` and stamps
  them on save, and `obsidian-task-filter.lua` greps `- [ ]`.
- A log line carries the **clock and not the date**. The section already sits
  under a dated note, and every existing entry reads `- **17:29** ...`. The
  timestamp is local time, for the reason the tangent capture gives: the
  filename and every neighbouring `## Log` stamp are local, and a UTC stamp
  would date an evening line to the next day.

`nvim-daily-note capture task` and `nvim-daily-note capture log` open the float
already in that mode, for a shell binding or a script that knows which it wants.
Bare `task` or `log` is shorthand for the same.

## Where the rules live

A task does not go under `#### Tasks` by accident. The section is found by its
exact heading text and the search stops at the next heading of the same or a
higher level, so `#### Tasks` runs to the `## Notepad` that follows it and not
into the section above. The entry lands after the **last non-blank line** of
the section, so a trailing `### Goal: <name>` heading keeps capturing entries
and the blank line before the next `##` stays put. A missing section is created
at the end of the file.

The date is resolved by obsidian.nvim when it is loaded, because it owns
`daily_notes.folder` and `daily_notes.date_format`; the module mirrors that
stanza for sessions that never load the plugin.

## Configuration

| `g:` variable | Default | Effect |
|---|---|---|
| `daily_note_task_heading` | `#### Tasks` | Section a task lands in. |
| `daily_note_log_heading` | `## Log` | Section a log entry lands in. |
| `daily_note_log_timestamp` | `1` | `0` writes the bare bullet, dropping `**HH:MM**`. |

Commands: `:DailyNote` (focus the note), `:DailyNoteCapture [mode]` (float),
`:DailyNoteCapture! [mode]` (float, quit when done — what a cold start runs).

## Layout

| What | Where |
|---|---|
| Float, insert rules, write path, RPC entry point | `home/.config/nvim/lua/custom/note-capture.lua` |
| Section choices, entry shapes, navigation | `home/.config/nvim/lua/custom/daily-note.lua` |
| Self-check | `home/.config/nvim/lua/custom/daily-note_test.lua` |
| System-wide triggers | `home/.local/bin/nvim-daily-note`, `home/.local/lib/nvim-editor-socket.sh` |
| OS hotkey registration | `patches/apply-cinnamon-note-keybindings.sh` |
| WezTerm bindings | `home/.config/wezterm/wezterm.lua`, self-check in `note_keys_test.py` |

## How the system-wide trigger finds your editor

`nvim-daily-note` resolves an editor exactly as `nvim-tangent-capture` does,
because both live in `home/.local/lib/nvim-editor-socket.sh`: `$NVIM`, then the
tmux pane running nvim (matched by process ancestry, pane → client → server),
then any editor with a terminal, then none. The full rationale for why that is
the only thing that works on a client-server nvim is in
`docs/guide/tangent-capture.md`.

```sh
nvim-daily-note --diagnose              # which editor it would use, without acting
nvim-daily-note capture --diagnose      # same, for the capture float
```

## Install and verify

```sh
./patches/apply-cinnamon-note-keybindings.sh            # register all three hotkeys
./patches/apply-cinnamon-note-keybindings.sh --check     # already part of ./smoke.sh
./smoke.sh
```

Then **restart nvim** — the module is loaded at startup.

```sh
nvim --headless -u NONE -i NONE -l home/.config/nvim/lua/custom/daily-note_test.lua
nvim-daily-note --diagnose
```
