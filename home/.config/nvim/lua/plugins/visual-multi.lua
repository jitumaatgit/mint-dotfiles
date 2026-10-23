-- vim-visual-multi: multiple cursors (Ctrl-N to select word under cursor, etc.)
-- https://github.com/mg979/vim-visual-multi
-- Docs: :help visual-multi, :help vm-mappings

return {
  "mg979/vim-visual-multi",
  branch = "master",
  init = function()
    -- Leader used for VM-specific commands (default '\'). Set before plugin loads.
    vim.g.VM_leader = "\\"

    -- Default mappings are enabled. Override individual maps here if needed, e.g.:
    -- vim.g.VM_maps = {
    --   ["Find Under"] = "<C-d>",
    --   ["Find Subword Under"] = "<C-d>",
    -- }
    vim.g.VM_maps = vim.empty_dict()

    -- Show VM status in statusline? (optional)
    -- vim.g.VM_show_warnings = 1
  end,
}
