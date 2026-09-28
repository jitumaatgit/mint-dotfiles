# Tool errors

Failures hit while working on the `@due` notifier (2026-09-28), kept for triage.
Product defects from that investigation are in
[error-triage.md](error-triage.md) instead — this file is only about the
agent tooling misbehaving.

Verbatim messages, what caused them, and what to do instead.

## Summary for triage

| Tool | Error | Verdict |
|---|---|---|
| `edit` | `REM <path>` rejected: *"payload line has no preceding hunk header"* | **Likely tool bug** — `REM` is documented for file deletion but is not parsed as a hunk, even as the only op |
| `edit` | Multi-file payload: only the first file's op applied | **Likely tool bug** — later `[path#tag]` headers ignored without a warning |
| `edit` | `CUT` followed by body rows: *"CUT ... takes no body rows"* | My payload — misrouted rows between files |
| `edit` | *"Auto-prefixed bare body row(s) with `+`"* then body applied at the wrong line | My payload — two `PUT >N` in one call, stale line numbers |
| `task` | *"Service mode does not accept async or timeout"* | My call — wrong combination, documented in the schema |
| `bash` | Session `.jsonl` not found after `cd` | My call — file is one level up |
| `bash` | `ipairs` on `nvim_exec2("messages").output` | My call — `.output` is a string, not a list |
| `bash` | `JSONDecodeError` on pretty-printed multi-record log | My stub's fault — record separator, not JSON lines |

Two of the eight are plausibly defects in the `edit` tool itself. Both are
reproduced first below.

## `edit`

### `REM` is not recognised as a hunk

```
line 1: payload line has no preceding hunk header. Use `PUT N.=M:`,
`CUT N.=M`, or `PUT <N:`/`PUT >N:` above the body.
Got "REM /home/mint/mint-dotfiles/home/.config/nvim/lua/custom/checkmate_notify.lua"
```

`REM <path>` is documented for deleting a file, but it was rejected in a
payload that also carried other ops, and again when it was the only op.
Tried three times with the same result.

Minimal repro — one op, nothing else in the payload:

```
[/abs/path/to/file.lua#A1B2]
REM /abs/path/to/file.lua
```

Expected: file deleted. Actual: the error above. Tried and rejected
identically: `REM` with a relative path, `REM` with no `[path#tag]` header
line, and `REM` as the trailing op of a multi-file payload. There is
currently no way to delete a file through the tool.

**Workaround:** `rm` the file, then verify with `ls`/`grep` that nothing
references it. Also removes any live symlink that now dangles.

### Multiple files in one payload do not parse

Mixing a hunk for `init.lua` with `REM` lines for two other files in a single
`input` produced the "no preceding hunk header" error above, i.e. the parser
never saw the second and third `[path#tag]` headers. Only the first file's op
was applied.

**Workaround:** one file per `edit` call, even when the change is trivial.

### `CUT` takes no body

```
line 2: `CUT` deletes (and captures) the named lines and takes no body rows.
To write new content, use `PUT N.=M:` with `+TEXT` rows.
```

Fired when a `CUT` was followed by body rows intended for a different file.
Purely my payload's fault, but the message points at the second file's row
rather than the misplacement.

**Workaround:** keep ops in separate calls; do not interleave.

### Bare body rows get silently auto-prefixed

```
Warnings:
Auto-prefixed bare body row(s) with `+`. Body rows must be `+TEXT` literal lines.
```

A body row written as `- item` (literal markdown) or as a bare indented line
is auto-prefixed. That is convenient, but combined with `PUT >N` at a computed
line number it applied the body to the **wrong place**: a `PUT >159` and a
`PUT >204` intended for `main()` landed at lines 191 and 239, inside `scan()`
and `publish()`, leaving a stray `return f"{days}d"...` mid-function.

**Workaround:** never chain two `PUT >N` insertions in one call. Insert one,
re-read to get fresh line numbers, then insert the next. Always `python3 -c
'ast.parse(...)'` or an equivalent syntax check after a multi-insert edit on
a script — this one only surfaced because the syntax check was run.

## `task`

### `async` is rejected for service mode

```
Service mode does not accept async or timeout; use ready.timeout for readiness.
```

A long-running background server was requested with `async: true` plus a
`ready` block.

**Workaround:** drop `async` and use `ready: { port: 8899, timeout: 10 }`, which
is what service mode is for. (`async: true` is fine for a finite job.)

## `bash`

### Session transcript not found after `cd`

```
FileNotFoundError: [Errno 2] No such file or directory:
'2026-09-21T11-49-21-941Z_01a0c3cc-....jsonl'
```

The `~/.omp/agent/sessions/<project>/` directory holds the `.jsonl` one level
*above* it, not inside it. Running `ls` there first showed only logs and
`local/`.

**Workaround:** list the directory, then open the path `ls` actually reported.

### `messages` output is a string, not a list

```
E5113: Lua chunk: bad argument #1 to 'ipairs' (table expected, got string)
```

`nvim_exec2("messages", { output = true }).output` is a plain string. Iterating
it with `ipairs` errors.

**Workaround:** print it directly, or `vim.split(out, "\n")`.

### Multi-line JSON in a log file cannot be read line by line

A local HTTP stub appended pretty-printed JSON records separated by `}\n{`.
Both `json.loads` per line and a `raw_decode` cursor loop failed on the
`}\n{` boundary.

**Workaround:** `json.loads("[" + raw.replace("}\n{", "},{") + "]")`, or have
the stub write one compact record per line in the first place.

## `read`

No failures. Every `read` this session succeeded, including `history://`,
`artifact://30` (a 1576-line page) and `:line-range` selectors.

Worth noting as a real limitation rather than an error: a `read` of a file
elides content (`...97ln elided`) and the tool then requires an explicit range
re-read. Line numbers in the elided display are still accurate, which is what
made the `checkmate_notify.lua` analysis reliable.

## `stow` (not a tool error, but noisy)

```
BUG in find_stowed_path? Absolute/relative mismatch between Stow dir
mint-dotfiles and path /home/mint/.config/tmux/tmux.conf
```

`stow -t ~ -R home` emits this for `tmux.conf` and for Steam files, then exits
0 with all links created correctly. Cosmetic, from stow traversing symlinks
that point outside the package. Tracked as item 12 in
[error-triage.md](error-triage.md).
