-- 2026-04-26 added to disabled plugins as it was spamming errors and hanging neovim when `g o` keymap was pressed
return {
  {
    "NickvanDyke/opencode.nvim",
    dependencies = {
      -- Recommended for `ask()` and `select()`.
      -- Required for `snacks` provider.
      ---@module 'snacks' <- Loads `snacks.nvim` types for configuration intellisense.
      { "folke/snacks.nvim", opts = { input = {}, picker = {}, terminal = {} } },
    },
    config = function()
      ---@type opencode.Opts
      vim.g.opencode_opts = {
        -- Your configuration, if any — see `lua/opencode/config.lua`, or "goto definition".
        -- port = 3000, -- dont enable this, opencode.nvim will not find the process if I set port manually (on my windows
        -- setup)
        -- provider is termporarily disabled and maintainer is working on fix. will have to use wezterm window split for
        -- now
        -- provider = {
        --   enabled = "snacks",
        --   snacks = {
        --     auto_close = true,
        --     win = {
        --       position = "right",
        --       enter = false,
        --       wo = {
        --         winbar = "",
        --       },
        --       bo = {
        --         filetype = "opencode_terminal",
        --       },
        --     },
        --   },
        -- },
      }

      -- Required for `opts.events.reload`.
      vim.o.autoread = true

      -- Recommended/example keymaps.
      vim.keymap.set({ "n", "x" }, "<leader>oa", function()
        require("opencode").ask("@this: ", { submit = true })
      end, { desc = "Ask opencode" })

      vim.keymap.set({ "n", "x" }, "<leader>ox", function()
        require("opencode").select()
      end, { desc = "Execute opencode action…" })

      vim.keymap.set({ "n", "x" }, "go", function()
        require("opencode").prompt("@this")
      end, { desc = "Add to opencode" })

      vim.keymap.set({ "n", "t" }, "<leader>ot", function()
        require("opencode").toggle()
      end, { desc = "Toggle opencode" })

      -- Toggle opencode window width (maximize/minimize)
      vim.keymap.set("n", "<leader>om", function()
        local opencode_win = nil
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          local buf = vim.api.nvim_win_get_buf(win)
          local ft = vim.api.nvim_get_option_value("filetype", { buf = buf })
          if ft == "opencode_terminal" then
            opencode_win = win
            break
          end
        end

        if not opencode_win then
          vim.notify("Opencode window not found", vim.log.levels.WARN)
          return
        end

        local current_width = vim.api.nvim_win_get_width(opencode_win)
        local total_width = vim.o.columns
        local max_width = math.floor(total_width * 0.8)
        local default_width = math.floor(total_width * 0.35)

        local new_width = current_width >= max_width - 5 and default_width or max_width
        vim.api.nvim_win_set_width(opencode_win, new_width)
      end, { desc = "Toggle opencode maximize" })

      -- Toggle focus between code window and opencode terminal
      vim.keymap.set({ "n", "t" }, "<leader>oo", function()
        local opencode_win = nil
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          local buf = vim.api.nvim_win_get_buf(win)
          local ft = vim.api.nvim_get_option_value("filetype", { buf = buf })
          if ft == "opencode_terminal" then
            opencode_win = win
            break
          end
        end

        local current_win = vim.api.nvim_get_current_win()

        if opencode_win and current_win ~= opencode_win then
          vim.api.nvim_set_current_win(opencode_win)
        elseif current_win == opencode_win then
          vim.cmd("wincmd p")
        else
          vim.notify("Opencode window not found", vim.log.levels.WARN)
        end
      end, { desc = "Toggle opencode focus" })

      -- You may want these if you stick with the opinionated "<C-a>" and "<C-x>" above — otherwise consider "<leader>o".
      -- vim.keymap.set("n", "+", "<C-a>", { desc = "Increment", noremap = true })
      -- vim.keymap.set("n", "-", "<C-x>", { desc = "Decrement", noremap = true })
    end,
  },
}
