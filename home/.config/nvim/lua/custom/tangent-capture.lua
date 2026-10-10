-- tangent-capture.lua
--
-- Capture the thought that arrives while you are doing something else, without
-- leaving the note you are in. `<leader>nT` opens a one-line float, `<CR>`
-- appends the text to the vault and gives the window back, `<Esc>`/`<C-c>`
-- changes nothing at all.
--
-- Everything that makes a capture correct -- the daily-note path, the section
-- rules, the buffer-aware write, the float, the RPC server -- lives in
-- custom.note-capture. What lives here is the part that is only about
-- tangents: which section they go in, and how one is spelled.
--
-- Why the daily note's `## Tangent Parking Lot`:
--   It is the section the rest of the system already reads -- the weekly note
--   template pulls tangents from each daily note into its own `## Tangent
--   Parking Lot`, and scripts/extract_weekly_tangents.py turns those into
--   inbox stubs. A second capture file would be a second convention.

local core = require("custom.note-capture")

local M = {}

local HEADING = "## Tangent Parking Lot"

---@return { path: string|nil, timestamp: boolean, utc: boolean, prompt: string }
local function cfg()
  local path = vim.g.tangent_parking_lot_path
  if type(path) == "string" and path ~= "" then
    path = vim.fn.expand(path)
  else
    path = nil
  end

  local prompt = vim.g.tangent_prompt
  if type(prompt) ~= "string" or prompt == "" then
    prompt = "Tangent > "
  end

  return {
    path = path,
    timestamp = core.flag("tangent_timestamp", true),
    utc = core.flag("tangent_timestamp_utc", false),
    prompt = prompt,
  }
end

--- The file a tangent is appended to.
---
--- Defaults to today's daily note. `g:tangent_parking_lot_path` overrides it,
--- which is what makes the module usable from a test or against a scratch file.
---@return string
function M.target_path()
  local c = cfg()
  if c.path then
    return c.path
  end

  return core.daily_note_path()
end

--- The markdown lines one tangent occupies.
---
--- A single line becomes a bullet with a trailing `(YYYY-MM-DD HH:MM)` stamp;
--- pasted multi-line text continues as an indented sub-line, which is how the
--- vault's existing tangents with a second thought are written.
---@param text string
---@return string[]
function M.bullet(text)
  local c = cfg()
  local stamp = ""
  if c.timestamp then
    -- Local time by default, matching the daily-note filename and the `## Log`
    -- stamps this is filed next to. `g:tangent_timestamp_utc = 1` switches it.
    stamp = os.date((c.utc and "!" or "") .. " (%Y-%m-%d %H:%M)")
  end

  return core.bullet_lines(text, "- ", stamp)
end

function M.insert(lines, bullets)
  return core.insert(lines, HEADING, bullets)
end

--- Append `text` to the parking lot.
---
--- `nil` is returned for blank input: pressing `<CR>` on an empty float is a
--- cancel, not an entry.
---@param text string
---@return string|nil path, string|nil err
function M.append(text)
  if type(text) ~= "string" or text:match("^%s*$") then
    return nil
  end

  return core.append(M.target_path(), HEADING, M.bullet(text))
end

--- The one mode this capture has. Built per call so `g:tangent_prompt` is read
--- at the moment the float opens rather than once at load time.
---@return core.CaptureMode[]
local function modes()
  return {
    {
      name = "tangent",
      label = "Tangent",
      title = cfg().prompt,
      heading = HEADING,
      bullet = M.bullet,
    },
  }
end

--- Open the capture float. `<CR>` saves, `<Esc>`/`<C-c>` cancels.
---@param opts { oneshot: boolean|? }|nil
function M.capture(opts)
  core.capture({
    modes = modes(),
    -- A function, not a path: `g:tangent_parking_lot_path` is read when the
    -- entry lands, exactly as :TangentAppend still reads it.
    path = M.target_path,
    oneshot = opts and opts.oneshot,
  })
end

function M.ensure_server()
  return core.ensure_server()
end

function M.setup()
  vim.keymap.set("n", "<leader>nT", function()
    M.capture()
  end, { desc = "Capture tangent to parking lot" })

  vim.api.nvim_create_user_command("TangentCapture", function(cmd)
    M.capture({ oneshot = cmd.bang })
  end, { bang = true, desc = "Capture a tangent into the parking lot (:TangentCapture! quits when done)" })

  vim.api.nvim_create_user_command("TangentAppend", function(cmd)
    local path, err = M.append(cmd.args)
    if not path then
      vim.notify("tangent: " .. tostring(err or "nothing to append"), vim.log.levels.ERROR)
    end
  end, { nargs = "+", desc = "Append text to the tangent parking lot without opening the float" })

  -- Publish the RPC address for the external trigger. VimEnter rather than
  -- setup() so the address exists before anything can try to reach it.
  vim.api.nvim_create_autocmd("VimEnter", {
    group = vim.api.nvim_create_augroup("TangentCaptureServer", { clear = true }),
    once = true,
    callback = function()
      M.ensure_server()
    end,
  })
end

return M
