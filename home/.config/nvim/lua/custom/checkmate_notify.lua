-- checkmate_notify.lua
-- Lightweight @due notifier for checkmate.nvim via ntfy
-- Incremental + debounced to avoid slowdown on buffer open

local api = vim.api
local uv = vim.uv
local fmt = string.format

-- Load config
local cfg = require("custom.checkmate_notify_config")

-- -------------------------------------------------------------------------
-- Helpers ------------------------------------------------------------------

local function patch_template(tpl, ctx)
  return (tpl:gsub("{{(%w+)}}", function(k) return ctx[k] or "" end))
end

local function http_post(url, headers, body)
  local cmd = { "curl", "-sS", "-X", "POST" }
  for k, v in pairs(headers) do
    table.insert(cmd, "-H"); table.insert(cmd, fmt("%s:%s", k, v))
  end
  table.insert(cmd, url); table.insert(cmd, "-d"); table.insert(cmd, body)
  api.nvim_call_function("jobstart", { cmd, {} })
end

-- Parse @due(YYYY-MM-DD HH:MM) or @due(YYYY-MM-DD)
local function parse_due(line)
  local raw = line:match("@due%((.-)%)")
  if not raw then return nil end
  local y, m, d, h, mi = raw:match("^(%d%d%d%d)-(%d%d)-(%d%d)%s*(%d%d):(%d%d)$")
  if not y then y, m, d = raw:match("^(%d%d%d%d)-(%d%d)-(%d%d)$"); h, mi = "00", "00" end
  return os.time{ year=y, month=m, day=d, hour=h, min=mi }
end

-- Parse @warn_before(1d,01:00:00) → seconds list
local function parse_warns(line)
  local raw = line:match("@warn_before%((.-)%)")
  if not raw then return {} end
  local warns = {}
  for part in raw:gmatch("[^,]+") do
    part = part:match("^%s*(.-)%s*$")
    local sec
    if part:find("d$") then
      sec = tonumber(part:sub(1, -2)) * 86400
    else
      local hh, mm, ss = part:match("^(%d%d):(%d%d):(%d%d)$")
      if hh and mm then sec = (tonumber(hh)*3600 + tonumber(mm)*60 + tonumber(ss or "00")) end
    end
    if sec then table.insert(warns, sec) end
  end
  return warns
end

-- -------------------------------------------------------------------------
-- State --------------------------------------------------------------------

local notified = {}          -- task_id -> true
local buf_tasks = {}         -- bufnr -> { tasks, version }
local check_scheduled = false
local timer = uv.new_timer()

-- -------------------------------------------------------------------------
-- Incremental buffer scanning ----------------------------------------------

local function scan_buffer(bufnr)
  if not api.nvim_buf_is_loaded(bufnr) then return end
  if api.nvim_buf_get_option(bufnr, "filetype") ~= "markdown" then return end

  local version = api.nvim_buf_get_changedtick(bufnr)
  local cached = buf_tasks[bufnr]
  if cached and cached.version == version then return cached.tasks end

  local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local tasks = {}
  for ln, txt in ipairs(lines) do
    local due = parse_due(txt)
    if due then
      local id = fmt("%d:%d", bufnr, ln)
      table.insert(tasks, {
        id = id,
        bufnr = bufnr,
        line = ln,
        due = due,
        warns = parse_warns(txt),
        desc = txt,
      })
    end
  end

  buf_tasks[bufnr] = { tasks = tasks, version = version }
  return tasks
end

local function gather_tasks()
  local all = {}
  for _, buf in ipairs(api.nvim_list_bufs()) do
    local t = scan_buffer(buf)
    if t then vim.list_extend(all, t) end
  end
  return all
end

-- -------------------------------------------------------------------------
-- Notification -------------------------------------------------------------

local function notify_task(task, state, warning)
  if not cfg.notifications.enabled then return end

  local id = task.id .. (warning and ":" .. warning or "")
  if notified[id] then return end
  notified[id] = true

  local when = ({ overdue = "OVERDUE: ", due = "DUE NOW: ", advance = fmt("DUE in %d sec: ", warning) })[state]
  local msg = fmt("%s%s %s (%s)", when, os.date("%Y-%m-%d %H:%M", task.due),
                  task.desc, api.nvim_buf_get_name(task.bufnr))

  local title = cfg.notifications.ntfy.priority_map[state] or "default"
  local topic = patch_template(cfg.notifications.ntfy.topic_template,
                              { file = vim.fn.fnamemodify(api.nvim_buf_get_name(task.bufnr), ":t") })
  local body = vim.json.encode({ message = msg })

  if cfg.notifications.handler then
    cfg.notifications.handler(task.bufnr, task, title, task.due, warning)
  else
    http_post(topic .. "?title=" .. title, {}, body)
  end
end

-- -------------------------------------------------------------------------
-- Debounced checker --------------------------------------------------------

local function schedule_check()
  if check_scheduled then return end
  check_scheduled = true
  vim.defer_fn(function()
    check_scheduled = false
    if not cfg.notifications.enabled then return end
    local now = os.time()
    for _, t in ipairs(gather_tasks()) do
      if now >= t.due then
        notify_task(t, "overdue")
      else
        for _, w in ipairs(t.warns) do
          if now >= (t.due - w) then notify_task(t, "advance", w) end
        end
      end
    end
  end, 50)
end

-- -------------------------------------------------------------------------
-- Events -------------------------------------------------------------------

-- Only re-scan on actual text changes in markdown buffers
api.nvim_create_autocmd("TextChanged", {
  pattern = "*.md",
  callback = function(args)
    buf_tasks[args.buf] = nil
    schedule_check()
  end,
})

-- Periodic check (bounded to config interval, typically 5 min)
timer:start(0, cfg.notifications.check_interval * 1000, vim.schedule_wrap(schedule_check))

-- Startup overdue scan (once, deferred)
if cfg.notifications.notify_overdue_on_startup then
  vim.defer_fn(schedule_check, 100)
end

-- -------------------------------------------------------------------------
-- Command ------------------------------------------------------------------

api.nvim_create_user_command("CheckmateOverdue", function()
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_name(buf, "checkmate-overdue")
  api.nvim_win_set_buf(0, buf)

  local lines = {}
  local now = os.time()
  for _, t in ipairs(gather_tasks()) do
    if now >= t.due then
      local file = vim.fn.fnamemodify(api.nvim_buf_get_name(t.bufnr), ":t")
      table.insert(lines, fmt("%s\t%s\t%s", file, os.date("%Y-%m-%d %H:%M", t.due), t.desc))
    end
  end
  if #lines == 0 then lines = { "-- no overdue tasks" } end
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
end, {})

return true