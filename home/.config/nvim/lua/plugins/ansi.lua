return {
  "0xferrous/ansi.nvim",
  config = function()
    require("ansi").setup({
      auto_enable = true,
      auto_enable_stdin = true,
      theme = "catppuccin",
      filetypes = { "log", "ansi", "txt", "output" },
    })
  end,
}