-- Play a sound whenever a notification pops up.
--
-- nvim-notify has no sound of its own, so wrap `vim.notify` rather than each
-- caller: pomo, checkmate and every LSP message then get one for free.
-- ntfy-delivered desktop popups are handled in ~/.config/ntfy/desktop-notify.sh.

local M = {}

local SOUND = "/usr/share/sounds/freedesktop/stereo/dialog-information.oga"

---@param level integer|nil vim.log.levels value the notification was raised at
function M.play(level)
  if level == vim.log.levels.DEBUG then
    return
  end
  -- detached and silent: a missing sound device must not print over the UI
  vim.system({ "paplay", SOUND }, { detach = true, stdout = false, stderr = false })
end

function M.setup()
  if vim.g.notify_sound_disabled then
    return
  end
  local notify = vim.notify
  vim.notify = function(msg, level, opts)
    M.play(level)
    return notify(msg, level, opts)
  end
end

return M
