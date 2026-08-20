-- Telescope is installed but has no keybindings
-- It's only used by obsidian.nvim and obsidian-task-filter for their pickers
-- My default picker (snacks) handles <leader>ff, <leader>fg, etc.
-- note: telescope is used by 99 for model switching using a picker. I will have to make sure its loaded when 99 calls
-- for it.
return {
  "nvim-telescope/telescope.nvim",
  cmd = "Telescope",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  -- No keys defined - telescope is only loaded when obsidian/my module calls it
  opts = {
    defaults = {
      -- layout_strategy = "ivy", -- wasnt working with kanban.nvim
      layout_config = {
        height = 0.30,
      },
      mappings = {
        i = {
          ["<C-j>"] = "move_selection_next",
          ["<C-k>"] = "move_selection_previous",
        },
      },
    },
  },
}
