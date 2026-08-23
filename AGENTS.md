# mint-dotfiles

## Agent skills

### Issue tracker

Issues and specs are tracked in the repo's GitHub Issues (uses the `gh` CLI). See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical triage roles use their default label names (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context layout: one `CONTEXT.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.
## Learnings

### Neovim config integration
- **Headless nvim file I/O quirk**: When running `nvim --headless` with a file argument, `io.open()` writes in Lua commands don't persist to disk the same way as interactive mode. Config verification passes (`lazy.sync()` succeeds, modules load), but file operations appear to fail. Verify interactively instead.

- **checkmate.nvim + render-markdown conflict**: Both plugins style checkboxes. Disable render-markdown checkbox rendering (`checkbox.enabled = false`) and let checkmate own styling (Unicode: ☐, ✔, ⊝).

- **Keymap conflict resolution**: checkmate uses `<leader>t` prefix. Remap conflicting snacks keymaps (`<leader>tt` → `<leader>tT`, `<leader>tc` → `<leader>tC`) instead of changing checkmate's defaults.

- **obsidian.nvim toggle checkbox**: Disable `<leader>nc` keymap in obsidian config when using checkmate for todo management.

- **Metadata via snacks picker**: checkmate's `metadata.choices` function + `select_on_insert = true` + `jump_to_on_insert = "value"` opens a snacks.nvim picker popup for tag values (e.g., energy: low/medium/high).

- **Archive heading separation**: checkmate archives to `## Archived` while task-auto-complete uses `## Completed` — both coexist without conflict.
