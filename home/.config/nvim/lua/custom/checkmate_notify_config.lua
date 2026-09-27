-- checkmate_notify_config.lua
-- Configuration for checkmate_notify.lua
-- Place this next to checkmate_notify.lua

return {
  notifications = {
    enabled = true,
    check_interval = 300,
    notify_overdue_on_startup = true,

    ntfy = {
      topic_template = "checkmate/due/{{file}}",
      priority_map = { advance = "low", due = "default", overdue = "high" },
    },

    handler = nil,
  },
}