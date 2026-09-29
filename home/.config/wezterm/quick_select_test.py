#!/usr/bin/env python3
"""Test for config.quick_select_patterns in wezterm.lua.

Run directly:  python3 home/.config/wezterm/quick_select_test.py
Or via ./smoke.sh at the repo root, which is the path that actually gets run.

Two things are checked, and the first one is the reason this file exists.

1. The patterns as they ACTUALLY LOAD, not as they appear in the source. They
   are Lua long strings, and a pattern ending in "]" has to be written with a
   doubled bracket -- "[==[...[\\w+-]]==]" -- because the pattern's own closing
   bracket otherwise merges into the delimiter. Get that wrong and Lua does not
   error: it scans past the end of the line, swallows the entries that follow
   until it stumbles on a later "]]==]", and every pattern after the bad one is
   silently wrong. `luac -p` passes on the broken file. Only loading the config
   and comparing catches it, which is what LUA_STUB below is for.

2. That those patterns match what they are supposed to. wezterm compiles the
   whole list into ONE alternation and scans left to right, so the first
   alternative matching at a position wins regardless of which pattern "ought"
   to be longer. Ordering is therefore behavioural, not cosmetic, and is pinned
   by the sample lines below.

Python's re stands in for wezterm's fancy-regex. These patterns only use
fixed-width lookbehind, which both support, so it catches syntax errors, bad
ordering, and over-matching -- which is what actually goes wrong.
"""
import ast
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent

# A stub good enough to evaluate wezterm.lua outside wezterm: every unknown
# wezterm.foo.bar is a function returning a table, which covers both
# wezterm.action.SendString(...) and wezterm.on(...).
LUA_STUB = r"""
package.path = "./?.lua;" .. package.path
local function member()
  return setmetatable({}, {
    __call = function(_, ...)
      local t = {}
      for i = 1, select("#", ...) do t[i] = select(i, ...) end
      return t
    end,
    __index = function() return member() end,
  })
end
package.loaded.wezterm = setmetatable({}, { __index = member })
local ok, config = pcall(dofile, "wezterm.lua")
if not ok then io.stderr:write(tostring(config) .. "\n") os.exit(1) end
local pats = config.quick_select_patterns
if type(pats) ~= "table" or #pats == 0 then
  io.stderr:write("quick_select_patterns missing or empty\n") os.exit(1)
end
for i, p in ipairs(pats) do io.write(string.format("%03d\t%s\n", i, p)) end
"""


def load_patterns():
    """Ask Lua for the patterns the config really produces."""
    stub = HERE / ".quick_select_stub.lua"
    stub.write_text(LUA_STUB)
    try:
        out = subprocess.run(
            ["lua5.1", stub.name, "wezterm.lua"],
            cwd=HERE, capture_output=True, text=True, check=True,
        ).stdout
    except FileNotFoundError:
        sys.exit("lua5.1 not installed; cannot verify the Lua config")
    finally:
        stub.unlink(missing_ok=True)
    lines = [l for l in out.splitlines() if l.strip()]
    return [l.split("\t", 1)[1] for l in lines if "\t" in l]


# (line, expected matches) -- the second half are lines that must match NOTHING.
SAMPLES = [
    ("/etc/fstab", ["/etc/fstab"]),
    ("~/notes/todo.md is late", ["~/notes/todo.md"]),
    ("  ./src/main.rs:42:9", ["./src/main.rs:42:9"]),
    ("cp a.lua b.lua", ["a.lua", "b.lua"]),
    ("EDITOR=nvim PATH=/usr/bin ok", ["EDITOR=nvim", "PATH=/usr/bin"]),
    ("error[E0308]: mismatched types", ["error[E0308]"]),
    ("   error TS2304: Cannot find", ["error TS2304"]),
    ("ERR_MODULE_NOT_FOUND thrown", ["ERR_MODULE_NOT_FOUND"]),
    ("id 550e8400-e29b-41d4-a716-446655440000", ["550e8400-e29b-41d4-a716-446655440000"]),
    ("listening on 192.168.1.42:8080", ["192.168.1.42:8080"]),
    ("built 2026-09-29T13:04:11Z", ["2026-09-29T13:04:11Z"]),
    ("on 2026-09-29 at noon", ["2026-09-29"]),
    ('say "hello world" now', ['"hello world"']),
    ("cargo build --release", ["cargo build --release"]),
    ("git commit -m 'fix: thing'", ["git commit -m", "'fix: thing'"]),
    ("run `make all` first", ["`make all`"]),
    # --- must not produce junk ---
    ("the cat sat on the mat", []),
    ("for example, e.g. this one", []),
    ("a < b && b > c", []),
    ("2 + 2 = 4", []),
    ("password=hunter2 is not ENV", []),
    ("version 1.2.3 released", []),
    ("ratio is 3:4 here", []),
]

failed = 0


def check(what, got, want):
    global failed
    if got == want:
        print(f"ok    {what}")
    else:
        failed += 1
        print(f"FAIL  {what}\n        got  {got}\n        want {want}")


pats = load_patterns()
print(f"-- loaded {len(pats)} patterns from the live config")

for p in pats:
    # wezterm compiles the list into one alternation that itself uses capture
    # groups, so a capturing group inside a pattern would break the numbering.
    if re.search(r"(?<!\\)\((?!\?)", p):
        check(f"no capture group in {p!r}", "capture group found", "none")
    try:
        re.compile(p)
    except re.error as exc:
        check(f"compiles {p!r}", f"re.error: {exc}", "compiles")

check("pattern count", len(pats), 17)

rx = re.compile("|".join(f"(?:{p})" for p in pats))
for line, want in SAMPLES:
    check(repr(line), rx.findall(line), want)

print(f"\nAll quick-select checks passed." if not failed else f"\n{failed} check(s) FAILED.")
sys.exit(1 if failed else 0)
