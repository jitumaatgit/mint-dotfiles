-- random-note.lua
-- Opens a random markdown file from ~/notes on keymap press

local M = {}

function M.open_random_note()
  local notes_dir = vim.fn.expand('~/notes')
  local files = vim.fn.glob(notes_dir .. '/**/*.md', true, true)
  if #files == 0 then
    vim.notify('No markdown files found in ' .. notes_dir, vim.log.levels.WARN)
    return
  end
  local random_file = files[math.random(#files)]
  vim.cmd.edit(vim.fn.fnameescape(random_file))
end

vim.api.nvim_create_user_command('RandomNote', M.open_random_note, {})
vim.keymap.set('n', '<leader>nr', M.open_random_note, { desc = 'Open random note' })

return M