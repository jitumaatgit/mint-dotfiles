-- tangent-capture.lua
--
-- Capture the thought that arrives while you are doing something else, without
-- leaving the note you are in. `<leader>nT` opens a one-line float, `<CR>`
-- appends the text to the vault and gives the window back, `<Esc>`/`<C-c>`
-- changes nothing at all.
--
-- Why the daily note's `## Tangent Parking Lot`:
--   It is the section the rest of the system already reads -- the weekly note
--   template pulls tangents from each daily note into its own `## Tangent
--   Parking Lot`, and scripts/extract_weekly_tangents.py turns those into
--   inbox stubs. A second capture file would be a second convention.
--
-- Invariants this module is built around (see docs/guide/tangent-capture.md):
--   * No register, mark, jumplist entry or undo state belongs to the capture.
--     The float is its own scratch buffer and nothing is ever yanked, so
--     closing it is enough to leave the note you were in untouched.
--   * The write is durable the moment `<CR>` is pressed: it never waits for a
--     later `:w` of somebody else's buffer. When the target file *is* already
--     open in a buffer the text is appended through that buffer instead of the
--     file, because writing the file underneath a loaded buffer leaves the
--     buffer stale and its next `:w` silently reverts the tangent.
--   * A crash between "user pressed <CR>" and "bytes on disk" must not be able
--     to truncate a note, hence the temp-file + rename in atomic_write().

local M = {}

local HEADING = "## Tangent Parking Lot"
local VAULT = "~/notes"
local MAX_FLOAT_HEIGHT = 6

-- Mirror of plugins/obsidian.lua's daily_notes stanza, used only when
-- obsidian.nvim has not been loaded (it is lazy, ft=markdown). When it *is*
-- loaded its own client answers, so the two can never disagree in practice.
local DAILY_SUBDIR = "docs/30-dailynotes"
local DAILY_FORMAT = "%Y/%m/%Y-%m-%d"

local uv = vim.uv or vim.loop

---@class TangentState
---@field win integer
---@field buf integer
---@field conf table
---@field oneshot boolean
---@field insert boolean

---@type TangentState|nil
local state = nil

--- Read a `g:` variable that may be set from Lua (booleans) or Vimscript
--- (0/1, "0"/"1"). Absent or empty means "use the default".
---@param name string
---@param default boolean
---@return boolean
local function flag(name, default)
  local value = vim.g[name]
  if value == nil or value == "" then
    return default
  end
  return value == true or value == 1 or value == "1" or value == "true"
end

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
    timestamp = flag("tangent_timestamp", true),
    utc = flag("tangent_timestamp_utc", false),
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

  -- obsidian.nvim resolves this from `daily_notes.folder` and
  -- `daily_notes.date_format`; asking it keeps us honest if either changes.
  -- Reading package.loaded rather than require()ing avoids dragging the plugin
  -- into sessions (a lua file, a terminal) that would otherwise never load it.
  local obsidian = package.loaded["obsidian"]
  if obsidian and obsidian.get_client then
    local ok, path = pcall(function()
      return obsidian.get_client():daily_note_path()
    end)
    if ok and path then
      return tostring(path)
    end
  end

  return string.format("%s/%s/%s.md", vim.fn.expand(VAULT), DAILY_SUBDIR, os.date(DAILY_FORMAT))
end

--- Create the target file when it does not exist yet.
---
--- Prefers obsidian.nvim, which applies the vault's folder, frontmatter and
--- template rules; only falls back to copying the template verbatim.
---@param path string
---@return boolean ok, string|nil err
local function ensure_target(path)
  if uv.fs_stat(path) then
    return true
  end

  local dir = vim.fn.fnamemodify(path, ":h")
  vim.fn.mkdir(dir, "p")
  if vim.fn.isdirectory(dir) == 0 then
    return false, "cannot create directory " .. dir
  end

  local obsidian = package.loaded["obsidian"]
  if obsidian and obsidian.get_client then
    local ok = pcall(function()
      obsidian.get_client():today()
    end)
    if ok and uv.fs_stat(path) then
      return true
    end
  end

  local template = vim.fn.expand(VAULT .. "/docs/50-templates/dailynote-template.md")
  local body
  if vim.fn.filereadable(template) == 1 then
    body = vim.fn.readfile(template)
  else
    body = { "# " .. os.date("%Y-%m-%d"), "" }
  end
  if vim.fn.writefile(body, path) ~= 0 then
    return false, "cannot write " .. path
  end
  return true
end

--- Insert `bullets` into the `## Tangent Parking Lot` section of `lines`.
---
--- Pure: returns a new list and never touches its input, so it can be exercised
--- without a vault (see tangent-capture_test.lua).
---
--- Entries go after the last non-blank line of the section rather than right
--- after the heading, which matters in two ways: a trailing `### Goal: <name>`
--- heading keeps capturing entries (the weekly note groups by goal), and the
--- blank line separating the section from the next `##` heading stays where it
--- is. A missing section is appended at the end of the file.
---@param lines string[]
---@param bullets string[]
---@return string[]
function M.insert(lines, bullets)
  local out = {}
  for i = 1, #lines do
    out[i] = lines[i]
  end

  local heading
  for i, line in ipairs(out) do
    if line:match("^##%s+Tangent Parking Lot%s*$") then
      heading = i
      break
    end
  end

  if not heading then
    while #out > 0 and out[#out]:match("^%s*$") do
      table.remove(out)
    end
    if #out > 0 then
      out[#out + 1] = ""
    end
    out[#out + 1] = HEADING
    heading = #out
  end

  local stop = #out + 1
  for i = heading + 1, #out do
    if out[i]:match("^##%s") then
      stop = i
      break
    end
  end

  local at = heading
  for i = heading + 1, stop - 1 do
    if out[i]:match("%S") then
      at = i
    end
  end

  for i = #bullets, 1, -1 do
    table.insert(out, at + 1, bullets[i])
  end
  return out
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

  local lines = vim.split(vim.trim(text), "\n", { plain = true })
  while #lines > 1 and lines[#lines]:match("^%s*$") do
    table.remove(lines)
  end

  local out = {}
  for i, line in ipairs(lines) do
    if i == 1 then
      out[i] = "- " .. line .. stamp
    elseif line:match("^%s*$") then
      out[i] = ""
    else
      out[i] = "  " .. line
    end
  end
  return out
end

--- Replace `path` with `lines` without ever leaving a half-written file behind.
---@param path string
---@param lines string[]
---@return boolean ok, string|nil err
local function atomic_write(path, lines)
  local dir = vim.fn.fnamemodify(path, ":h")
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end

  local tmp = string.format("%s/.%s.tangent.tmp", dir, vim.fn.fnamemodify(path, ":t"))
  if vim.fn.writefile(lines, tmp) ~= 0 then
    return false, "cannot write " .. tmp
  end

  -- rename() replaces the inode, so the temp file's mode would otherwise win
  -- over the note's (writefile creates 0644 before umask). `% 0x1000` peels the
  -- S_IFREG bits off st_mode, giving the permission bits on their own.
  local stat = uv.fs_stat(path)
  if stat then
    uv.fs_chmod(tmp, stat.mode % 0x1000)
  end

  local ok, err = uv.fs_rename(tmp, path)
  if not ok then
    uv.fs_unlink(tmp)
    return false, tostring(err)
  end
  return true
end

--- The loaded buffer holding `path`, if any.
---@param path string
---@return integer|nil
local function buffer_for(path)
  local abs = uv.fs_realpath(path) or path
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      local name = vim.api.nvim_buf_get_name(buf)
      if name ~= "" and (name == path or (uv.fs_realpath(name) or name) == abs) then
        return buf
      end
    end
  end
  return nil
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

  local path = M.target_path()
  if not uv.fs_stat(path) then
    local ok, err = ensure_target(path)
    if not ok then
      return nil, err
    end
  end

  -- Read from the buffer when there is one: the on-disk copy may be behind it,
  -- and rebuilding the file from disk would throw the buffer's pending edits
  -- away underneath the user.
  local buf = buffer_for(path)
  local lines = buf and vim.api.nvim_buf_get_lines(buf, 0, -1, false) or vim.fn.readfile(path)
  lines = M.insert(lines, M.bullet(text))

  if buf and vim.bo[buf].modifiable and not vim.bo[buf].readonly then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    -- nvim_buf_call() swaps the buffer into a temporary window without firing
    -- autocommands and restores the cursor and current buffer afterwards, so
    -- the window the user is looking at does not move.
    local ok, err = pcall(vim.api.nvim_buf_call, buf, function()
      vim.cmd("silent write!")
    end)
    if not ok then
      return nil, tostring(err)
    end
    return path
  end

  local ok, err = atomic_write(path, lines)
  if not ok then
    return nil, err
  end
  return path
end

--- Close the float, if one is open, and let the window underneath have focus.
local function close_float()
  local st = state
  state = nil
  if not st then
    return
  end
  if st.win and vim.api.nvim_win_is_valid(st.win) then
    pcall(vim.api.nvim_win_close, st.win, true)
  end
  if st.buf and vim.api.nvim_buf_is_valid(st.buf) then
    pcall(vim.api.nvim_buf_delete, st.buf, { force = true })
  end
  -- Insert mode is not per-window: closing a float that was typing does not
  -- clear it, so the note underneath would start swallowing keystrokes. Only
  -- leave insert when the capture did not start from insert itself (which it
  -- can, via the RPC entry point).
  if not st.insert and vim.fn.mode():match("^[iR]") then
    vim.cmd("stopinsert")
  end
end

--- Save the float's contents and close it. Cancels on blank input.
---@param st TangentState
local function commit_float(st)
  local text = table.concat(vim.api.nvim_buf_get_lines(st.buf, 0, -1, false), "\n")
  local oneshot = st.oneshot
  close_float()

  if text:match("%S") then
    local path, err = M.append(text)
    if path then
      vim.notify("Tangent → " .. vim.fn.fnamemodify(path, ":t"), vim.log.levels.INFO, { title = "tangent" })
    else
      vim.notify("Tangent NOT saved: " .. tostring(err), vim.log.levels.ERROR, { title = "tangent" })
    end
  end

  -- One-shot mode is the system-wide entry point: nvim was started purely to
  -- show this float, so there is nothing to return to.
  if oneshot then
    vim.schedule(function()
      vim.cmd("qa!")
    end)
  end
end

--- Grow the float so a pasted paragraph is visible, up to MAX_FLOAT_HEIGHT.
---@param st TangentState
local function resize_float(st)
  if not vim.api.nvim_win_is_valid(st.win) then
    return
  end
  local height = math.max(1, math.min(MAX_FLOAT_HEIGHT, vim.api.nvim_buf_line_count(st.buf)))
  if st.conf.height ~= height then
    st.conf.height = height
    pcall(vim.api.nvim_win_set_config, st.win, st.conf)
  end
end

--- Open the capture float. `<CR>` saves, `<Esc>`/`<C-c>` cancels.
---@param opts { oneshot: boolean|? }|nil
function M.capture(opts)
  opts = opts or {}

  if state then
    if vim.api.nvim_win_is_valid(state.win) then
      vim.api.nvim_set_current_win(state.win)
      vim.cmd("startinsert")
      return
    end
    state = nil
  end

  local c = cfg()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false

  local width = math.max(30, math.min(72, vim.o.columns - 24))
  -- Remembered so closing the float can put the mode back: the capture forces
  -- insert mode, and insert mode is global state, not a property of the window
  -- that goes away with the float.
  local entered_insert = vim.fn.mode():match("^[iR]") ~= nil

  local conf = {
    relative = "editor",
    row = math.max(1, math.floor(vim.o.lines / 3) - 1),
    col = math.max(0, math.floor((vim.o.columns - width) / 2)),
    width = width,
    height = 1,
    style = "minimal",
    border = "rounded",
    -- The prompt lives in the border rather than as virtual text inside the
    -- line: virtual text would sit under the cursor's column arithmetic and
    -- shift the caret, this cannot.
    title = " " .. vim.trim(c.prompt) .. " ",
    title_pos = "left",
    noautocmd = true,
    zindex = 60,
  }

  local st = {
    win = vim.api.nvim_open_win(buf, true, conf),
    buf = buf,
    conf = conf,
    oneshot = opts.oneshot == true,
    insert = entered_insert,
  }
  state = st

  -- style="minimal" clears numbers/signcolumn/cursorline but not a globally set
  -- winbar, and LazyVim sets one for navic's breadcrumbs.
  vim.wo[st.win].winbar = ""
  vim.wo[st.win].statusline = ""
  vim.wo[st.win].wrap = true

  local function map(mode, lhs, rhs, desc)
    vim.keymap.set(mode, lhs, rhs, { buffer = buf, nowait = true, silent = true, desc = desc })
  end

  map({ "i", "n" }, "<CR>", function()
    commit_float(st)
  end, "Save tangent")
  map({ "i", "n" }, "<Esc>", function()
    local oneshot = st.oneshot
    close_float()
    if oneshot then
      vim.schedule(function()
        vim.cmd("qa!")
      end)
    end
  end, "Cancel tangent")
  map({ "i", "n" }, "<C-c>", function()
    local oneshot = st.oneshot
    close_float()
    if oneshot then
      vim.schedule(function()
        vim.cmd("qa!")
      end)
    end
  end, "Cancel tangent")

  local group = vim.api.nvim_create_augroup("TangentCaptureFloat", { clear = true })
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "TextChangedP" }, {
    group = group,
    buffer = buf,
    callback = function()
      resize_float(st)
    end,
  })
  -- The float is the whole point of one-shot mode: if it is dismissed some
  -- other way (a remote :q, a signal) the placeholder nvim should not linger.
  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    pattern = tostring(st.win),
    once = true,
    callback = function()
      -- Only a close this module did not initiate lands here: close_float()
      -- clears `state` before closing the window.
      if state == st then
        state = nil
        if st.oneshot then
          vim.schedule(function()
            vim.cmd("qa!")
          end)
        end
      end
    end,
  })

  vim.cmd("startinsert")
end

--- Start the RPC server that system-wide triggers connect to.
---
--- A socket cannot be conjured on the other end: `nvim --server` needs an
--- address, so every instance that wants to be reachable has to publish one.
--- `serverstart()` with no argument generates `$XDG_RUNTIME_DIR/nvim.<pid>.<n>`,
--- which is how nvim-tangent-capture finds it again.
---@return string|nil address
function M.ensure_server()
  if #vim.fn.serverlist() > 0 then
    return vim.v.servername
  end
  local ok, addr = pcall(vim.fn.serverstart)
  if not ok or type(addr) ~= "string" or addr == "" then
    vim.schedule(function()
      vim.notify("tangent: could not start RPC server; the system-wide hotkey will not reach this nvim", vim.log.levels.WARN)
    end)
    return nil
  end
  return addr
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
