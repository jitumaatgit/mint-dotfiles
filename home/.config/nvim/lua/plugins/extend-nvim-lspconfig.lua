return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      marksman = {
        enabled = true, -- Re-enabled with completion disabled
        on_attach = function(client, bufnr)
          -- Disable completion provider to avoid space→dash conversion
          -- obsidian.nvim provides completion instead
          client.server_capabilities.completionProvider = nil
        end,
      },
      -- stylua: ignore
      ["*"] = {
        keys = {
          { "K", false }, -- Disable LazyVim's default K (hover) - using smart-peek instead
          -- { "gr", false }, -- disable references
          { "gd", function() Snacks.picker.lsp_definitions() end, desc = "Goto Definition", has = "definition" },
          { "gR", function() Snacks.picker.lsp_references() end, desc = "References", nowait = true },
          { "gI", function() Snacks.picker.lsp_implementations() end, desc = "Goto Implementation" },
          { "gy", function() Snacks.picker.lsp_type_definitions() end, desc = "Goto T[y]pe Definition" },
        }
      },
    },
  },
}
