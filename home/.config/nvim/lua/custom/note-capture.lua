-- note-capture.lua
--
-- The engine every capture in this config shares. It resolves today's daily
-- note, creates it when it does not exist, formats an entry, inserts it into a
-- section, writes it through the buffer when one is loaded and atomically
-- through a temp file when it is not -- and the float that collects the text.
-- One place for the write path is the point: the rules below are the ones that
-- cost real notes when they are got wrong.
--
-- The features on top are specs (tangent-capture.lua, daily-note.lua): a name,
-- the section the entry lands in, and how one entry is spelled.
--
-- Invariants this module is built around (see docs/guide/tangent-capture.md and
-- docs/guide/daily-note.md):
--   * No register, mark, jumplist entry or undo state belongs to a capture:
--     the float is its own scratch buffer and nothing is ever yanked, so
--     closing it is enough to leave the note you were in untouched.
--   * The write is durable the moment <CR> is pressed: it never waits for a
--     later :w of somebody else's buffer. When the target file *is* already
--     open in a buffer the text is appended through that buffer instead of the
--     file, because writing the file underneath a loaded buffer leaves the
--     buffer stale and its next :w silently reverts the entry.
--   * A crash between "user pressed <CR>" and "bytes on disk" must not be able
--     to truncate a note, hence the temp-file + rename in atomic_write().
--   * Timestamps are local time, matching the daily-note filename and the
--     `## Log` stamps they sit beside. Nothing else in this vault is UTC.

local M = {}

local VAULT = "~/notes"
local MAX_FLOAT_HEIGHT = 6

-- Mirror of plugins/obsidian.lua's daily_notes stanza, used only when
-- obsidian.nvim has not been loaded (it is lazy, ft=markdown). When it *is*
-- loaded its own client answers, so the two can never disagree in practice.
local DAILY_SUBDIR = "docs/30-dailynotes"
local DAILY_FORMAT = "%Y/%m/%Y-%m-%d"

local uv = vim.uv or vim.loop

--- Read a `g:` variable that may be set from Lua (booleans) or Vimscript
--- (0/1, "0"/"1"). Absent or empty means "use the default".
---@param name string
---@param default boolean
---@return boolean
function M.flag(name, default)
  local value = vim.g[name]
  if value == nil or value == "" then
    return default
  end
  return value == true or value == 1 or value == "1" or value == "true"
end

--- Today's daily note, resolved the way the vault actually lays it out.
---
--- obsidian.nvim is asked first when it is loaded, because it owns
--- `daily_notes.folder` and `daily_notes.date_format` -- the mirror below is
--- only for sessions that never load the plugin (a scratch buffer, a test).
---@return string
function M.daily_note_path()
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

--- Create `path` when it does not exist yet.
---
--- Prefers obsidian.nvim, which applies the vault's folder, frontmatter and
--- template rules; only falls back to copying the template verbatim.
---@param path string
---@return boolean ok, string|nil err
function M.ensure_file(path)
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

--- The number of `#`s on a markdown heading line, nil for anything else.
---@param line string
---@return integer|nil
local function heading_level(line)
  local hashes = line:match("^(#+)%s")
  if hashes then
    return #hashes
  end
  return nil
end

--- Does `line` read exactly `heading`, allowing the trailing whitespace some
--- editors leave behind? `"#### Tasks"` must not match `"#### Tasks later"`.
---@param line string
---@param heading string
---@return boolean
local function is_heading(line, heading)
  local hashes = heading:match("^(#+)")
  local name = heading:sub(#hashes + 1):gsub("^%s+", ""):gsub("%s+$", "")
  return line:match("^" .. hashes .. "%s+" .. vim.pesc(name) .. "%s*$") ~= nil
end

--- Insert `bullets` into the section of `lines` headed by `heading`.
---
--- Pure: returns a new list and never touches its input, so it can be
--- exercised without a vault (see daily-note_test.lua).
---
--- Entries go after the last non-blank line of the section rather than right
--- after the heading, which matters in two ways: a trailing `### Goal: <name>`
--- heading keeps capturing entries (the weekly note groups by goal), and the
--- blank line separating the section from the next heading stays where it is.
--- A section of any depth can be named -- the search stops at the next heading
--- of the same or a higher level, so `#### Tasks` runs to the `## Notepad`
--- that follows it. A missing section is appended at the end of the file.
---@param lines string[]
---@param heading string
---@param bullets string[]
---@return string[]
function M.insert(lines, heading, bullets)
  local out = {}
  for i = 1, #lines do
    out[i] = lines[i]
  end

  local hashes = heading:match("^(#+)")
  local level = hashes and #hashes or 2

  local at
  for i, line in ipairs(out) do
    if is_heading(line, heading) then
      at = i
      break
    end
  end

  if not at then
    while #out > 0 and out[#out]:match("^%s*$") do
      table.remove(out)
    end
    if #out > 0 then
      out[#out + 1] = ""
    end
    out[#out + 1] = heading
    at = #out
  end

  local stop = #out + 1
  for i = at + 1, #out do
    local child = heading_level(out[i])
    if child and child <= level then
      stop = i
      break
    end
  end

  local last = at
  for i = at + 1, stop - 1 do
    if out[i]:match("%S") then
      last = i
    end
  end

  for i = #bullets, 1, -1 do
    table.insert(out, last + 1, bullets[i])
  end
  return out
end

--- The markdown lines one entry occupies.
---
--- `prefix` is what the first line starts with and `suffix` what it ends with;
--- pasted multi-line text continues as an indented sub-line, which is the
--- shape existing entries in this vault use.
---@param text string
---@param prefix string
---@param suffix string?
---@return string[]
function M.bullet_lines(text, prefix, suffix)
  local lines = vim.split(vim.trim(text), "\n", { plain = true })
  while #lines > 1 and lines[#lines]:match("^%s*$") do
    table.remove(lines)
  end

  local out = {}
  for i, line in ipairs(lines) do
    if i == 1 then
      out[i] = prefix .. line .. (suffix or "")
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

  local tmp = string.format("%s/.%s.note-capture.tmp", dir, vim.fn.fnamemodify(path, ":t"))
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
function M.buffer_for(path)
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

--- Append `bullets` to a section of a note.
---
--- `path` nil means today's daily note. Blank bullets are a no-op: pressing
--- <CR> on an empty float is a cancel, not an entry.
---@param path string|nil
---@param heading string
---@param bullets string[]
---@return string|nil path, string|nil err
function M.append(path, heading, bullets)
  if type(bullets) ~= "table" or #bullets == 0 then
    return nil
  end

  path = path or M.daily_note_path()
  if not uv.fs_stat(path) then
    local ok, err = M.ensure_file(path)
    if not ok then
      return nil, err
    end
  end

  -- Read from the buffer when there is one: the on-disk copy may be behind it,
  -- and rebuilding the file from disk would throw the buffer's pending edits
  -- away underneath the user.
  local buf = M.buffer_for(path)
  local lines = buf and vim.api.nvim_buf_get_lines(buf, 0, -1, false) or vim.fn.readfile(path)
  lines = M.insert(lines, heading, bullets)

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

---@class CaptureMode
---@field name string          "task", "log", "tangent"
---@field label string         what a confirmation says: "Task"
---@field title string         border label: "Task > "
---@field heading string       section the entry lands in: "#### Tasks"
---@field bullet fun(text: string): string[]

---@class CaptureState
---@field win integer
---@field buf integer
---@field conf table
---@field modes CaptureMode[]
---@field mode integer
---@field oneshot boolean
---@field insert boolean
--- Where the entry goes: a literal path, a function returning one (so a target
--- that can change is read when the entry lands, not when the float opened), or
--- nil for today's daily note.
---@field path string|fun():string|nil

---@type CaptureState|nil
local state = nil

---@param st CaptureState
---@return CaptureMode
local function current_mode(st)
  return st.modes[st.mode]
end

--- Redraw the border label. A mode with more than one entry in `modes` is
--- switchable with <Tab>, and the label is the only thing that says which one
--- the keystroke is going to land in.
---@param st CaptureState
---@param mode CaptureMode
local function set_title(st, mode)
  st.conf.title = { { " " .. vim.trim(mode.title) .. " ", "FloatTitle" } }
  if vim.api.nvim_win_is_valid(st.win) then
    pcall(vim.api.nvim_win_set_config, st.win, st.conf)
  end
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
---@param st CaptureState
local function commit_float(st)
  local text = table.concat(vim.api.nvim_buf_get_lines(st.buf, 0, -1, false), "\n")
  local mode = current_mode(st)
  local oneshot = st.oneshot
  local target = type(st.path) == "function" and st.path() or st.path
  close_float()

  if text:match("%S") then
    local path, err = M.append(target, mode.heading, mode.bullet(text))
    if path then
      vim.notify(mode.label .. " → " .. vim.fn.fnamemodify(path, ":t"), vim.log.levels.INFO, { title = mode.name })
    else
      vim.notify(mode.label .. " NOT saved: " .. tostring(err), vim.log.levels.ERROR, { title = mode.name })
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
---@param st CaptureState
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

--- Open the capture float. `<CR>` saves, `<Esc>`/`<C-c>` cancels, `<Tab>`
--- switches between `modes` when there is more than one.
---@param opts { modes: CaptureMode[], mode: string|?, oneshot: boolean|?, path: string|? }|nil
function M.capture(opts)
  opts = opts or {}
  local modes = opts.modes
  if type(modes) ~= "table" or #modes == 0 then
    return
  end

  local start = 1
  if type(opts.mode) == "string" then
    for i, mode in ipairs(modes) do
      if mode.name == opts.mode then
        start = i
        break
      end
    end
  end

  if state then
    if vim.api.nvim_win_is_valid(state.win) then
      vim.api.nvim_set_current_win(state.win)
      vim.cmd("startinsert")
      return
    end
    state = nil
  end

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
    title = { { " " .. vim.trim(modes[start].title) .. " ", "FloatTitle" } },
    title_pos = "left",
    noautocmd = true,
    zindex = 60,
  }

  local st = {
    win = vim.api.nvim_open_win(buf, true, conf),
    buf = buf,
    conf = conf,
    modes = modes,
    mode = start,
    oneshot = opts.oneshot == true,
    insert = entered_insert,
    path = opts.path,
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

  local function cancel()
    local oneshot = st.oneshot
    close_float()
    if oneshot then
      vim.schedule(function()
        vim.cmd("qa!")
      end)
    end
  end

  map({ "i", "n" }, "<CR>", function()
    commit_float(st)
  end, "Save entry")
  map({ "i", "n" }, "<Esc>", cancel, "Cancel")
  map({ "i", "n" }, "<C-c>", cancel, "Cancel")

  if #modes > 1 then
    map({ "i", "n" }, "<Tab>", function()
      local next = st.mode % #st.modes + 1
      set_title(st, st.modes[next])
      st.mode = next
    end, "Switch what the entry is")
  end

  local group = vim.api.nvim_create_augroup("NoteCaptureFloat", { clear = true })
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
--- which is how nvim-daily-note finds it again.
---@return string|nil address
function M.ensure_server()
  if #vim.fn.serverlist() > 0 then
    return vim.v.servername
  end
  local ok, addr = pcall(vim.fn.serverstart)
  if not ok or type(addr) ~= "string" or addr == "" then
    vim.schedule(function()
      vim.notify("note capture: could not start RPC server; the system-wide hotkey will not reach this nvim", vim.log.levels.WARN)
    end)
    return nil
  end
  return addr
end

return M
