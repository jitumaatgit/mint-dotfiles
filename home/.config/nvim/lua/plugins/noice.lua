return {
  "folke/noice.nvim",
  event = "VeryLazy",
  opts = {
    notify = {
      enabled = true,
    },
    messages = {
      enabled = true,
      view = "notify",
      view_error = "notify",
      view_warn = "notify",
      view_history = "messages",
    },
    lsp = {
      progress = {
        enabled = true,
      },
      override = {
        ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
        ["vim.lsp.util.stylize_markdown"] = true,
        ["cmp.entry.get_documentation"] = true,
      },
    },
    presets = {
      bottom_search = true,
      command_palette = true,
      long_message_to_split = true,
      inc_rename = false,
      lsp_doc_border = false,
    },
    views = {
      mini = {
        position = {
          row = 0,
          col = "100%",
        },
      },
      notify = {
        position = {
          row = 0,
          col = "100%",
        },
      },
    },
  },
  keys = {
    { "<leader>sn", function() require("noice").cmd("pick") end, desc = "Noice: Notification Picker" },
    { "<leader>sna", function() require("noice").cmd("all") end, desc = "Noice: All Messages" },
    { "<leader>n", function() require("noice").cmd("pick") end, desc = "Noice: Notifications" },
  },
}
