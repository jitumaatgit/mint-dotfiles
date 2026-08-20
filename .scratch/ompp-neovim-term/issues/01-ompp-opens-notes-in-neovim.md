# 01 — ompp opens notes in Neovim

**What to build:** Running `ompp` with no arguments creates a timestamped markdown file in `~/notes/90-archive/prompts/` and opens it in Neovim. Add an opt-in flag (e.g. `ompp --nvim`) that selects the new inline-terminal flow instead of the current behavior (which runs `omp` after the editor closes).

**Blocked by:** None — can start immediately

**Status:** done

- [x] `ompp` (no args) creates `~/notes/90-archive/prompts/YYYYMMDD-HHMMSS.md`
- [x] File is opened in Neovim (`$EDITOR`)
- [x] `ompp --nvim` flag exists and suppresses the old "run omp after save" path
- [x] `ompp "some prompt"` still runs `omp "$*"` directly (unchanged)