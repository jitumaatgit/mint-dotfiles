# Tool errors

Failures hit while working on the `@due` notifier (2026-09-28), kept for triage.
Product defects from that investigation are in
[error-triage.md](error-triage.md) instead — this file is only about the
agent tooling misbehaving.

Verbatim messages, what caused them, and what to do instead.

## Summary for triage

| Tool | Error | Verdict |
|---|---|---|
| `edit` | `REM <path>` rejected: *"payload line has no preceding hunk header"* | My payload — `REM` takes no argument; the path argument was parsed as a body row |
| `edit` | Multi-file payload: only the first file's op applied | Not the cause — a cross-file regression, see below |
| `edit` | `CUT` followed by body rows: *"CUT ... takes no body rows"* | My payload — misrouted rows between files |
| `edit` | *"Auto-prefixed bare body row(s) with `+`"* then body applied at the wrong line | My payload — two `PUT >N` in one call, stale line numbers |
| `task` | *"Service mode does not accept async or timeout"* | My call — wrong combination, documented in the schema |
| `bash` | Session `.jsonl` not found after `cd` | My call — file is one level up |
| `bash` | `ipairs` on `nvim_exec2("messages").output` | My call — `.output` is a string, not a list |
| `bash` | `JSONDecodeError` on pretty-printed multi-record log | My stub's fault — record separator, not JSON lines |

None of the eight is a tool defect. The two originally filed as "Likely tool
bug" were re-checked against upstream source on 2026-09-28 and were both my
payload; see the `REM` and multi-file sections. One earlier conclusion *is* a
tool defect — a misleading error message from the seen-line guard, documented
under [The seen-line guard](#the-seen-line-guard) below.

## `edit`

### `REM <path>` — the argument is the bug

```
line 1: payload line has no preceding hunk header. Use `PUT N.=M:`,
`CUT N.=M`, or `PUT <N:`/`PUT >N:` above the body.
Got "REM /home/mint/mint-dotfiles/home/.config/nvim/lua/custom/checkmate_notify.lua"
```

`REM` takes **no argument**. The path comes from the `[path#tag]` header, so
`REM <path>` is a body row with no hunk header above it — the parser is
right and the payload was wrong. Upstream fixtures use bare `REM`
(`crates/pi-edit/src/session.rs:436`: `"[legacy.txt#FFFF]\nREM\n…"`), and
`patcher.rs:441` maps `FileOp::Rem` to `EngineFileOp::Delete`.

```
[/abs/path/to/file.lua#A1B2]
REM
```

The original repro also failed because the file had never been read, so
there was no tag to cite. This was misfiled as a tool defect on the
assumption that deletion was unsupported; it is not. `rm` was a valid
workaround but the conclusion "there is no way to delete a file through
the tool" was wrong.

**Correct form:** bare `REM` under a `[path#tag]` header for a file you
have already read.

### Multi-file payloads work — the original failure was the `REM` bug

This entry was wrong twice. It first blamed a parser that ignores later
`[path#tag]` headers, then (after finding the string *"Multiple entries in
one call apply to the top-level `path`*" in the binary) concluded that
multi-file payloads were unsupported. Both are wrong.

Retested 2026-09-28 against the current binary, two sections in one call:

```
[/tmp/xf-src.lua#8D5A]
PUT 2.=2:
-- touched
[/tmp/xf-dst.lua#32A5]
PUT 1.=1:
-- also touched
```

Both applied to their own file. The documented cross-file move
(`docs/tools/edit.md`) also works — `CUT 3.=5 @greet` followed by
`PUT <2 @greet` under a second header, verified.

The original failure was entirely `REM <path>`: the argument was a body
row with no hunk above it, and the parser reported the *first* line of
that row, which made it look like the later headers had been skipped.

The `path` string above refers to the JSON-schema modes (`patch`,
`replace`, `apply_patch`), which have a top-level `path` field — not to
hashline section headers.

**No workaround needed.** One file per call is not required.

### `CUT` takes no body

```
line 2: `CUT` deletes (and captures) the named lines and takes no body rows.
To write new content, use `PUT N.=M:` with `+TEXT` rows.
```

Fired when a `CUT` was followed by body rows intended for a different file.
Purely my payload's fault, but the message points at the second file's row
rather than the misplacement.

**Workaround:** `CUT`, `REM`, `MV` and register-pastes take no body rows.
Put the body under a `PUT ...:` header and keep each op inside its own
section — do not let one file's body rows fall under another file's
header.

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

## The seen-line guard

Not an error I hit, but the thing behind most of the friction in the table
above, and the one conclusion in this file that *is* a real tool defect.

`edit.enforceSeenLines` (default `true`) rejects an edit anchored to a line
that no prior read or search displayed in full. It is not in
`~/.omp/agent/config.yml` because it is a default; the setting lives at
`cfg://edit/enforceSeenLines`. The guard is good — editing a line you never
looked at is how files get mangled. The problem is that most of this config
made whole files "unseen" without saying so.

### The message is wrong

```
This edit anchors to lines 17-18 of /tmp/guard-probe.lua that
[/tmp/guard-probe.lua#67E2] never displayed (it showed a partial range, a
search hit, or a folded summary).
```

That is accurate. The misleading case is when the guard rejects a payload
that carries a body row before any hunk header — the `REM` row above. The
parser reports "no preceding hunk header" for a line the guard had already
flagged as unseen, which sends you hunting for a syntax problem that does not
exist. **Read the first line of the message before assuming a parse error.**

### The retry path, and why rejections are cheap

On rejection the tool reveals the *actual* file content at the offending
lines and records them as seen (`crates/pi-edit/src/modes/hashline/patcher.rs:123-186`).
So a straight retry of the identical payload succeeds **with no re-read**:

```
This edit anchors to lines 17-18 … never displayed … Actual file content at
those lines:
  17:end
  18:
Verify the content matches what you intend to touch, then re-issue the edit
with the same [path#tag] header — a straight retry now succeeds without a
re-read.
```

Verify the revealed content, then retry. If the reveal is itself truncated
(or empty) the message instead asks for a ranged read, and only then is a
re-read needed.

### What counts as seen

Recorded at render time into a session-scoped native store
(`EditStore`, `crates/pi-edit/src/store.rs`):

| Source | Counts as seen |
|---|---|
| `read` with a range selector, full file | the lines shown |
| `read` **without** a selector, file over `read.summarize.minTotalLines` | only the lines the summary left unfolded |
| `read` with `:raw` | the range displayed — `:raw` bypasses summarisation |
| `grep` / `ast-grep` hit | the context lines rendered around the hit |

The summary case is the one that bites: a 240-line `checkmate.lua` came back
as 50 lines with 190 elided, and every anchor in the elided spans was
rejected.

### What does *not* clear it

**Compaction does not.** The store is lazily created on the session object
(`packages/coding-agent/src/edit/store.ts:15-18`) and populated by
read/grep/ast-grep at render time; no compaction path calls `clear()` or
`invalidate()`. An earlier guess that `snapcompact.toolResults: false` would
wipe it was wrong — `toolResults` only controls what is kept in the
transcript, not the store.

**Auto-repair does, for that file.** When a broken edit is auto-repaired,
`packages/coding-agent/src/edit/index.ts:541` calls
`getEditStore(session).invalidate(path)`, which drops *every* version of that
path. After any syntax warning, the file must be re-read before editing it
again.

The real ceiling is LRU eviction, not compaction: `DEFAULT_MAX_PATHS: 256`,
`DEFAULT_MAX_VERSIONS_PER_PATH: 4`, `DEFAULT_MAX_TOTAL_BYTES: 64 MiB`
(`store.rs:14-20`).

### Settings changed on 2026-09-28

In `home/.omp/agent/config.yml`, to stop the truncation from starving the
guard. Kept `enforceSeenLines` on.

| Setting | Was | Now |
|---|---|---|
| `read.defaultLimit` | 200 | 500 |
| `read.summarize.minTotalLines` | 100 (default) | 500 |
| `grep.contextAfter` | 3 | 10 |
| `grep.contextBefore` | 1 | 5 |

Verified: `checkmate.lua` (240 lines) now reads back verbatim with no elided
spans.

**Working rules under the guard:** cite a tag from a read you actually did;
never compute line numbers from a read that has since been shifted by an
edit; after an auto-repair warning, re-read the file.

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
