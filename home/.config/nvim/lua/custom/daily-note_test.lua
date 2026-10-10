-- Self-check for daily-note.lua. Run via ./smoke.sh at the repo root, or
-- directly with:
--   nvim --headless -u NONE -i NONE -l home/.config/nvim/lua/custom/daily-note_test.lua
--
-- `-u NONE` on purpose, like the tangent self-check: the modules are vanilla
-- Lua, so the checks run without LazyVim in the way, and `-i NONE` keeps the
-- register assertions meaningful. Nothing here writes to the real vault -- the
-- engine's append is stubbed out for the float checks and its daily-note
-- resolution is pointed at a temp file for the navigation ones.
--
-- Cases that pin a decision rather than a bug: which section each entry belongs
-- to and how it is spelled (a `- [ ]` checkbox in `#### Tasks`, a `- **HH:MM**`
-- line in `## Log`), the level-aware insert stopper that keeps a `####` capture
-- from running past the next `##`, and focus-over-duplication, which is the
-- requirement the hotkey exists for.

local here = (arg and arg[0] or debug.getinfo(1, "S").source:sub(2)):match("^(.*)[/\\][^/\\]*$") or "."
local root = vim.fn.fnamemodify(here, ":h:h")
package.path = ("%s/lua/?.lua;%s/lua/?/init.lua;%s"):format(root, root, package.path)
vim.opt.runtimepath:prepend(root)

local M = require("custom.daily-note")
local core = require("custom.note-capture")

local failed = 0
local function check(what, got, want)
  if got ~= want then
    failed = failed + 1
    print(("FAIL  %s\n        got  %s\n        want %s"):format(what, tostring(got), tostring(want)))
  else
    print("ok    " .. what)
  end
end

local notices = {}
vim.notify = function(msg, level)
  notices[#notices + 1] = { msg = msg, level = level }
end

local tmp = vim.fn.tempname()
vim.fn.mkdir(tmp, "p")
local function read(path)
  return vim.fn.readfile(path)
end
local joined = table.concat
--- Line number of the first line matching the Lua pattern, or nil.
local function index_of(lines, pattern)
  for i, line in ipairs(lines) do
    if line:match(pattern) then
      return i
    end
  end
end

-- A daily note shaped like the template: a To-Do section holding `#### Tasks`,
-- and a `## Log` section holding stamped lines.
local function daily_note()
  return {
    "# 2026-10-08 Thursday",                                      -- 1
    "## Summary",                                                 -- 2
    "",                                                           -- 3
    "## Journal",                                                 -- 4
    "",                                                           -- 5
    "### To-Do",                                                  -- 6
    "#### Top 3 Most Important Goals Today",                      -- 7
    "> _If I only accomplish one thing today, what should it be?_", -- 8
    "-",                                                          -- 9
    "#### time blocking",                                         -- 10
    "- **Time Blocking:** Dedicate specific hours to specific domains", -- 11
    "#### Tasks",                                                 -- 12
    "- [x] have omp deindex omp session transcripts from hister.", -- 13
    "",                                                           -- 14
    "## Notepad",                                                 -- 15
    "",                                                           -- 16
    "## Notes made today",                                        -- 17
    "",                                                           -- 18
    "## Log",                                                     -- 19
    "**Days Sober:**",                                            -- 20
    "**Hours of Sleep:**",                                        -- 21
    "- **17:29** broke night doing m with Jess.",                 -- 22
    "",                                                           -- 23
    "## Related Notes",                                           -- 24
    "* [[2026-10-01]]",                                           -- 25
  }
end

print("-- entry shape")
local task = core.bullet_lines("call VOA back", "- [ ] ", "")
check("task opens a checkbox", task[1], "- [ ] call VOA back")
check("task carries no stamp", task[1]:match("%d%d:%d%d"), nil)
local log = core.bullet_lines("sat down to study", "- **" .. os.date("%H:%M") .. "** ", "")
check("log line carries the clock", log[1]:match("^%- %*%*%d%d:%d%d%*%* sat down to study$") ~= nil, true)
check("log line carries no date", log[1]:match("%d%d%d%d%-%d%d%-%d%d"), nil)
local multi = core.bullet_lines("first\nsecond", "- [ ] ", "")
check("wrapped task indents the continuation", multi[2], "  second")

print("-- insert point")
local lines = daily_note()
local out = core.insert(lines, "#### Tasks", task)
check("task lands under the last task", index_of(out, "^%- %[ %] call VOA back$"), 14)
check("the existing task is not disturbed", out[13], "- [x] have omp deindex omp session transcripts from hister.")
check("the time-blocking list above stays where it is", out[11], "- **Time Blocking:** Dedicate specific hours to specific domains")
check("blank line before the next heading survives", out[15], "")
check("the next heading does not move", out[16], "## Notepad")
check("input is not mutated", lines[13], "- [x] have omp deindex omp session transcripts from hister.")
check("exactly one line added", #out, #lines + 1)

out = core.insert(daily_note(), "## Log", log)
check("log lands at the end of its section", index_of(out, "^%- %*%*%d%d:%d%d%*%* sat down to study$"), 23)
check("the stats lines above it stay put", out[20], "**Days Sober:**")
check("the blank separator before the next heading stays put", out[24], "")
check("the next heading moves by one line", out[25], "## Related Notes")

out = core.insert({ "# note", "## Operations", "- [x] a" }, "#### Tasks", task)
check("missing section gets a blank line before it", out[4], "")
check("missing section is appended", out[5], "#### Tasks")
check("missing section: entry follows", out[6], "- [ ] call VOA back")

print("-- which section the float writes to")
-- Stub the engine so no file is touched and the heading each mode chose is
-- visible: this is the only place the mode table is observable from outside.
local appended = {}
local real_append = core.append
core.append = function(path, heading, bullets)
  local target = path or core.daily_note_path()
  appended[#appended + 1] = { path = target, heading = heading, bullets = bullets }
  return target
end

local function capture_as(mode, text)
  appended = {}
  M.capture({ mode = mode })
  local float_buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(float_buf, 0, -1, false, { text })
  local map = vim.fn.maparg("<CR>", "i", false, true)
  if type(map.callback) ~= "function" then
    error("no <CR> callback in the capture float")
  end
  map.callback()
  vim.wait(200, function()
    return vim.fn.mode() == "n"
  end)
  return appended[1]
end

local wrote = capture_as("task", "email the landlord")
check("task mode writes to the tasks heading", wrote.heading, "#### Tasks")
check("task mode writes a checkbox", wrote.bullets[1]:match("^%- %[ %] email the landlord$") ~= nil, true)
check("the capture defaults to today's daily note", wrote.path, core.daily_note_path())
check("exactly one confirmation", #notices, 1)
check("confirmation names the kind and the file", notices[1].msg, "Task → " .. vim.fn.fnamemodify(wrote.path, ":t"))

wrote = capture_as("log", "read for an hour")
check("log mode writes to the log heading", wrote.heading, "## Log")
check("log mode writes a stamped line", wrote.bullets[1]:match("^%- %*%*%d%d:%d%d%*%* read for an hour$") ~= nil, true)

M.capture()
check("the float opens in task mode", vim.api.nvim_win_get_config(0).title[1][1]:match("Task >") ~= nil, true)
local tab = vim.fn.maparg("<Tab>", "i", false, true)
if type(tab.callback) ~= "function" then
  error("no <Tab> callback in the capture float")
end
tab.callback()
check("<Tab> moves to log mode", vim.api.nvim_win_get_config(0).title[1][1]:match("Log >") ~= nil, true)
tab.callback()
check("<Tab> wraps back to task mode", vim.api.nvim_win_get_config(0).title[1][1]:match("Task >") ~= nil, true)
local confirmations = #notices
vim.fn.maparg("<Esc>", "i", false, true).callback()
vial = nil
check("cancelling adds no confirmation", #notices, confirmations)

core.append = real_append

print("-- navigation focuses what is open")
local note = tmp .. "/daily.md"
vim.fn.writefile(daily_note(), note)
local other = tmp .. "/other.md"
vim.fn.writefile({ "# unrelated", "", "text" }, other)
local real_daily_note_path = core.daily_note_path
core.daily_note_path = function()
  return note
end

vim.cmd.edit(vim.fn.fnameescape(other))
vim.cmd.edit(vim.fn.fnameescape(note))
local daily_bufnr = vim.fn.bufnr(note)
check("today's note is a loaded buffer of its own", daily_bufnr > 0, true)
vim.cmd.edit(vim.fn.fnameescape(other))
check("some other buffer is the one on screen", vim.api.nvim_buf_get_name(0), other)

M.open()
check("navigation returns to the note", vim.api.nvim_buf_get_name(0), note)
check("navigation reuses the loaded buffer", vim.api.nvim_get_current_buf(), daily_bufnr)

-- The case the requirement is about: the note already displayed in one window
-- and another buffer in the one you are looking at.
vim.cmd("vsplit")
vim.cmd.edit(vim.fn.fnameescape(other))
local function windows_showing(buf)
  local found = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == buf then
      found[#found + 1] = win
    end
  end
  return found
end
local showing = windows_showing(daily_bufnr)
check("the note is displayed in exactly one window", #showing, 1)
local other_win = vim.api.nvim_get_current_win()
M.open()
check("navigation focuses the window already showing it", vim.api.nvim_get_current_win(), showing[1])
check("no second view of the note was opened", #windows_showing(daily_bufnr), 1)

-- The capture has to move the same way, or the float opens over whatever window
-- happens to be current and the entry lands in a note nobody is looking at --
-- exactly the "nothing happened" report the hotkey generated.
--
-- Look at the *other* window first: that is the state the hotkey is pressed in,
-- and leaving focus on the note would let this check pass whether or not the
-- capture moved anything.
-- A floating window is current while it is open, so the question is where it
-- opened: closing it returns focus there, which is what the user sees.
vim.cmd("wincmd w")
check("the other window is the one on screen", vim.api.nvim_get_current_win(), other_win)
M.capture()
local float_win = vim.api.nvim_get_current_win()
check("the capture float opened in its own window", float_win ~= showing[1], true)
vim.api.nvim_win_close(float_win, false)
check("capture opens on the window already showing the note", vim.api.nvim_get_current_win(), showing[1])

core.daily_note_path = real_daily_note_path

print("-- setup")
vim.g.mapleader = " "
M.setup()
local function map_for(desc)
  for _, map in ipairs(vim.api.nvim_get_keymap("n")) do
    if map.desc == desc then
      return map.lhs
    end
  end
end
check("<leader>nD is mapped", map_for("Open or focus today's daily note"), " nD")
check("<leader>nA is mapped", map_for("Capture a task or log into today's daily note"), " nA")
check(":DailyNote exists", vim.fn.exists(":DailyNote"), 2)
check(":DailyNoteCapture exists", vim.fn.exists(":DailyNoteCapture"), 2)

vim.fn.delete(tmp, "rf")

print(failed == 0 and "\nAll daily-note checks passed." or ("\n" .. failed .. " check(s) FAILED."))
os.exit(failed == 0 and 0 or 1)
