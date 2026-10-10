# clipboard history — `<Super>v`, and why it needs an autostart entry

CopyQ keeps a searchable history of everything you copy. `<Super>v` shows or
hides it, from anywhere in the Cinnamon session.

## Triggers

| Trigger | Where | What it does |
|---|---|---|
| `<Super>v` | anywhere in the Cinnamon session | show or hide the history window |
| `copyq toggle` | any shell | the same, from a terminal |
| `<Super>t` | `<Super>d`, `<Super>a` | the note hotkeys, unrelated |

## The two things that have to be true

A bound key by itself is not the feature. Both of these have to hold, and
`patches/apply-cinnamon-copyq-keybinding.sh --check` verifies both:

1. **The keybinding.** Cinnamon custom keybinding slots are numbered
   (`custom1`, `custom2`, ...) and the live list of them is a *separate* key,
   `org.cinnamon.desktop.keybindings custom-list`. A slot that is configured but
   missing from that list is inert and looks configured. The script owns both,
   and finds the slot by the command it runs, so reordering `custom-list` by
   hand does not strand the binding.
2. **The autostart entry.** With no CopyQ instance running, `copyq toggle` exits
   1 with `Cannot connect to server!`. A bound key alone therefore produces a
   hotkey that silently does nothing after the next login, which reads as "the
   hotkey broke" rather than "CopyQ is not running". The entry is deployed by
   stow from `home/.config/autostart/copyq.desktop`.

That second half is why the drag of a bad `--check` is worth it: the failure is
invisible at the moment you configure it and only appears at the next reboot.

## Applying

```bash
patches/apply-cinnamon-copyq-keybinding.sh            # register (default)
patches/apply-cinnamon-copyq-keybinding.sh --check    # exit 1 if not registered
patches/apply-cinnamon-copyq-keybinding.sh --remove   # unbind and drop the slot
```

Cinnamon reads dconf live, so no reload is needed and the key works
immediately. `--remove` unbinds the key only; the autostart entry is stow's, and
leaving it in place is usually what you want anyway.

`smoke.sh` runs `--check` whenever `copyq` is on `PATH`. Unlike the note
keybindings, this one is guarded: on a fresh clone with no CopyQ installed there
is nothing to check, and a hard failure would be wrong.

## Choosing the key

`<Super>v` is free. No gsettings keybinding schema on this machine (Cinnamon,
muffin, GNOME, media-keys) binds it, and nothing under
`/usr/share/glib-2.0/schemas` mentions it. The used `Super`+letter keys are
`c d e h l o p s`, all services you would not want to shadow anyway.

One collision is worth knowing about and is **not** introduced by this feature:
`<Super>d` is also bound by `org.cinnamon.desktop.keybindings.wm show-desktop`.
The note hotkeys take that key anyway, so in practice the custom binding wins.

## CopyQ's own footprint

CopyQ is installed from the distro archive and its history lives in
`~/.local/share/copyq/`, which home-git (`docs/guide/home-git.md`) does version.
Nothing the hotkey writes is repo state.
