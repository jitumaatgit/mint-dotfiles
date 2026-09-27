return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      marksman = {
        enabled = true, -- Re-enabled with completion disabled
        root_dir = function(fname)
          if type(fname) == "number" then
            fname = vim.api.nvim_buf_get_name(fname)
          end
          return vim.fs.dirname(vim.fs.find(".git", { path = fname, upward = true })[1]) or vim.fn.getcwd()
        end,
        on_attach = function(client, bufnr)
          -- Disable completion provider to avoid space→dash conversion
          -- obsidian.nvim provides completion instead
          client.server_capabilities.completionProvider = nil
          -- Detach from large files to avoid slowdown
          if vim.api.nvim_buf_line_count(bufnr) > 5000 then
            vim.lsp.buf_detach_client(bufnr, client.id)
          end
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
