-- :NotesMadeToday — append notes created today under the daily note's
-- "## Notes made today" heading, then open it.
--
-- Thin wrapper over notes/scripts/notes_made_today.py. The script owns detection and
-- idempotency; this only resolves the target date and surfaces the result. Pass a date
-- to backfill:  :NotesMadeToday 2026-10-02
local M = {}

local SCRIPT = "~/notes/scripts/notes_made_today.py"

local function notify(msg)
  vim.notify(msg, vim.log.levels.INFO, { title = "Notes made today" })
end

local function notify_err(msg)
  vim.notify(msg, vim.log.levels.ERROR, { title = "Notes made today" })
end

--- Date to operate on: argument if given, else the date of the current buffer when that
--- buffer is a daily note, else today. Backfilling while sitting on another day's note
--- should not silently write to today.
local function target_date(args)
  if args and args ~= "" then
    return args
  end
  local bufname = vim.api.nvim_buf_get_name(0)
  local stamped = bufname:match("(%d%d%d%d%-%d%d%-%d%d)%.md$")
  if stamped then
    return stamped
  end
  return os.date("!%Y-%m-%d")
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
  vim.cmd(("edit ~/notes/docs/30-dailynotes/%s/%s/%s.md"):format(
    date:sub(1, 4), date:sub(6, 7), date
  ))
end

-- complete="file" lets the existing daily notes complete the argument, which is the only
-- sensible completion for a YYYY-MM-DD that must match a real note.
vim.api.nvim_create_user_command("NotesMadeToday", function(args)
  M.run({ args = args.args })
end, { nargs = "?", complete = "file", desc = "Add notes made today to the daily note" })

vim.api.nvim_create_user_command("NotesMadeTodayPreview", function(args)
  M.run({ args = args.args, preview = true })
end, { nargs = "?", complete = "file", desc = "Preview notes made today (dry run)" })

return M
