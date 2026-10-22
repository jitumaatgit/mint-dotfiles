return {
  {
    "neovide-config",
    virtual = true,
    config = function()
      if not vim.g.neovide then return end
      vim.g.neovide_scale_factor = 1.0
      vim.g.neovide_cursor_animation_length = 0.06
      vim.g.neovide_scroll_animation_length = 0.15
      vim.g.neovide_floating_blur_amount_x = 2.0
      vim.g.neovide_floating_blur_amount_y = 2.0
    end,
  },
}