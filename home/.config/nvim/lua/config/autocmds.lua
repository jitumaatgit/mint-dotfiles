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

-- (PowerShell autocmds removed — not applicable on Linux)

return M
