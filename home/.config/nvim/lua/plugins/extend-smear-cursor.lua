return {
  "sphamba/smear-cursor.nvim",
  event = "VeryLazy",
  cond = vim.g.neovide == nil and vim.env.OPENCODE_EDITOR == nil,
  opts = {
    legacy_computing_symbols_support = true,
    legacy_computing_symbols_support_vertical_bars = true,
    use_diagonal_blocks = true,
    -- Disable trail in some cases:
    -- .. for tiny horizontal/vertical movements
    -- min_horizontal_distance_smear = 4,
    -- min_vertical_distance_smear = 6,
    -- .. in insert mode, it looks pretty bad :/
    smear_insert_mode = false,
    -- .. in cmdline, as it prevents builtin behavior where I can write 2
    -- commands and still see the result of the first command.
    -- (which is very useful when editing hl or exploring options)
    smear_to_cmd = false,
    hide_target_hack = false,
    never_draw_over_target = false, -- for no termguicolors set true
    cursor_color = "none",
    time_interval = 10,
    stiffness = 0.65,
    trailing_stiffness = 0.4,
    damping = 1,
    distance_stop_animating = 0.3,
    max_length = 75,
  },
  specs = {
    -- disable mini.animate cursor
    {
      "nvim-mini/mini.animate",
      optional = true,
      opts = {
        cursor = { enable = false },
      },
    },
  },
}
