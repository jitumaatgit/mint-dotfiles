return {
  "sindrets/diffview.nvim",
  cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory" },
  keys = {
    { "<leader>gv", "<cmd>DiffviewOpen<cr>", desc = "Diffview" },
    { "<leader>gV", "<cmd>DiffviewClose<cr>", desc = "Diffview Close" },
    { "<leader>gf", "<cmd>DiffviewFileHistory %<cr>", desc = "File History" },
  },
  opts = {},
}
