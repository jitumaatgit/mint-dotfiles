-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- We deliberately import the octo extra at the end of lua/plugins/cmp.lua,
-- AFTER our nvim-cmp spec, so extras.lang.git's cmp hook finds a populated
-- opts.sources (enabling octo via lazyvim.json instead crashes startup at
-- extras/lang/git.lua). LazyVim's import-order check warns about that
-- deliberate ordering, so disable it here.
vim.g.lazyvim_check_order = false
vim.opt.scrolloff = 0 -- line buffer above and below
vim.opt.swapfile = false

-- sqlite_clib_path is resolved at startup by lua/_sqlite_path.lua (see init.lua).

-- set textwidth (default 80)
vim.opt.textwidth = 120

-- UFO folding requirements
vim.o.foldcolumn = "1" -- Show fold column
vim.o.foldlevel = 99 -- Large value required by ufo
vim.o.foldlevelstart = 99 -- Large value required by ufo
vim.o.foldenable = true -- Enable folding

