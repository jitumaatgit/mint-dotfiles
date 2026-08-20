return {
  {
    "folke/snacks.nvim",
    -- snacks.terminal defaults to $SHELL (zsh on this machine); no override needed.
    -- (Windows version set opts.terminal.shell = "/usr/bin/bash.exe" for Git Bash — dropped on Linux.)
    keys = {
      -- I use this keymap with mini.files, but snacks explorer was taking over
      -- https://github.com/folke/snacks.nvim/discussions/949
      { "<leader>e", false },
      { "<leader>n", false }, -- disable notification history picker
      {
        "<leader>sg",
        function()
          Snacks.picker.grep({
            -- Exclude results from grep picker
            -- I think these have to be specified in gitignore syntax
            exclude = { "dictionaries/words.txt" },
          })
        end,
        desc = "Grep",
      },
      -- Open git log in vertical view
      {
        "<leader>gl",
        function()
          Snacks.picker.git_log({
            finder = "git_log",
            format = "git_log",
            preview = "git_show",
            confirm = "git_checkout",
            layout = "vertical",
          })
        end,
        desc = "Git Log",
      },
      -- -- Iterate through incomplete tasks in Snacks_picker
      {
        -- -- You can confirm in your teminal lamw26wmal with:
        -- -- rg "^\s*-\s\[ \]" test-markdown.md
        "<leader>tt",
        function()
          Snacks.picker.grep({
            prompt = " ",
            -- pass your desired search as a static pattern
            search = "^\\s*- \\[ \\]",
            -- we enable regex so the pattern is interpreted as a regex
            regex = true,
            -- no "live grep" needed here since we have a fixed pattern
            live = false,
            -- restrict search to the current working directory
            dirs = { vim.fn.getcwd() },
            args = {
              "--no-ignore",
              "--glob",
              "!docs/90-archives/**",
              "--glob",
              "!docs/50-templates/**",
              "--glob",
              "!docs/plannotator/plans/**",
            },
            on_show = function()
              vim.cmd.stopinsert()
            end,
            finder = "grep",
            format = "file",
            show_empty = true,
            supports_live = false,
            layout = "ivy",
          })
        end,
        desc = "[P]Search for incomplete tasks",
      },
      -- -- Iterate throuth completed tasks in Snacks_picker lamw26wmal
      {
        "<leader>tc",
        function()
          Snacks.picker.grep({
            prompt = " ",
            -- pass your desired search as a static pattern
            search = "^\\s*- \\[x\\] `done:",
            -- we enable regex so the pattern is interpreted as a regex
            regex = true,
            -- no "live grep" needed here since we have a fixed pattern
            live = false,
            -- restrict search to the current working directory
            dirs = { vim.fn.getcwd() },
            -- include files ignored by .gitignore
            args = { "--no-ignore" },
            -- Start in normal mode
            on_show = function()
              vim.cmd.stopinsert()
            end,
            finder = "grep",
            format = "file",
            show_empty = true,
            supports_live = false,
            layout = "ivy",
          })
        end,
        desc = "[P]Search for complete tasks",
      },
      -- -- List git branches with Snacks_picker to quickly switch to a new branch
      {
        "<M-b>",
        function()
          Snacks.picker.git_branches({
            layout = "select",
          })
        end,
        desc = "Branches",
      },
      -- Used in LazyVim to view the different keymaps, this by default is
      -- configured as <leader>sk but I run it too often
      -- Sometimes I need to see if a keymap is already taken or not
      -- {
      --   "<M-k>",
      --   function()
      --     Snacks.picker.keymaps({
      --       layout = "vertical",
      --     })
      --   end,
      --   desc = "Keymaps",
      -- },
      -- File picker
      {
        "<leader><space>",
        function()
          Snacks.picker.files({
            finder = "files",
            format = "file",
            show_empty = true,
            supports_live = true,
            -- In case you want to override the layout for this keymap
            -- layout = "vscode",
          })
        end,
        desc = "Find Files",
      },
      -- Navigate my buffers
      {
        "<S-h>",
        function()
          Snacks.picker.buffers({
            -- I always want my buffers picker to start in normal mode
            on_show = function()
              vim.cmd.stopinsert()
            end,
            finder = "buffers",
            format = "buffer",
            hidden = false,
            unloaded = true,
            current = true,
            sort_lastused = true,
            win = {
              input = {
                keys = {
                  ["d"] = "bufdelete",
                },
              },
              list = { keys = { ["d"] = "bufdelete" } },
            },
            -- In case you want to override the layout for this keymap
            -- layout = "ivy",
          })
        end,
        desc = "[P]Snacks picker buffers",
      },
      -- Keybindings from fzf-lua migration
      { "<leader>,", "<cmd>lua Snacks.picker.buffers({ sort_lastused = true })<cr>", desc = "Switch Buffer" },
      { "<leader>:", "<cmd>lua Snacks.picker.cmd_history()<cr>", desc = "Command History" },
      { "<leader>fb", "<cmd>lua Snacks.picker.buffers({ sort_lastused = true })<cr>", desc = "Buffers" },
      { "<leader>fB", "<cmd>lua Snacks.picker.buffers()<cr>", desc = "Buffers (all)" },
      {
        "<leader>fc",
        '<cmd>lua Snacks.picker.files({ cwd = vim.fn.stdpath("config") })<cr>',
        desc = "Find Config File",
      },
      { "<leader>ff", "<cmd>lua Snacks.picker.files()<cr>", desc = "Find Files (Root Dir)" },
      { "<leader>fF", "<cmd>lua Snacks.picker.files({ cwd = vim.uv.cwd() })<cr>", desc = "Find Files (cwd)" },
      { "<leader>fg", "<cmd>lua Snacks.picker.git_files()<cr>", desc = "Find Files (git-files)" },
      { "<leader>fr", "<cmd>lua Snacks.picker.recent()<cr>", desc = "Recent" },
      { "<leader>fR", "<cmd>lua Snacks.picker.recent({ cwd = vim.uv.cwd() })<cr>", desc = "Recent (cwd)" },
      { "<leader>gd", "<cmd>lua Snacks.picker.git_diff()<cr>", desc = "Git Diff (hunks)" },
      { "<leader>gs", "<cmd>lua Snacks.picker.git_status()<cr>", desc = "Status" },
      { "<leader>gS", "<cmd>lua Snacks.picker.git_stash()<cr>", desc = "Git Stash" },
      { '<leader>s"', "<cmd>lua Snacks.picker.registers()<cr>", desc = "Registers" },
      { "<leader>s/", "<cmd>lua Snacks.picker.search_history()<cr>", desc = "Search History" },
      { "<leader>sa", "<cmd>lua Snacks.picker.autocmds()<cr>", desc = "Auto Commands" },
      { "<leader>sb", "<cmd>lua Snacks.picker.lines()<cr>", desc = "Buffer Lines" },
      { "<leader>sc", "<cmd>lua Snacks.picker.cmd_history()<cr>", desc = "Command History" },
      { "<leader>sC", "<cmd>lua Snacks.picker.commands()<cr>", desc = "Commands" },
      { "<leader>sd", "<cmd>lua Snacks.picker.diagnostics()<cr>", desc = "Diagnostics" },
      { "<leader>sD", "<cmd>lua Snacks.picker.diagnostics({ bufnr = 0 })<cr>", desc = "Buffer Diagnostics" },
      { "<leader>sG", "<cmd>lua Snacks.picker.grep({ cwd = vim.uv.cwd() })<cr>", desc = "Grep (cwd)" },
      { "<leader>sh", "<cmd>lua Snacks.picker.help()<cr>", desc = "Help Pages" },
      { "<leader>sH", "<cmd>lua Snacks.picker.highlights()<cr>", desc = "Search Highlight Groups" },
      { "<leader>sj", "<cmd>lua Snacks.picker.jumps()<cr>", desc = "Jumplist" },
      { "<leader>sk", "<cmd>lua Snacks.picker.keymaps()<cr>", desc = "Key Maps" },
      { "<leader>sl", "<cmd>lua Snacks.picker.loclist()<cr>", desc = "Location List" },
      { "<leader>sM", "<cmd>lua Snacks.picker.man()<cr>", desc = "Man Pages" },
      { "<leader>sm", "<cmd>lua Snacks.picker.marks()<cr>", desc = "Jump to Mark" },
      { "<leader>sR", "<cmd>lua Snacks.picker.resume()<cr>", desc = "Resume" },
      { "<leader>sq", "<cmd>lua Snacks.picker.qflist()<cr>", desc = "Quickfix List" },
      { "<leader>sw", "<cmd>lua Snacks.picker.grep_cword()<cr>", desc = "Word (Root Dir)" },
      { "<leader>sW", "<cmd>lua Snacks.picker.grep_cword({ cwd = vim.uv.cwd() })<cr>", desc = "Word (cwd)" },
      { "<leader>sw", "<cmd>lua Snacks.picker.grep_visual()<cr>", mode = "x", desc = "Selection (Root Dir)" },
      {
        "<leader>sW",
        "<cmd>lua Snacks.picker.grep_visual({ cwd = vim.uv.cwd() })<cr>",
        mode = "x",
        desc = "Selection (cwd)",
      },
      { "<leader>uC", "<cmd>lua Snacks.picker.colorschemes()<cr>", desc = "Colorscheme with Preview" },
      {
        "<leader>ss",
        function()
          Snacks.picker.lsp_symbols({
            filter = function(item)
              return item.kind ~= "Comment" and item.kind ~= "String"
            end,
          })
        end,
        desc = "Goto Symbol",
      },
      {
        "<leader>sS",
        function()
          Snacks.picker.lsp_symbols_workspace({
            filter = function(item)
              return item.kind ~= "Comment" and item.kind ~= "String"
            end,
          })
        end,
        desc = "Goto Symbol (Workspace)",
      },
    },
    opts = {
      picker = {
        layout = {
          preset = "ivy",
          cycle = false,
        },
        layouts = {
          ivy = {
            layout = {
              box = "vertical",
              backdrop = false,
              row = -1,
              width = 0,
              height = 0.5,
              border = "top",
              title = " {title} {live} {flags}",
              title_pos = "left",
              { win = "input", height = 1, border = "bottom" },
              {
                box = "horizontal",
                { win = "list", border = "none" },
                { win = "preview", title = "{preview}", width = 0.5, border = "left" },
              },
            },
          },
          vertical = {
            layout = {
              backdrop = false,
              width = 0.8,
              min_width = 80,
              height = 0.8,
              min_height = 30,
              box = "vertical",
              border = "rounded",
              title = "{title} {live} {flags}",
              title_pos = "center",
              { win = "input", height = 1, border = "bottom" },
              { win = "list", border = "none" },
              { win = "preview", title = "{preview}", height = 0.4, border = "top" },
            },
          },
        },
        matcher = {
          frecency = true,
        },
        win = {
          input = {
            keys = {
              ["<Esc>"] = { "close", mode = { "n", "i" } },
              ["J"] = { "preview_scroll_down", mode = { "i", "n" } },
              ["K"] = { "preview_scroll_up", mode = { "i", "n" } },
              ["H"] = { "preview_scroll_left", mode = { "i", "n" } },
              ["L"] = { "preview_scroll_right", mode = { "i", "n" } },
            },
          },
        },
        formatters = {
          file = {
            filename_first = true,
            truncate = 80,
          },
        },
      },
      lazygit = {
        theme = {
          selectedLineBgColor = { bg = "CursorLine" },
        },
        win = {
          width = 0,
          height = 0,
        },
      },
      notifier = {
        enabled = true,
        top_down = true,
      },
    },
  },
}
