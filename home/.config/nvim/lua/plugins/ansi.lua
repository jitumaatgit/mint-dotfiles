return {
  "0xferrous/ansi.nvim",
  config = function()
    require("ansi").setup({
      auto_enable = true,
      auto_enable_stdin = true,
      theme = "catppuccin",
      -- netrw is what `gf` lands in for http(s) fetches
      filetypes = { "log", "ansi", "txt", "output", "netrw" },
    })
  end,
}