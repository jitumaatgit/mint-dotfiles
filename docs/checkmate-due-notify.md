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
| In-editor popups | any `vim.notify`, so pomo, checkmate and LSP messages | `lua/custom/notify-sound.lua` |
| ntfy popups | every message on any subscribed topic | `~/.config/ntfy/desktop-notify.sh` |

The in-editor hook wraps `vim.notify` from nvim-notify's `config`, so it must
be installed after nvim-notify's own `setup()` or it gets overwritten. Set
`vim.g.notify_sound_disabled = true` to mute. `DEBUG`-level notifications are
silent.

Because nvim-notify is loaded by lazy.nvim, notifications raised in the first
few milliseconds of startup can fire before the hook is installed.

Both sounds default to `dialog-information.oga` in
`/usr/share/sounds/freedesktop/stereo/`; the ntfy one honours `NTFY_SOUND`.
