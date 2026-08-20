return {
  "nvim-treesitter/nvim-treesitter",
  lazy = false,
  build = ":TSUpdate",
  opts = {
    ensure_installed = {
      "markdown",
      "markdown_inline",
      "lua",
      "bash",
      "rust",
      "python",
    },
  },
}
