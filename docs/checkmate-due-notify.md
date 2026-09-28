# checkmate-due-notify

Pushes `@due` task alerts from the notes vault to [ntfy](https://ntfy.sh).

Runs from a systemd user timer every 15 minutes and reads the vault from disk.
This replaced an in-editor Neovim module (`custom.checkmate_notify`), which
could only see tasks in buffers nvim happened to have open — and which never
successfully sent a notification at all. See
[error-triage.md](error-triage.md) for the full list of what was wrong.

## What it does

- Walks the vault for markdown files, skipping `.git`, `.obsidian` and friends.
- Matches **task lines only** — a bullet plus a checkbox. `@due(...)` mentioned
  in prose (archived prompts, spec docs) is ignored.
- Alerts only for unchecked tasks: `[ ]`. `[x]`, `[X]`, `[-]` and progress
  states like `[/]` are skipped.
- Parses `@due(YYYY-MM-DD)` and `@due(YYYY-MM-DD HH:MM)`. Anything else is
  warned about on stderr and skipped; it never aborts the scan.
- Publishes one ntfy message per newly-overdue task, with the title, priority
  and tags in HTTP headers.
- Records what it has sent, so re-runs do not re-alert. State is written after
  each individual send, so a crash mid-run cannot cause duplicates or losses.

## Usage

```sh
checkmate-due-notify --dry-run     # list what would be sent, send nothing
checkmate-due-notify               # the real thing
checkmate-due-notify --repost      # ignore dedup state, alert again
checkmate-due-notify --show-topic  # print the configured topic URL
```

Useful overrides: `--vault PATH`, `--topic NAME`, `--server URL`.

## Configuration

`~/.config/checkmate-due-notify/config.json`, created on first run with a
random, unguessable topic. ntfy topics are effectively passwords — anyone who
guesses the name can read every alert.

Never commit a real topic name. An ntfy topic is the only thing protecting the
alerts on a public server, so treat it as a credential.

```json
{
  "vault": "/home/mint/notes",
  "server": "https://ntfy.sh",
  "topic": "due-<random hex, generated on first run>",
  "priority": "high",
  "tags": ["warning", "clock"]
}
```

Optional keys: `token` (or the `NTFY_TOKEN` env var) for a private topic, and
`ignore_globs` to skip paths. Dedup state lives in
`~/.local/state/checkmate-due-notify/state.json` and is pruned after a year —
a task still open past that age is deliberately re-alerted.

## Subscribing

```sh
ntfy subscribe https://ntfy.sh/due-<your-topic>
```

For desktop popups, add the topic to `~/.config/ntfy/client.yml` under
`subscribe:` — the `ntfy-client.service` unit already runs
`ntfy subscribe --from-config`.

## systemd

```sh
systemctl --user status  checkmate-due-notify.timer
systemctl --user start   checkmate-due-notify.service   # run once now
journalctl --user -u checkmate-due-notify.service -n 20
systemctl --user disable --now checkmate-due-notify.timer
```

`Persistent=true` means a run is triggered on login if one was missed while the
machine was asleep or off.

## Writing tasks

```markdown
- [ ] file the SNAP renewal @due(2026-09-21)
- [ ] call the clinic @due(2026-09-28 14:30) @priority(high)
- [x] already done @due(2026-09-01)      <- never alerts
```

Always write a real date. `@due(today)` and `@due(saturday)` are not supported.
`<leader>td` in Neovim inserts the `due` metadata tag.

## ntfy publishing quirk

ntfy only parses a JSON request body when it is POSTed to the **root** URL. A
JSON body POSTed to `/<topic>` is stored verbatim as the message text — the
`title`, `priority` and `tags` fields are silently ignored. This script posts
the message as the body to the topic URL with `Title`, `Priority` and `Tags`
headers, which works against any ntfy deployment.

## Other senders

The topic is shared, so anything can push to it as long as it can read the
config file. `pomo.nvim` already does: `lua/plugins/pomo.lua` registers a
custom notifier through pomo's `{ init = factory }` hook, so a finished work
or break timer reaches the phone even while Neovim sits in the background.
It sends the timer name, its duration and the repetition count.

Note that pomo's `timers.<Name>` list *replaces* `notifiers` wholesale rather
than extending it, so a per-timer override has to repeat the ntfy entry or
that timer stays local.

## Notification sounds

Two separate paths, both needed:

| Where | What | Configured in |
|---|---|---|
| In-editor popups | every notification nvim-notify displays, whoever raises it | `lua/custom/notify-sound.lua` |
| ntfy popups | every message on any subscribed topic | `~/.config/ntfy/desktop-notify.sh` |

The in-editor hook wraps the **nvim-notify module's** `notify` function, not
`vim.notify`. Do not "simplify" it to wrap `vim.notify`: LazyVim replaces
`vim.notify` with a buffer that collects notifications until the real notifier
is installed and then replays them, and a wrapper installed at that moment
captures the buffer. Every replayed notification then re-enters it, so the
replay never terminates — that produced tens of thousands of stuck sound
players and took the machine down. The module field is untouched by the swap,
so there is no ordering to get right.

Wrapping the module also means pomo, which calls `require("notify").notify()`
directly and so never went through `vim.notify`, now sounds as well.

Set `vim.g.notify_sound_disabled = true` to mute. `DEBUG`-level notifications
are silent. Players are spawned under `timeout 5` and at most one per 200 ms,
so neither a blocked audio device nor a burst of alerts can pile up processes.

### Stacking

nvim-notify opens one floating window per message, so distinct notifications
already stack — the installed version has no queue option at all. Two separate
things were collapsing them into fewer windows:

- `merge_duplicates` (default `true`) folds repeated *identical* messages into
  a single popup, which hides the fact that they repeated. Set to `false`, so
  three identical notifications produce three popups.
- pomo's default notifier passes `replace = self.notification`, so a running
  timer updates one popup in place rather than adding one per tick. That is
  deliberate: its notifier fires every second, so stacking would flood.

Popups also disappear after `timeout` (5000 ms) unless raised sticky, so a
burst is only on screen for that long. On a short terminal a stack can run out
of rows, in which case further notifications wait for a slot.

### Choosing a sound

`desktop-notify.sh` picks its sound from the tags the publisher set. ntfy-client
exports each message's fields as environment variables to the subscribed
command, so `NTFY_TAGS` is available for free and publishers need no local
config to match:

| Tag | Sound | Sent by |
|---|---|---|
| `alarm_clock` | `alarm-clock-elapsed.oga` | pomo timer completions |
| `warning` | `bell.oga` | checkmate overdue tasks |
| anything else | `dialog-information.oga` | everything else |

The first match wins, so `alarm_clock` is checked before `warning`. The checkmate
sound follows the `tags` list in `config.json`; drop `warning` from there and it
falls back to the generic blip. `NTFY_SOUND` overrides the choice entirely.

Files come from `/usr/share/sounds/freedesktop/stereo/`. The sound is played
after the popup is queued and in the background, so a missing sound device can
neither delay nor suppress the notification.
