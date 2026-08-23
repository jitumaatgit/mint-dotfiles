return {
  "bngarren/checkmate.nvim",
  ft = "markdown",
  opts = {
    -- Activate on all markdown files
    files = { "*.md" },

    -- Checkmate owns styling (Unicode markers: ☐, ✔, ⊝, etc.)
    style = true,

    -- Custom todo states - keeping defaults but can extend later
    todo_states = {
      unchecked = { marker = "☐", hl = "CheckmateUnchecked" },
      checked = { marker = "✔", hl = "CheckmateChecked" },
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
        select_on_insert = true,
      },

      -- Area tag (PARA method: projects, areas, resources, archives)
      area = {
        style = { fg = "#cba6f7" },
        choices = function()
          return { "projects", "areas", "resources", "archives" }
        end,
        key = "<leader>ta",
        jump_to_on_insert = "value",
        select_on_insert = true,
      },

      -- Time estimate tag
      time_estimate = {
        style = { fg = "#fab387" },
        choices = function()
          return { "5m", "15m", "30m", "1h", "2h", "4h", "8h+" }
        end,
        key = "<leader>tm",
        jump_to_on_insert = "value",
        select_on_insert = true,
      },

      -- Built-in priority with choices
      priority = {
        style = function(context)
          local value = context.value:lower()
          if value == "high" then
            return { fg = "#f38ba8", bold = true }
          elseif value == "medium" then
            return { fg = "#f9e2af" }
          elseif value == "low" then
            return { fg = "#a6e3a1" }
          end
        end,
        choices = function()
          return { "high", "medium", "low" }
        end,
        key = "<leader>tP",
        jump_to_on_insert = "value",
        select_on_insert = true,
      },

      -- Built-in due date
      due = {
        style = { fg = "#f38ba8" },
        key = "<leader>td",
        jump_to_on_insert = "value",
      },

      -- Built-in started timestamp
      started = {
        style = { fg = "#89b4fa" },
        key = "<leader>ts",
        jump_to_on_insert = "value",
      },

      -- Built-in done timestamp
      done = {
        style = { fg = "#a6e3a1" },
        key = "<leader>tD",
        jump_to_on_insert = "value",
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
      heading = "## Archived",
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

    -- Core todo operations
    map("n", "<leader>tn", api.create, { desc = "Create todo" })
    map("x", "<leader>tn", api.create, { desc = "Create todos from selection" })
    map("n", "<leader>tt", api.toggle, { desc = "Toggle todo" })
    map("x", "<leader>tt", api.toggle, { desc = "Toggle selected todos" })
    map("n", "<leader>tc", api.check, { desc = "Check todo" })
    map("x", "<leader>tc", api.check, { desc = "Check selected todos" })
    map("n", "<leader>tu", api.uncheck, { desc = "Uncheck todo" })
    map("x", "<leader>tu", api.uncheck, { desc = "Uncheck selected todos" })
    map("n", "<leader>t=", api.cycle_next, { desc = "Cycle todo state forward" })
    map("n", "<leader>t-", api.cycle_prev, { desc = "Cycle todo state backward" })
    map("n", "<leader>tg", api.archive, { desc = "Archive completed todos" })

    -- Metadata keymaps (defined in metadata config above, but also accessible via commands)
    map("n", "<leader>te", function() api.add_metadata("energy") end, { desc = "Add energy metadata" })
    map("x", "<leader>te", function() api.add_metadata("energy") end, { desc = "Add energy metadata to selection" })
    map("n", "<leader>tx", function() api.add_metadata("context") end, { desc = "Add context metadata" })
    map("x", "<leader>tx", function() api.add_metadata("context") end, { desc = "Add context metadata to selection" })
    map("n", "<leader>tp", function() api.add_metadata("project") end, { desc = "Add project metadata" })
    map("x", "<leader>tp", function() api.add_metadata("project") end, { desc = "Add project metadata to selection" })
    map("n", "<leader>ta", function() api.add_metadata("area") end, { desc = "Add area metadata" })
    map("x", "<leader>ta", function() api.add_metadata("area") end, { desc = "Add area metadata to selection" })
    map("n", "<leader>tm", function() api.add_metadata("time_estimate") end, { desc = "Add time estimate metadata" })
    map("x", "<leader>tm", function() api.add_metadata("time_estimate") end, { desc = "Add time estimate to selection" })
    map("n", "<leader>tP", function() api.add_metadata("priority") end, { desc = "Add priority metadata" })
    map("x", "<leader>tP", function() api.add_metadata("priority") end, { desc = "Add priority to selection" })
    map("n", "<leader>td", function() api.add_metadata("due") end, { desc = "Add due date metadata" })
    map("x", "<leader>td", function() api.add_metadata("due") end, { desc = "Add due date to selection" })
    map("n", "<leader>ts", function() api.add_metadata("started") end, { desc = "Add started timestamp" })
    map("x", "<leader>ts", function() api.add_metadata("started") end, { desc = "Add started to selection" })
    map("n", "<leader>tD", function() api.add_metadata("done") end, { desc = "Add done timestamp" })
    map("x", "<leader>tD", function() api.add_metadata("done") end, { desc = "Add done to selection" })

    -- Metadata navigation
    map("n", "<leader>tj", api.jump_next_metadata, { desc = "Jump to next metadata" })
    map("n", "<leader>tk", api.jump_prev_metadata, { desc = "Jump to previous metadata" })

    -- Lint current buffer
    map("n", "<leader>tl", api.lint, { desc = "Lint checkmate buffer" })

    -- Select/search todos (using snacks picker backend)
    map("n", "<leader>tf", function()
      require("snacks").picker.checkmate()
    end, { desc = "Find todos (snacks picker)" })
  end,
}