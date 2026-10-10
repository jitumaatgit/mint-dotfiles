-- Configure SQLite library path for sqlite.lua (used by yanky's sqlite storage).
-- Candidate paths are probed in lua/_sqlite_path.lua; first readable wins.
require("_sqlite_path")

-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
require("config.markdown-folding")
require("snippets")

-- Auto-move completed tasks to Completed section
require("custom.task-auto-complete").setup()

-- Filter tasks by file-level tags (requires obsidian.nvim)
require("custom.obsidian-task-filter").setup({
  picker = "telescope", -- Uses telescope for better UI
  show_completed = false,
  preview_context = 3,
})

-- Patch trouble.nvim's section.refresh so the throttle uv_check handler
-- never gets pinned at ~78% CPU via a stuck `section.fetching = true`.
-- See notes/docs/20-resources/neovim/trouble-nvim-fetch-leak-2026-07-04.md
-- (notes repo) for the full root-cause writeup.
require("custom.trouble-fetch-fix").setup()

-- Spawn omp terminal on first save of prompt notes
require("custom.omp-prompt").setup()
-- Open random note from ~/notes
require("custom.random-note")
-- Seed new vault notes with their creation-day daily note
require("custom.daily-related-link").setup()
-- Go to today's daily note (`<leader>nD`, or the system-wide nvim-daily-note)
-- and catch tasks and log entries into it on the way in (`<leader>nA`).
require("custom.daily-note").setup()
-- Keep today's "## Notes made today" section current whenever a note is written
-- (`:NotesMadeToday` rebuilds it by hand for any date)
require("custom.notes-made-today").setup()
-- Capture a tangent into today's `## Tangent Parking Lot` without leaving the
-- note you are in (`<leader>nT`, or the system-wide nvim-tangent-capture).
require("custom.tangent-capture").setup()
