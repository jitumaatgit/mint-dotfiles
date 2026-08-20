-- bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)
-- make sure our lua files are discoverable
vim.opt.rtp:append(vim.fn.stdpath("config") .. "/lua")

-- load plugins
local plugins = require("custom.plugins")
require("lazy").setup(plugins)

-- load custom settings
require("custom.omp-prompt").setup()
-- lint configuration is now handled within the plugin specs
-- Apply colorscheme after plugins load
vim.o.termguicolors = true
vim.cmd('colorscheme catppuccin')