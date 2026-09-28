return {
  "rcarriga/nvim-notify",
  opts = {
    -- Use noice's render style for consistency
    render = "wrapped-compact",
    stages = "fade_in_slide_out",
    -- Long enough that a burst of alerts is actually readable while stacked.
    timeout = 5000,
    -- Show one window per message. With this on, repeated *identical* messages
    -- collapse into a single popup, which hides the fact that they repeated.
    merge_duplicates = false,
    max_width = 50,
    max_height = 10,
    background_colour = "#1e1e2e",
  },

  -- Replaces LazyVim's implicit `require("notify").setup(opts)` so the sound
  -- hook can wrap the module once nvim-notify has configured itself.
  config = function(_, opts)
    require("notify").setup(opts)
    require("custom.notify-sound").setup(require("notify"))
  end,
}