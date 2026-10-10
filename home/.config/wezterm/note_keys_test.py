#!/usr/bin/env python3
"""Test that the note-workflow events and keybindings really load.

Run directly:  python3 home/.config/wezterm/note_keys_test.py
Or via ./smoke.sh at the repo root, which is the path that actually gets run.

The vertical tangent capture already proved the shape (an event handler that
runs a script, plus the leader binding that emits it). These checks exist
because the new daily-note bindings sit in the same table as a dozen others,
where two things fail silently:

  1. A keybinding that names an event with no `wezterm.on` handler does nothing
     at all -- no error, no output, and nothing to notice from the terminal.
  2. Two bindings claiming the same key combination. wezterm resolves the
     conflict by keeping the first, so adding `<leader>d` on top of something
     that already owns it silently disables one of the two.

Both are checked against the config as it ACTUALLY loads, not as it reads in the
source, so a Lua typo that changes the table is caught here too.

lua5.1 with a stub stands in for the real runtime: quick_select_test.py uses the
same technique, and the config only needs `wezterm.on`, `wezterm.action.*` and
the `config` table to be evaluated.
"""
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent

# A stub good enough to evaluate wezterm.lua outside wezterm: every unknown
# wezterm.foo.bar is a function returning a table, which covers both
# wezterm.action.SendString(...) and wezterm.on(...). `on` is intercepted so the
# registered event names can be asserted.
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
local registered = {}
local stub = setmetatable({
  on = function(name)
    registered[#registered + 1] = tostring(name)
  end,
}, { __index = member })
package.loaded.wezterm = stub
local ok, config = pcall(dofile, "wezterm.lua")
if not ok then io.stderr:write(tostring(config) .. "\n") os.exit(1) end
io.write("EVENTS\t" .. table.concat(registered, ",") .. "\n")
for _, k in ipairs(config.keys or {}) do
  io.write(string.format("KEY\t%s\t%s\t%s\n", tostring(k.key), tostring(k.mods),
    tostring(k.action and k.action[1] or "?")))
end
-- AND every keybinding's combination, for the duplicate check.
local seen = {}
for _, k in ipairs(config.keys or {}) do
  local sig = tostring(k.key) .. "+" .. tostring(k.mods)
  io.write("SIG\t" .. sig .. "\n")
end
"""


def load():
    """Ask Lua for the events and keybindings the config really produces."""
    stub = HERE / ".note_keys_stub.lua"
    stub.write_text(LUA_STUB)
    try:
        out = subprocess.run(
            ["lua5.1", stub.name], cwd=HERE, capture_output=True, text=True,
            check=True,
        ).stdout
    except FileNotFoundError:
        sys.exit("lua5.1 not installed; cannot verify the Lua config")
    finally:
        stub.unlink(missing_ok=True)

    events, keys, sigs = [], [], []
    for line in out.splitlines():
        parts = line.split("\t")
        if parts[0] == "EVENTS":
            events = [e for e in parts[1].split(",") if e]
        elif parts[0] == "KEY":
            keys.append((parts[1], parts[2], parts[3]))
        elif parts[0] == "SIG":
            sigs.append(parts[1])
    return events, keys, sigs


failed = 0


def check(what, got, want):
    global failed
    if got == want:
        print(f"ok    {what}")
    else:
        print(f"FAIL  {what}\n        got  {got}\n        want {want}")
        failed += 1


events, keys, sigs = load()

# --- events and their handlers exist ----------------------------------------

for name in ("tangent-capture", "daily-note", "daily-note-capture"):
    check(f"event registered: {name}", name in events, True)

# --- each binding emits the event that matches its name --------------------

def emits(key, mods, event):
    return any(k == key and m == mods and e == event for k, m, e in keys)

check("LEADER d emits daily-note", emits("d", "LEADER", "daily-note"), True)
check("LEADER SHIFT D emits daily-note-capture",
      emits("D", "LEADER|SHIFT", "daily-note-capture"), True)
check("LEADER SHIFT T still emits tangent-capture",
      emits("T", "LEADER|SHIFT", "tangent-capture"), True)

# --- no two bindings may claim one key combination --------------------------

dupes = sorted({s for s in sigs if sigs.count(s) > 1})
check("no duplicate keybinding", dupes, [])

print("\nAll wezterm note-keybinding checks passed." if not failed
      else f"\n{failed} check(s) FAILED.")
sys.exit(1 if failed else 0)
