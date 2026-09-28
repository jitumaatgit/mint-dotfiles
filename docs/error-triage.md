# Error triage

Defects found while investigating, and things still open. Fixed items stay here
so the same bug is not rediscovered later.

Status: `fixed` = corrected, `open` = still present, `decided` = consciously
left alone.

## checkmate_notify.nvim (removed 2026-09-28)

The in-editor `@due` notifier. Replaced by
[`checkmate-due-notify`](checkmate-due-notify.md) + a systemd timer, so these
are closed by removal rather than patched.

| # | Error | Root cause | Status |
|---|---|---|---|
| 1 | `checkmate_notify.lua:115: bad argument #2 to 'fmt' (number expected, got nil)` | A table constructor evaluates **all** values before indexing: `({ overdue = "...", advance = fmt("DUE in %d sec: ", warning) })[state]` ran `fmt` with `nil` on every call, including `notify_task(t, "overdue")`. The feature had never sent a single notification. | fixed (module deleted) |
| 2 | `parse_due`: `field 'day' missing in date table` | `@due(today)` left `year`/`month`/`day` as `nil`, which `os.time` rejects. The throw propagated out of `scan_buffer` → `gather_tasks` → one deferred callback, so **one** malformed line aborted the entire vault scan. | fixed (parser returns `None` and warns) |
| 3 | No done-state filter | Every line containing `@due` was treated as live. 8 of the 10 dated `@due` in the vault were on `- [x]` lines and 1 on `- [-]`, all past-dated — fixing #1 alone would have produced a burst of alerts for finished work. | fixed (only `[ ]` alerts) |
| 4 | Priority sent as the ntfy **title**; JSON body stored verbatim | `priority_map` values (`high`/`low`/`default`) were passed as `?title=`, so priority was never sent and the notification would have been titled the word "high". The `{"message":...}` body was posted to the topic URL, which ntfy stores as raw text — the fields were ignored. Reproduced live: the notification arrived as a literal JSON string with `title: None`, `priority: None`. | fixed (headers to topic URL) |
| 5 | Dedup key was `bufnr:line` | Inserting a line above a task shifted every task below it, re-alerting all of them. | fixed (sha1 of path + due + description) |
| 6 | `due` state unreachable | `priority_map.due` and the `"DUE NOW: "` branch were never produced; `schedule_check` only ever emitted `overdue` and `advance`. | fixed (removed) |
| 7 | `api.nvim_buf_get_option` deprecated | Removed in nvim 0.10; this config runs nvim 0.12.4. | fixed (module deleted) |
| 8 | Unbounded `uv` timer, never stopped on exit | `uv.new_timer()` at module scope, `timer:start` with no `VimLeave` teardown. | fixed (module deleted) |
| 9 | checkmate.nvim 0.12.1 has no `@due` engine at all | Grepping the plugin returns only "due to" in comments — no parser, scheduler or notifier. The module was a parallel hand-rolled implementation reading raw text, and only ever saw tasks in buffers nvim happened to have open. | decided (systemd timer instead) |

## Notes vault

| # | Item | Detail | Status |
|---|---|---|---|
| 10 | `@due(today)` / `@due(saturday)` shorthand | Unparseable, and the majority of real usage. Removed from `2026-09-03.md:69,72` and `2026-09-04.md:62`. `due` in `checkmate.lua:98` has no `get_value` or `choices`, so these came from free typing and will not regenerate. | fixed |
| 11 | `2026-09-19.md:66` — `template@due(2026-09-19)` | Missing space before the tag. Parses anyway (the regex is position-independent) but renders badly and Obsidian will not see it as metadata. | open |

## Open items outside the notifier

| # | Item | Detail | Status |
|---|---|---|---|
| 12 | `stow -t ~ -R home` prints `BUG in find_stowed_path? Absolute/relative mismatch` | Emitted for `/home/mint/.config/tmux/tmux.conf`, `/home/mint/.steam/steam.pid`, `/home/mint/.steam/sdk32/steam`. Exit status is 0 and the links are created correctly, so this is cosmetic noise from stow traversing symlinks that point outside the package. | open — cosmetic, worth suppressing in the stow invocation or ignoring |
| 13 | `~/notes/90-archive/prompts/20260921-024516.md:14` contains a literal `@due(YYYY-MM-DD HH:MM)` | Archived prompt text, not a task. Left alone: it is a historical record, and the notifier's task-line regex ignores prose, so it is harmless. | decided |
