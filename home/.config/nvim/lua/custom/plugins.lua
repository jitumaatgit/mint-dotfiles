return {
  {
    "neovim/nvim-lspconfig",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      -- Configure lua_ls using vim.lsp.config (nvim 0.11+)
      vim.lsp.config('lua_ls', {
        settings = {
          Lua = {
            diagnostics = {
              globals = { 'vim' },
            },
          },
        },
      })
      vim.lsp.enable('lua_ls')
    end,
  },
  {
    "nvimtools/none-ls.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local null_ls = require("null-ls")
      null_ls.setup({
        sources = {
          -- none-ls dropped the luacheck builtin; custom source instead
          require("custom.luacheck"),
        },
      })
    end,
  },
}