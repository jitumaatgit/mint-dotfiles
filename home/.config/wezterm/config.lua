-- Local overrides for wezterm.lua.
--
-- wezterm auto-loads only wezterm.lua, so this file does nothing on its own --
-- wezterm.lua requires it near the end and copies these keys over the top,
-- which is why they win over anything set there. Keep this file to plain data:
-- it is merged key by key, so functions and nested tables are not applied.
local config = {}

-- Requires a compositor to be visible. Under a bare X session with no
-- compositing WM, the window is simply opaque and these values are inert.
config.window_background_opacity = 0.85
config.text_background_opacity = 0.7

return config
