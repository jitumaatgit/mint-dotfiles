-- :NotesMadeToday — rebuild the "## Notes made today" section of a daily note,
-- then open it.
--
-- Thin wrapper over notes/scripts/notes_made_today.py. The script owns detection,
-- ordering and idempotency; this only resolves the target date and surfaces the
-- result. Pass a date to backfill:  :NotesMadeToday 2026-10-02
local M = {}

local SCRIPT = "~/notes/scripts/notes_made_today.py"
local DAILY_NOTES = "/docs/30-dailynotes/"

local function notify(msg)
  vim.notify(msg, vim.log.levels.INFO, { title = "Notes made today" })
end

local function notify_err(msg)
  vim.notify(msg, vim.log.levels.ERROR, { title = "Notes made today" })
end

--- Date to operate on: argument if given, else the date of the current buffer when that
--- buffer is a daily note, else today. Backfilling while sitting on another day's note
--- should not silently write to today.
---
--- Local, not UTC: the daily note is filed on the day it is *here*, so a note written at
--- 18:00 belongs to today's note, not tomorrow's.
local function target_date(args)
  if args and args ~= "" then
    return args
  end
  local bufname = vim.api.nvim_buf_get_name(0)
  local stamped = bufname:match("(%d%d%d%d%-%d%d%-%d%d)%.md$")
  if stamped then
    return stamped
  end
  return os.date("%Y-%m-%d")
end

--- Today's daily note, as a path.
local function daily_note_path(date)
  return vim.fn.expand(
    ("~/notes/docs/30-dailynotes/%s/%s/%s.md"):format(date:sub(1, 4), date:sub(6, 7), date)
  )
end

--- Reload today's daily note if it is open and clean, so an entry added by the script
--- is visible and is not clobbered by a later :w of a stale buffer. A modified buffer is
--- left alone — never discard what the user typed.
local function refresh_open_daily_note(date)
  local path = daily_note_path(date)
  local bufnr = vim.fn.bufnr(vim.fn.fnameescape(path))
  if bufnr < 1 or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  if vim.bo[bufnr].modified then
    notify("today's note is open with unsaved changes: :w to keep them, or :e! to reload")
    return
  end
  vim.api.nvim_buf_call(bufnr, function()
    vim.cmd("silent! edit!")
  end)
end

function M.run(opts)
  opts = opts or {}
  local date = target_date(opts.args)
  if not date:match("^%d%d%d%d%-%d%d%-%d%d$") then
    notify_err(("bad date %q, expected YYYY-MM-DD"):format(date))
    return
  end

  local cmd = { "python3", vim.fn.expand(SCRIPT), "--date", date }
  if opts.preview then
    table.insert(cmd, "--dry-run")
  end

  local ok, out = pcall(vim.fn.system, cmd)
  local code = vim.v.shell_error
  out = ok and vim.trim(out) or ""

  if code ~= 0 then
    notify_err(out ~= "" and out or ("script exited " .. code))
    return
  end

  notify(out ~= "" and out or ("no notes made on " .. date))
  vim.cmd("edit " .. vim.fn.fnameescape(daily_note_path(date)))
end

--- Keep today's section current: as soon as a note is written, today's daily note is
--- rebuilt from it. Daily notes are excluded because they are the *output* of this
--- rebuild — writing one must not trigger another pass over the same file.
function M.setup()
  local group = vim.api.nvim_create_augroup("NotesMadeToday", { clear = true })

  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    pattern = "*.md",
    desc = "Rebuild today's Notes made today section when a note is written",
    callback = function(ev)
      local name = vim.api.nvim_buf_get_name(ev.buf)
      if name:find(DAILY_NOTES, 1, true) then
        return
      end
      local date = os.date("%Y-%m-%d")
      vim.system({ "python3", vim.fn.expand(SCRIPT), "--date", date }, { text = true },
        function(out)
          vim.schedule(function()
            if out.code ~= 0 then
              local msg = vim.trim(out.stderr or "")
              notify_err(msg ~= "" and msg or ("script exited " .. out.code))
              return
            end
            refresh_open_daily_note(date)
          end)
        end)
    end,
  })
end

-- complete="file" lets the existing daily notes complete the argument, which is the only
-- sensible completion for a YYYY-MM-DD that must match a real note.
vim.api.nvim_create_user_command("NotesMadeToday", function(args)
  M.run({ args = args.args })
end, { nargs = "?", complete = "file", desc = "Rebuild the Notes made today section" })

vim.api.nvim_create_user_command("NotesMadeTodayPreview", function(args)
  M.run({ args = args.args, preview = true })
end, { nargs = "?", complete = "file", desc = "Preview notes made today (dry run)" })

return M
