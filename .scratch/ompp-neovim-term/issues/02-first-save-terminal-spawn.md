# 02 — Neovim spawns a terminal split running `omp` on first save

**What to build:** When a notes file created by `ompp --nvim` is saved for the first time, the front-matter prompt is extracted, a horizontal terminal split (~40% height) opens in the same Neovim instance, and `omp` runs with the extracted prompt as an argv argument. The terminal-buffer pair stays open. On neovim exit, the omp process must be killed to prevent shell leakage.

**Blocked by:** 01 — ompp opens notes in Neovim (need the flow to reach the buffer)

**Status:** in-progress

- [ ] Lua module `custom/omp-prompt.lua` defines autocmd handler for BufWritePost
- [ ] First-time save only is detected (via `b.omp_spawned` buffer-local flag)
- [ ] Prompt is extracted from front-matter `---` block
- [ ] Horizontal terminal split opens at ~40% height
- [ ] `omp` runs with prompt passed as argv (not stdin)
- [ ] Both buffer and terminal remain visible after save
- [ ] On neovim exit, omp process is killed (no shell leakage)
