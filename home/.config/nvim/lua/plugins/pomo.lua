-- Reuse the topic from the checkmate-due-notify config so every alert lands in
-- one place. Returns nil if the file is missing, which disables the notifier
-- rather than erroring.
local function ntfy_topic()
  local path = vim.fn.expand("~/.config/checkmate-due-notify/config.json")
  if vim.fn.filereadable(path) == 0 then
    return nil
  end
  local ok, cfg = pcall(vim.json.decode, table.concat(vim.fn.readfile(path), "\n"))
  return ok and cfg.topic or nil
end

---A `pomo.Notifier` that pushes timer completions to ntfy. Used for every timer
---the pomo run owns, so a break that ends while nvim sits in the background
---still reaches the phone.
---@param timer pomo.Timer
---@param opts { priority: string?, tags: string? }|?
local function ntfy(timer, opts)
  opts = opts or {}
  return {
    start = function() end,
    stop = function() end,
    tick = function() end,
    hide = function() end,
    show = function() end,
    done = function()
      local topic = ntfy_topic()
      if not topic then
        return
      end
      local name = timer.name or ("Timer %d"):format(timer.id)
      local duration = require("pomo.util").format_time(timer.time_limit)
      local reps = timer.max_repetitions and timer.max_repetitions > 0
          and (" [%d/%d]"):format(timer.repetitions + 1, timer.max_repetitions)
        or ""
      -- Flags must precede the topic: `ntfy publish [OPTIONS..] TOPIC [MESSAGE..]`
      -- folds anything after the topic into the message text.
      vim.system({
        "ntfy", "publish",
        "-t", ("%s done"):format(name),
        "-m", ("%s (%s) finished%s."):format(name, duration, reps),
        "-p", opts.priority or "high",
        "-T", opts.tags or "alarm_clock,white_check_mark",
        topic,
      }, { detach = true, stdout = false, stderr = false })
    end,
  }
end

return {
  "epwalsh/pomo.nvim",
  version = "*",
  lazy = true,
  cmd = { "TimerStart", "TimerRepeat", "TimerSession" },
  dependencies = { "rcarriga/nvim-notify" },
  opts = {
    update_interval = 1000,
    notifiers = {
      {
        name = "Default",
        opts = {
          sticky = true,
          title_icon = "󱎫",
          text_icon = "󰄉",
        },
      },
      { name = "System" },
      { init = ntfy },
    },
    timers = {
      -- `timers[name]` replaces `notifiers` wholesale for that timer, so the
      -- ntfy notifier has to be repeated here or break timers stay local.
      Break = { { name = "System" }, { init = ntfy } },
    },
    sessions = {
      pomodoro = {
        { name = "Work", duration = "25m" },
        { name = "Short Break", duration = "5m" },
        { name = "Work", duration = "25m" },
        { name = "Short Break", duration = "5m" },
        { name = "Work", duration = "25m" },
        { name = "Long Break", duration = "15m" },
      },
    },
  },
}
