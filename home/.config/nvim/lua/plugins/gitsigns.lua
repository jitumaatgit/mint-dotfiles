return {
  "lewis6991/gitsigns.nvim",
  opts = {
    on_attach = function(bufnr)
      local gs = require("gitsigns")

      local function map(mode, l, r, desc)
        vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
      end

      map("n", "]h", gs.next_hunk, "Go to next hunk")
      map("n", "[h", gs.prev_hunk, "Go to previous hunk")
      map("n", "<leader>hp", gs.preview_hunk, "Preview hunk")
      map("n", "<leader>hs", gs.stage_hunk, "Stage hunk")
      map("n", "<leader>hr", gs.reset_hunk, "Reset hunk")
      map("n", "<leader>hu", gs.undo_stage_hunk, "Undo stage hunk")
      map({"o", "x"}, "ih", gs.select_hunk, "Select hunk text object")

      map("v", "<leader>hsf", function()
        local start_line = vim.fn.line "'<"
        local end_line = vim.fn.line "'>"
        local current_file = vim.fn.expand("%:t")
        local new_file = current_file:match("^([^_]+)_") and current_file:gsub("^([^_]+)_", "%1_") or current_file .. "_new"

        vim.cmd("split " .. new_file)

        vim.cmd("normal! gvp")

        vim.cmd("normal! d'\"<d'\">")

        vim.cmd("w")
      end, "Extract hunk to new file")
    end,
  },
}
