-- Play a sound whenever a notification pops up.
--
-- nvim-notify has no sound of its own, so wrap `vim.notify` rather than each
-- caller: pomo, checkmate and every LSP message then get one for free.
-- ntfy-delivered desktop popups are handled in ~/.config/ntfy/desktop-notify.sh.

local M = {}

local SOUND = "/usr/share/sounds/freedesktop/stereo/dialog-information.oga"

-- Guards against a player piling up. A blocked audio device otherwise leaves
-- one stuck process per notification, which is how a burst of alerts once
-- produced tens of thousands of them.
local MIN_INTERVAL_MS = 200
local last_played = 0

---@param level integer|nil vim.log.levels value the notification was raised at
function M.play(level)
  if level == vim.log.levels.DEBUG or vim.g.notify_sound_disabled then
    return
  end
  local now = vim.uv.now()
  if now - last_played < MIN_INTERVAL_MS then
    return
  end
  last_played = now
  -- `timeout` so a player that cannot reach the device dies instead of hanging.
  vim.system({ "timeout", "5", "paplay", SOUND }, { detach = true, stdout = false, stderr = false })
end

---@param notify table the nvim-notify module, already set up
function M.setup(notify)
  -- Wrap the module's own `notify` rather than `vim.notify`. LazyVim swaps
  -- `vim.notify` for a buffer that collects notifications until the real
  -- notifier is installed and then replays them; wrapping that buffer makes
  -- every replayed notification re-enter it, so the replay never terminates.
  -- The module field is untouched by that swap, so there is no ordering to get
  -- right, and callers using the module directly are covered as well.
  local original = notify.notify
  M.wrapped = function(msg, level, opts)
    M.play(level)
    return original(msg, level, opts)
  end
  notify.notify = M.wrapped
  vim.notify = M.wrapped
end

return M
