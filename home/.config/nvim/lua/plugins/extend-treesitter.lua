return {
  "nvim-treesitter/nvim-treesitter",
  lazy = false,
  build = ":TSUpdate",
  -- Still getting parser compiler errors going to disable for now.
  -- config = function()
  --   -- require("nvim-treesitter").install({
  --   --   -- "lua",
  --   --   -- "regex",
  --   --   -- -- "sql",
  --   --   -- "json",
  --   --   -- -- "csv",
  --   --   -- "javascript",
  --   --   -- "html",
  --   --   -- "markdown",
  --   --   -- "markdown_inline",
  --   --   -- -- "elixir",
  --   --   -- -- "powershell",
  --   --   -- "python",
  --   --   -- "yaml",
  --   --   -- "bash",
  --   -- })
  -- end,
}
