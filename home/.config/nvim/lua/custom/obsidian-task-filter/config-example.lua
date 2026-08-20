-- Example configuration for obsidian-task-filter
-- Add this to your Neovim configuration (e.g., init.lua or a separate file)

-- Option 1: Basic setup with telescope (recommended)
require("obsidian-task-filter").setup({
  picker = "telescope",
  show_completed = false,
  preview_context = 3,
  format = "{filename}:{line} [{tags}] {task}",
})

-- Option 2: Setup with fzf-lua
-- require("obsidian-task-filter").setup({
--   picker = "fzf-lua",
--   show_completed = false,
--   preview_context = 3,
-- })

-- Option 3: Minimal setup (uses vim.ui.select)
-- require("obsidian-task-filter").setup()

-- Keybindings for quick access
vim.keymap.set("n", "<leader>ot", ":ObsidianTasksByTag ", { desc = "Filter tasks by tag" })

-- Quick access to common tags
vim.keymap.set("n", "<leader>ow", function()
  vim.cmd("ObsidianTasksByTag work")
end, { desc = "Show work tasks" })

vim.keymap.set("n", "<leader>op", function()
  vim.cmd("ObsidianTasksByTag personal")
end, { desc = "Show personal tasks" })

vim.keymap.set("n", "<leader>ou", function()
  vim.cmd("ObsidianTasksByTag urgent")
end, { desc = "Show urgent tasks" })

-- Advanced: Interactive tag selection with telescope
-- This allows you to select multiple tags using <Tab>
local function select_tags_with_telescope()
  local ok, obsidian = pcall(require, "obsidian")
  if not ok then
    vim.notify("obsidian.nvim not available", vim.log.levels.ERROR)
    return
  end
  
  local client = obsidian.get_client()
  client:list_tags_async(nil, function(tags)
    if #tags == 0 then
      vim.notify("No tags found in vault", vim.log.levels.WARN)
      return
    end
    
    require("telescope.pickers").new({}, {
      prompt_title = "Select Tags (Tab to multi-select, Enter to confirm)",
      finder = require("telescope.finders").new_table({
        results = tags,
      }),
      sorter = require("telescope.config").values.generic_sorter({}),
      attach_mappings = function(prompt_bufnr)
        local actions = require("telescope.actions")
        local action_state = require("telescope.actions.state")
        
        actions.select_default:replace(function()
          local picker = action_state.get_current_picker(prompt_bufnr)
          local selections = picker:get_multi_selection()
          
          -- If no multi-selection, use current selection
          if #selections == 0 then
            local selection = action_state.get_selected_entry()
            if selection then
              selections = { selection }
            end
          end
          
          local selected_tags = {}
          for _, selection in ipairs(selections) do
            table.insert(selected_tags, selection.value)
          end
          
          actions.close(prompt_bufnr)
          
          if #selected_tags > 0 then
            require("obsidian-task-filter").filter_tasks_by_tags(selected_tags)
          end
        end)
        
        return true
      end,
    }):find()
  end)
end

vim.keymap.set("n", "<leader>oT", select_tags_with_telescope, { desc = "Select tags interactively" })

-- Example: Create an autocommand to show tasks when opening a file with specific tags
-- vim.api.nvim_create_autocmd("BufEnter", {
--   pattern = "*.md",
--   callback = function()
--     local ok, obsidian = pcall(require, "obsidian")
--     if not ok then return end
--     
--     local client = obsidian.get_client()
--     local note = client:current_note()
--     if note and note:has_tag("daily") then
--       -- Show tasks from files tagged with "daily"
--       -- Uncomment the next line to auto-show tasks
--       -- require("obsidian-task-filter").filter_tasks_by_tags({"daily"})
--     end
--   end,
-- })
