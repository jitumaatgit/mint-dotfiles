-- Patch trouble.nvim section.refresh to ensure self.fetching is always reset.
--
-- Upstream leaves `fetching = true` when M:main_call bails (see section.lua
-- lines 92-118: not-main, preview-window, or switched-buffers paths all
-- return without invoking the inner fn, so the surrounding Promise never
-- resolves and .finally never runs). That pins section.fetching = true,
-- wedging the throttle uv_check callback (util.lua:171) at ~full CPU and
-- leaking Lua VM state until nvim restart.
--
-- We wrap M.refresh with a 3s uv_timer watchdog that forces fetching = false
-- if upstream hasn't already done so, and disarms the timer via .finally
-- when upstream's promise chain completes normally.

local M = {}

local SECS = 3000 -- ms; comfortably above trouble's internal 2s Promise timeout

local patched = false

local function apply()
  if patched then
    return
  end
  local ok, section = pcall(require, "trouble.view.section")
  if not ok then
    return
  end
  patched = true

  local uv = vim.uv or vim.loop
  local orig = section.refresh

  section.refresh = function(self, opts)
    local timer = uv.new_timer()
    timer:start(SECS, 0, function()
      timer:close()
      vim.schedule(function()
        if self.fetching then
          self.fetching = false
        end
      end)
    end)

    local p = orig(self, opts)

    if p and p.finally then
      p:finally(function()
        if not timer:is_closing() then
          if timer:is_active() then
            timer:stop()
          end
          timer:close()
        end
      end)
    end

    return p
  end
end

function M.setup()
  apply()
  -- trouble.nvim is lazy-loaded; retry on LazyLoad in case it wasn't ready.
  vim.api.nvim_create_autocmd("User", {
    pattern = "LazyLoad",
    nested = true,
    once = true,
    callback = apply,
  })
end

return M
