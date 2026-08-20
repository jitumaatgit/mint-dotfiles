local M = {}

-- Autocmds are automatically loaded on VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Apply custom bold color for markdown files
vim.api.nvim_create_autocmd({ "ColorScheme", "FileType" }, {
  pattern = { "*", "markdown" },
  callback = function()
    if
      vim.bo.filetype == "markdown" or (vim.tbl_contains(vim.api.nvim_get_autocmds({ event = "ColorScheme" }), true))
    then
      vim.api.nvim_set_hl(0, "@markup.strong", {
        fg = "#f38ba8",
        bold = true,
      })
    end
  end,
})




-- Enable rainbow_csv and csvview for CSV files
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = { "*.csv", "*.tsv" },
  callback = function()
    vim.opt_local.wrap = false
    vim.bo.filetype = "rfc_csv"
    vim.schedule(function()
      if vim.fn.exists(":CsvViewToggle") > 0 then
        vim.cmd("CsvViewEnable")
      end
    end)
  end,
})

-- Set PowerShell execution policy to Unrestricted for LSP
-- Note: Scope CurrentUser does NOT require admin privileges
vim.api.nvim_create_autocmd("VimEnter", {
  pattern = "*",
  callback = function()
    if vim.fn.has("win32") == 1 then
      vim.fn.jobstart(
        {
          "powershell.exe",
          "-NoProfile",
          "-Command",
          "Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Unrestricted -Force",
        },
        { on_exit = function() end, detach = true }
      )
    end
  end,
  once = true,
})

-- Ensure PowerShell files are detected with correct filetype
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = { "*.ps1", "*.psm1", "*.psd1", "*.ps1xml" },
  callback = function()
    vim.bo.filetype = "ps1"
  end,
})

-- Enable nvim-navic breadcrumbs in winbar for PowerShell files
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    if vim.bo.filetype == "ps1" and args.data and args.data.client_id then
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if client and client.name == "powershell_es" then
        vim.api.nvim_create_autocmd("CursorHold", {
          buffer = 0,
          callback = function()
            local navic = require("nvim-navic")
            if navic.is_available() then
              vim.wo.winbar = navic.get_location()
            end
          end,
        })
      end
    end
  end,
})

return M
