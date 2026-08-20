-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
-- shorthand for mapping keys
local map = vim.keymap.set

-- gj/gk for wrapped lines; add to jumplist when jumping >= 3 lines
vim.keymap.set(
  { "n", "x" },
  "j",
  [[v:count ? (v:count >= 3 ? "m'" . v:count . 'j' : 'j') : 'gj']],
  { noremap = true, expr = true, silent = true }
)

vim.keymap.set(
  { "n", "x" },
  "k",
  [[v:count ? (v:count >= 3 ? "m'" . v:count . 'k' : 'k') : 'gk']],
  { noremap = true, expr = true, silent = true }
)

vim.keymap.set("i", "jj", "<Esc>")
vim.keymap.set("i", "kk", "<Esc>")
vim.keymap.set("i", "jk", "<Esc>")
vim.keymap.set("i", "kj", "<Esc>")
vim.keymap.set("t", "<C-n>", "<C-\\><C-n>", { desc = "Exit terminal mode" })
vim.keymap.set("t", "<Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })
vim.keymap.set("n", "gj", [[/^#\+ .*<CR>]], { desc = "Next markdown heading" })
vim.keymap.set("n", "gk", [[?^#\+ .*<CR>]], { desc = "Previous markdown heading" })

-- Pressing Esc clears search highlight
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<cr>")

-- Add undo break-points
map("i", ",", ",<c-g>u")
map("i", ".", ".<c-g>u")
map("i", ";", ";<c-g>u")

-- smart deletion, dd
-- It solves the issue, where you want to delete empty line, but dd will override you last yank.
-- Code above will check if u are deleting empty line, if so - use black hole register.
-- [src: https://www.reddit.com/r/neovim/comments/w0jzzv/comment/igfjx5y/?utm_source=share&utm_medium=web2x&context=3]
local function smart_dd()
  if vim.api.nvim_get_current_line():match("^%s*$") then
    return '"_dd'
  else
    return "dd"
  end
end

vim.keymap.set("n", "dd", smart_dd, { noremap = true, expr = true })

-- Map Shift+Enter to insert a newline in normal mode
vim.keymap.set("n", "<S-CR>", "a<CR><ESC>", { desc = "Split line" })
-- Map Shift+Enter in insert mode
vim.keymap.set("i", "<S-CR>", "<CR>", { desc = "Split line" })

-- UFO fold keymaps
vim.keymap.set("n", "zR", require("ufo").openAllFolds, { desc = "Open all folds" })
vim.keymap.set("n", "zM", require("ufo").closeAllFolds, { desc = "Close all folds" })
vim.keymap.set("n", "zr", require("ufo").openFoldsExceptKinds, { desc = "Open folds except kinds" })
vim.keymap.set("n", "zm", require("ufo").closeFoldsWith, { desc = "Close folds with" })

-- Smart peek: UFO peek → Custom fold peek → LSP hover
vim.keymap.set("n", "K", function()
  require("config.smart-peek").smart_peek()
end, { desc = "Smart peek (fold or LSP hover)" })
