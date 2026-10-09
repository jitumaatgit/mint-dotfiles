-- Self-check for tangent-capture.lua. Run via ./smoke.sh at the repo root, or
-- directly with:
--   nvim --headless -u NONE -l home/.config/nvim/lua/custom/tangent-capture_test.lua
--
-- `-u NONE` on purpose: the module is deliberately vanilla (no plugin
-- dependencies), so it can be checked without LazyVim in the way, and every
-- append test points g:tangent_parking_lot_path at a temp file so the real
-- vault is never touched.
--
-- Cases that pin a decision rather than a bug: the insert-point rules (after
-- the section comment, under a trailing `### Goal:` heading, blank line before
-- the next `##` preserved) and the invariant block, which is the whole reason
-- the float is a scratch buffer.

local here = (arg and arg[0] or debug.getinfo(1, "S").source:sub(2)):match("^(.*)[/\\][^/\\]*$") or "."
local root = vim.fn.fnamemodify(here, ":h:h")
package.path = ("%s/lua/?.lua;%s/lua/?/init.lua;%s"):format(root, root, package.path)
vim.opt.runtimepath:prepend(root)

local M = require("custom.tangent-capture")

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
local function joined(lines, sep)
  return table.concat(lines, sep or "\n")
end
--- Line number of the first line matching the Lua pattern, or nil.
local function index_of(lines, pattern)
  for i, line in ipairs(lines) do
    if line:match(pattern) then
      return i
    end
  end
end
local function open(path)
  vim.cmd("edit! " .. vim.fn.fnameescape(path))
end
--- Press a buffer-local mapping of the currently focused float.
local function press(lhs, mode)
  local map = vim.fn.maparg(lhs, mode or "i", false, true)
  if type(map.callback) ~= "function" then
    error("no callback mapped for " .. lhs)
  end
  map.callback()
end

print("-- bullet formatting")
vim.g.tangent_parking_lot_path = nil
vim.g.tangent_timestamp = 1
check(
  "local stamp format",
  M.bullet("hello")[1]:match("^%- hello %(%d%d%d%d%-%d%d%-%d%d %d%d:%d%d%)$") ~= nil,
  true
)
vim.g.tangent_timestamp_utc = 1
local utc_before = os.date("!%Y-%m-%d %H:%M")
local utc_stamp = M.bullet("x")[1]:match("(%(%d%d%d%d%-%d%d%-%d%d %d%d:%d%d%))$")
local utc_after = os.date("!%Y-%m-%d %H:%M")
check("utc flag switches the clock", utc_stamp == "(" .. utc_before .. ")" or utc_stamp == "(" .. utc_after .. ")", true)
vim.g.tangent_timestamp_utc = nil
vim.g.tangent_timestamp = 0
check("timestamp can be turned off with 0", M.bullet("plain")[1], "- plain")
vim.g.tangent_timestamp = nil

local multi = M.bullet("first\nsecond\nthird")
check("first line is the bullet", multi[1]:match("^%- first %(") ~= nil, true)
check("continuation is indented two spaces", multi[2], "  second")
check("all lines kept", #multi, 3)
check("trailing blank continuation dropped", #M.bullet("first\n\n\n"), 1)

print("-- insert point")
local daily = {
  "# 2026-10-08 Thursday",
  "## Summary",
  "",
  "## Tangent Parking Lot",
  "",
  "<!-- Optional: group entries under '### Goal: <name>' — the weekly note then groups them by goal. -->",
  "",
  "## Operations",
}
local out = M.insert(daily, { "- tangent" })
check("entry goes after the section comment", index_of(out, "- tangent"), 7)
check("blank line before the next heading survives", out[8], "")
check("next heading does not move", out[9], "## Operations")
check("input is not mutated", daily[7], "")
check("exactly one line added", #out, #daily + 1)

local goal = { "## Tangent Parking Lot", "- a", "### Goal: stay sober", "- b", "", "## Next" }
out = M.insert(goal, { "- c" })
check("entry lands under the trailing goal heading", out[5], "- c")
check("unknown-grouped entry stays above the blank separator", out[6], "")
check("next heading stays last", out[7], "## Next")

out = M.insert({ "# note", "body", "", "" }, { "- x" })
check("missing section: blank line before the new heading", out[3], "")
check("missing section: heading appended", out[4], "## Tangent Parking Lot")
check("missing section: entry follows", out[5], "- x")
check("missing section: trailing blanks trimmed", #out, 5)

out = M.insert({ "## Tangent Parking Lot", "", "## Next" }, { "- e" })
check("empty section gets the entry directly", out[2], "- e")
check("empty section keeps its blank line", out[3], "")

print("-- target resolution")
check(
  "default target is a dated daily note",
  M.target_path():match("^/.*/notes/docs/30%-dailynotes/%d%d%d%d/%d%d/%d%d%d%d%-%d%d%-%d%d%.md$") ~= nil,
  true
)
vim.g.tangent_parking_lot_path = "~/tmp/tangent-test.md"
check("override is expanded", M.target_path(), vim.fn.expand("~/tmp/tangent-test.md"))
vim.g.tangent_parking_lot_path = nil

print("-- append")
local target = tmp .. "/parking.md"
vim.g.tangent_parking_lot_path = target
check("first append reports the path", M.append("first thought"), target)
local lines = read(target)
check("section heading written", index_of(lines, "## Tangent Parking Lot") ~= nil, true)
check("first thought written after the heading", index_of(lines, "## Tangent Parking Lot") < index_of(lines, "^%- first thought %("), true)
local count = #lines
check("blank input is a no-op", M.append("   "), nil)
check("blank input wrote nothing", #read(target), count)
check("second append adds one line", (M.append("second thought") and #read(target)) or -1, count + 1)
check("second thought written", index_of(read(target), "^%- second thought %(") ~= nil, true)

print("-- loaded buffers are written through")
local buffered = tmp .. "/buffered.md"
vim.fn.writefile({ "## Tangent Parking Lot", "", "## Later" }, buffered)
open(buffered)
vim.api.nvim_buf_set_lines(0, -1, -1, false, { "", "an unsaved edit" })
vim.g.tangent_parking_lot_path = buffered
check("append through a loaded buffer reports the path", M.append("through the buffer"), buffered)
lines = read(buffered)
check("tangent reached the file", index_of(lines, "^%- through the buffer %(") ~= nil, true)
check("pending buffer edits were not discarded", index_of(lines, "an unsaved edit") ~= nil, true)

print("-- invariants")
local note = tmp .. "/note.md"
vim.fn.writefile({ "# note", "", "line two", "line three", "" }, note)
open(note)
vim.api.nvim_win_set_cursor(0, { 3, 5 })
local before = {
  buf = vim.api.nvim_get_current_buf(),
  win = vim.api.nvim_get_current_win(),
  cursor = joined({ vim.api.nvim_win_get_cursor(0)[1], vim.api.nvim_win_get_cursor(0)[2] }, ":"),
  lines = joined(vim.api.nvim_buf_get_lines(0, 0, -1, false)),
  modified = tostring(vim.bo.modified),
  unnamed = vim.fn.getreg('"'),
  yank = vim.fn.getreg("0"),
  undo = vim.fn.undotree().seq_cur,
  bufs = #vim.api.nvim_list_bufs(),
  jumps = #vim.fn.getjumplist()[1],
}

M.capture()
check("float takes focus", vim.api.nvim_get_current_buf() ~= before.buf, true)
local float_win = vim.api.nvim_get_current_win()
local float_conf = vim.api.nvim_win_get_config(float_win)
check("prompt is drawn in the border", float_conf.title[1][1]:match("Tangent >") ~= nil, true)
check("no line numbers", tostring(vim.wo[float_win].number), "false")
check("no relative numbers", tostring(vim.wo[float_win].relativenumber), "false")
check("no winbar (navic must not leak in)", vim.wo[float_win].winbar, "")
check("scratch buffer", vim.bo.buftype, "nofile")
check("buffer not listed", tostring(vim.bo.buflisted), "false")
check("buffer wiped when hidden", vim.bo.bufhidden, "wipe")

press("<Esc>")
check("cancel returns to the note", vim.api.nvim_get_current_buf(), before.buf)
check("cancel returns to the original window", vim.api.nvim_get_current_win(), before.win)
check("cursor untouched", joined({ vim.api.nvim_win_get_cursor(0)[1], vim.api.nvim_win_get_cursor(0)[2] }, ":"), before.cursor)
-- Closing a float does not clear insert mode by itself, and the note underneath
-- would start swallowing keystrokes. stopinsert() is deferred, so give it the
-- chance to land before asking.
vim.wait(200, function()
  return vim.fn.mode() == "n"
end)
check("cancel leaves normal mode behind", vim.fn.mode(), "n")
check("buffer text untouched", joined(vim.api.nvim_buf_get_lines(0, 0, -1, false)), before.lines)
check("modified flag untouched", tostring(vim.bo.modified), before.modified)
check("unnamed register untouched", vim.fn.getreg('"'), before.unnamed)
check("yank register untouched", vim.fn.getreg("0"), before.yank)
check("undo state untouched", vim.fn.undotree().seq_cur, before.undo)
check("float buffer did not leak", #vim.api.nvim_list_bufs(), before.bufs)
check("jumplist untouched", #vim.fn.getjumplist()[1], before.jumps)

print("-- save")
local saved = tmp .. "/saved.md"
vim.fn.writefile({ "## Tangent Parking Lot", "", "## Later" }, saved)
open(note)
vim.api.nvim_win_set_cursor(0, { 2, 0 })
notices = {}
vim.g.tangent_parking_lot_path = saved
M.capture()
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "a real tangent" })
press("<CR>")
check("save returns to the note", vim.api.nvim_get_current_buf(), before.buf)
check("save returns to the original window", vim.api.nvim_get_current_win(), before.win)
check("save leaves the cursor alone", joined({ vim.api.nvim_win_get_cursor(0)[1], vim.api.nvim_win_get_cursor(0)[2] }, ":"), "2:0")
check("save leaves the buffer untouched", joined(vim.api.nvim_buf_get_lines(0, 0, -1, false)), before.lines)
lines = read(saved)
check("tangent written", index_of(lines, "^%- a real tangent %(") ~= nil, true)
check("tangent lands before the next heading", index_of(lines, "^%- a real tangent %(") < index_of(lines, "## Later"), true)
vim.wait(200, function()
  return vim.fn.mode() == "n"
end)
check("save leaves normal mode behind", vim.fn.mode(), "n")
check("exactly one confirmation", #notices, 1)
check("confirmation names the file", notices[1].msg:match("saved%.md") ~= nil, true)

notices = {}
count = #read(saved)
M.capture()
press("<CR>")
check("empty capture stores nothing", #read(saved), count)
check("empty capture is silent", #notices, 0)
check("empty capture returns focus", vim.api.nvim_get_current_buf(), before.buf)

print("-- setup")
vim.g.mapleader = " "
M.setup()
local found
for _, map in ipairs(vim.api.nvim_get_keymap("n")) do
  if map.desc == "Capture tangent to parking lot" then
    found = map.lhs
  end
end
check("<leader>nT is mapped", found, " nT")
check("<leader>nT resolves to the float's user command", vim.fn.exists(":TangentCapture"), 2)

vim.g.tangent_parking_lot_path = nil
vim.fn.delete(tmp, "rf")

print(failed == 0 and "\nAll tangent-capture checks passed." or ("\n" .. failed .. " check(s) FAILED."))
os.exit(failed == 0 and 0 or 1)
