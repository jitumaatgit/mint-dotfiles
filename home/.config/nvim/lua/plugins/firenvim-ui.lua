return {
  -- Disable statusline and heavy UI under Firenvim
  { "nvim-lualine/lualine.nvim", cond = function() return not vim.g.started_by_firenvim end },
  { "akinsho/bufferline.nvim", cond = function() return not vim.g.started_by_firenvim end },
  { "folke/noice.nvim", cond = function() return not vim.g.started_by_firenvim end },
  { "rcarriga/nvim-notify", cond = function() return not vim.g.started_by_firenvim end },
}