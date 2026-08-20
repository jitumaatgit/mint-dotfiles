return {
  "stevearc/aerial.nvim",
  -- Optional dependencies
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "nvim-tree/nvim-web-devicons",
  },
  config = function()
    require("plugins.pluginconfig.aerial")
  end,
}
