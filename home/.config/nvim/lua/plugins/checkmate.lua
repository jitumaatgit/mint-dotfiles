return {
  "bngarren/checkmate.nvim",
  ft = "markdown",
  opts = {
    -- Activate on all markdown files
    files = { "*.md" },

    -- Checkmate owns styling (Unicode markers: ☐, ✔, ⊝, etc.)
    style = {},

    -- Custom todo states - keeping defaults but can extend later
    todo_states = {
      unchecked = { marker = "☐", hl = "CheckmateUnchecked" },
      checked = { marker = "✔", hl = "CheckmateChecked" },
      cancelled = {
        marker = "✗",
        markdown = "-",
        type = "complete",
        order = 2,
      },
    },

    -- Metadata configuration with custom tags for obsidian workflow
    metadata = {
      -- Energy level with choice popup (low/medium/high)
      energy = {
        style = function(context)
          local value = context.value:lower()
          if value == "high" then
            return { fg = "#ff5555", bold = true }
          elseif value == "medium" then
            return { fg = "#ffb86c" }
          elseif value == "low" then
            return { fg = "#8be9fd" }
          end
        end,
        choices = function()
          return { "low", "medium", "high" }
        end,
        key = "<leader>te",
        jump_to_on_insert = "value",
        select_on_insert = true,
      },

      -- Context tag (e.g., @context(work), @context(personal))
      context = {
        style = { fg = "#a6e3a1" },
        choices = function()
          return { "work", "personal", "learning", "admin", "creative" }
        end,
        key = "<leader>tx",
        jump_to_on_insert = "value",
        select_on_insert = true,
      },

      -- Project tag
      project = {
        style = { fg = "#f9e2af" },
        key = "<leader>tp",
        jump_to_on_insert = "value",
      },

      -- Area tag
      area = {
        style = { fg = "#89b4fa" },
        key = "<leader>ta",
        jump_to_on_insert = "value",
      },

      -- Time estimate
      time_estimate = {
        style = { fg = "#fab387" },
        key = "<leader>tm",
        jump_to_on_insert = "value",
      },

      -- Priority
      priority = {
        style = function(context)
          local value = context.value:lower()
          if value == "high" then
            return { fg = "#ff5555", bold = true }
          elseif value == "medium" then
            return { fg = "#ffb86c" }
          elseif value == "low" then
            return { fg = "#8be9fd" }
          end
        end,
        choices = function()
          return { "high", "medium", "low" }
        end,
        key = "<leader>tP",
        jump_to_on_insert = "value",
        select_on_insert = true,
      },

      -- Due date
      due = {
        style = { fg = "#ff79c6" },
        key = "<leader>td",
        jump_to_on_insert = "value",
      },

      -- Started timestamp
      started = {
        style = { fg = "#8be9fd" },
        key = "<leader>ts",
        get_value = function()
          return os.date("%Y-%m-%d %H:%M")
        end,
      },

      -- Done timestamp
      done = {
        style = { fg = "#50fa7b" },
        key = "<leader>tD",
        get_value = function()
          return os.date("%Y-%m-%d %H:%M")
        end,
      },
    },

    -- Disable default keymaps - we'll set our own with <leader>t prefix
    keys = false,
    use_metadata_keymaps = false,

    -- Picker integration with snacks.nvim (already installed)
    picker = {
      backend = "snacks",
    },

    -- Smart toggle behavior
    smart_toggle = {
      enabled = true,
    },

    -- Archive completed todos
    archive = {
      enabled = true,
      heading = { text = "## Archived" },
    },

    -- Linting
    lint = {
      enabled = true,
    },
  },
  config = function(_, opts)
    require("checkmate").setup(opts)

    -- Custom keymaps with <leader>t prefix
    local map = vim.keymap.set
    local api = require("checkmate.api")
    local checkmate = require("checkmate")

    -- Core todo operations
    map("n", "<leader>tn", api.create_todo_normal, { desc = "Create todo" })
    map("n", "<leader>tt", checkmate.toggle, { desc = "Toggle todo" })
    map("x", "<leader>tt", checkmate.toggle, { desc = "Toggle selected todos" })
    map("n", "<leader>tc", checkmate.check, { desc = "Check todo" })
    map("x", "<leader>tc", checkmate.check, { desc = "Check selected todos" })
    map("n", "<leader>tu", checkmate.uncheck, { desc = "Uncheck todo" })
    map("x", "<leader>tu", checkmate.uncheck, { desc = "Uncheck selected todos" })
    map("n", "<leader>tg", api.archive_todos, { desc = "Archive completed todos" })

    -- Metadata keymaps (use main module's add_metadata which handles context)
    map("n", "<leader>te", function()
      checkmate.add_metadata("energy")
    end, { desc = "Add energy metadata" })
    map("x", "<leader>te", function()
      checkmate.add_metadata("energy")
    end, { desc = "Add energy metadata to selection" })
    map("n", "<leader>tx", function()
      checkmate.add_metadata("context")
    end, { desc = "Add context metadata" })
    map("x", "<leader>tx", function()
      checkmate.add_metadata("context")
    end, { desc = "Add context metadata to selection" })
    map("n", "<leader>tp", function()
      checkmate.add_metadata("project")
    end, { desc = "Add project metadata" })
    map("x", "<leader>tp", function()
      checkmate.add_metadata("project")
    end, { desc = "Add project metadata to selection" })
    map("n", "<leader>ta", function()
      checkmate.add_metadata("area")
    end, { desc = "Add area metadata" })
    map("x", "<leader>ta", function()
      checkmate.add_metadata("area")
    end, { desc = "Add area metadata to selection" })
    map("n", "<leader>tm", function()
      checkmate.add_metadata("time_estimate")
    end, { desc = "Add time estimate metadata" })
    map("x", "<leader>tm", function()
      checkmate.add_metadata("time_estimate")
    end, { desc = "Add time estimate to selection" })
    map("n", "<leader>tP", function()
      checkmate.add_metadata("priority")
    end, { desc = "Add priority metadata" })
    map("x", "<leader>tP", function()
      checkmate.add_metadata("priority")
    end, { desc = "Add priority to selection" })
    map("n", "<leader>td", function()
      checkmate.add_metadata("due")
    end, { desc = "Add due date metadata" })
    map("x", "<leader>td", function()
      checkmate.add_metadata("due")
    end, { desc = "Add due date to selection" })
    map("n", "<leader>ts", function()
      checkmate.add_metadata("started")
    end, { desc = "Add started timestamp" })
    map("x", "<leader>ts", function()
      checkmate.add_metadata("started")
    end, { desc = "Add started to selection" })
    map("n", "<leader>tD", function()
      checkmate.add_metadata("done")
    end, { desc = "Add done timestamp" })
    map("x", "<leader>tD", function()
      checkmate.add_metadata("done")
    end, { desc = "Add done to selection" })

    -- Metadata navigation
    map("n", "<leader>tj", checkmate.jump_next_metadata, { desc = "Jump to next metadata" })
    map("n", "<leader>tk", checkmate.jump_previous_metadata, { desc = "Jump to previous metadata" })

    -- Lint current buffer
    map("n", "<leader>tl", checkmate.lint, { desc = "Lint checkmate buffer" })

    -- Select/search todos (using snacks picker backend)
    map("n", "<leader>tf", function()
      require("snacks").picker.checkmate()
    end, { desc = "Find todos (snacks picker)" })
  end,
}
