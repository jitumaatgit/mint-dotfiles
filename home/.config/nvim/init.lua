-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
require("config.markdown-folding")
require("snippets")

-- Auto-move completed tasks to Completed section
require("custom.task-auto-complete").setup()

-- Filter tasks by file-level tags (requires obsidian.nvim)
require("custom.obsidian-task-filter").setup({
  picker = "telescope",
  show_completed = false,
  preview_context = 3,
})

require("custom.trouble-fetch-fix").setup()

-- Spawn omp terminal on first save of prompt notes
require("custom.omp-prompt").setup()
