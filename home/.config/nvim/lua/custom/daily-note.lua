-- daily-note.lua
--
-- Two things, both about today's daily note:
--
--   * going there -- `:DailyNote`, `<leader>nD`, or the system-wide
--     nvim-daily-note script. A window already showing the note is focused
--     instead of being opened a second time.
--   * catching what lands in it -- a float with a `<Tab>` between `#### Tasks`
--     (a `- [ ]` checkbox, the convention `task-auto-complete.lua` already
--     completes on save) and `## Log` (a `- **HH:MM**` line), because those are
--     the two sections of the day that get written from outside it.
--
-- The float, the section rules and the write path are custom.note-capture's.
-- What lives here is which section each entry belongs to, how it is spelled,
-- and what "go to the daily note" means when it is already open somewhere.

local core = require("custom.note-capture")

local M = {}

local DEFAULT_TASK_HEADING = "#### Tasks"
local DEFAULT_LOG_HEADING = "## Log"

--- A `g:` override for a heading, so a vault that renames a section does not
--- need this module patched.
---@param name string
---@param default string
---@return string
local function heading_or(name, default)
  local value = vim.g[name]
  if type(value) == "string" and value ~= "" then
    return value
  end
  return default
end

--- A task is a checkbox, which is the shape the rest of the vault's tooling
--- reads: `task-auto-complete.lua` moves `- [x]` lines to `## Completed` on save
--- and stamps them, and `obsidian-task-filter.lua` greps for `- [ ]`.
---@param text string
---@return string[]
local function task_bullet(text)
  return core.bullet_lines(text, "- [ ] ", "")
end

--- A log line carries the clock, not the date: the section already sits under a
--- dated note and every existing entry reads `- **17:29** ...`.
---@param text string
---@return string[]
local function log_bullet(text)
  if not core.flag("daily_note_log_timestamp", true) then
    return core.bullet_lines(text, "- ", "")
  end
  return core.bullet_lines(text, "- **" .. os.date("%H:%M") .. "** ", "")
end

--- The capture float's modes, in the order <Tab> walks them: a task first,
--- because that is the one that must not be lost.
---@return core.CaptureMode[]
local function modes()
  return {
    {
      name = "task",
      label = "Task",
      title = "Task > ",
      heading = heading_or("daily_note_task_heading", DEFAULT_TASK_HEADING),
      bullet = task_bullet,
    },
    {
      name = "log",
      label = "Log",
      title = "Log > ",
      heading = heading_or("daily_note_log_heading", DEFAULT_LOG_HEADING),
      bullet = log_bullet,
    },
  }
end

--- The window showing `buf`, in any tabpage, or nil when it is not displayed.
---@param buf integer
---@return integer|nil
local function note_window(buf)
  for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
      if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf then
        return win
      end
    end
  end
end

--- Open today's daily note, focusing the window that already shows it.
---
--- "Focus, do not duplicate" is the whole requirement: `:edit` on a note that
--- is already displayed in another window would give the same buffer two
--- visible views, and the hotkey's promise -- that the note you are looking at
--- _is_ the one with today's tasks -- would be quietly false. A window in any
--- tabpage counts, because a note captured into earlier today is usually still
--- open in whatever tab you left it in.
---@return string path
function M.open()
  local path = core.daily_note_path()

  local buf = core.buffer_for(path)
  if buf then
    local win = note_window(buf)
    if win then
      vim.api.nvim_set_current_win(win)
      return path
    end
    -- Loaded but hidden: it goes in the current window, because that is where
    -- the user asked for it.
    vim.api.nvim_win_set_buf(0, buf)
    return path
  end

  -- Not loaded: obsidian.nvim's own daily-note creation applies the vault's
  -- folder, frontmatter and template rules, which is exactly what a cold start
  -- needs. It opens the note too, so there is nothing left to do.
  local obsidian = package.loaded["obsidian"]
  if obsidian and obsidian.get_client then
    local ok = pcall(function()
      obsidian.get_client():today()
    end)
    if ok and core.buffer_for(path) then
      return path
    end
  end

  core.ensure_file(path)
  vim.cmd.edit(vim.fn.fnameescape(path))
  return path
end

--- Open the capture float. `<Tab>` switches between task and log.
---
--- The float opens on the window already showing the note when there is one.
--- A note left open in another split or tab is the note the hotkey means, and
--- a float that appears somewhere else looks like the hotkey did nothing -- the
--- entry still lands, silently, in the note nobody is looking at. When the note
--- is not displayed the float simply opens where it was asked for.
---@param opts { mode: string|?, oneshot: boolean|? }|nil
function M.capture(opts)
  opts = opts or {}

  local buf = core.buffer_for(core.daily_note_path())
  local win = buf and note_window(buf)
  if win then
    vim.api.nvim_set_current_win(win)
  end
  core.capture({
    modes = modes(),
    mode = opts.mode,
    oneshot = opts.oneshot,
  })
end

function M.setup()
  vim.keymap.set("n", "<leader>nD", function()
    M.open()
  end, { desc = "Open or focus today's daily note" })

  vim.keymap.set("n", "<leader>nA", function()
    M.capture()
  end, { desc = "Capture a task or log into today's daily note" })

  vim.api.nvim_create_user_command("DailyNote", function()
    M.open()
  end, { desc = "Open today's daily note, focusing the window already showing it" })

  vim.api.nvim_create_user_command("DailyNoteCapture", function(cmd)
    M.capture({ mode = cmd.args ~= "" and cmd.args or nil, oneshot = cmd.bang })
  end, { nargs = "?", bang = true, desc = "Capture a task or log into today's daily note (:DailyNoteCapture! quits when done)" })

  -- Publish the RPC address for the external trigger. VimEnter rather than
  -- setup() so the address exists before anything can try to reach it. Both
  -- this and the tangent module call ensure_server(); the first one wins and
  -- the other sees the socket already there.
  vim.api.nvim_create_autocmd("VimEnter", {
    group = vim.api.nvim_create_augroup("DailyNoteCaptureServer", { clear = true }),
    once = true,
    callback = function()
      core.ensure_server()
    end,
  })
end

return M
