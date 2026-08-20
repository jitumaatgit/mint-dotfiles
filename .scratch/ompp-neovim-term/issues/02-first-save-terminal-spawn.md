# 02 — Neovim spawns a terminal split running `omp` on first save

**What to build:** When a notes file created by `ompp --nvim` is saved for the first time, the front-matter prompt is extracted, a horizontal terminal split (~40% height) opens in the same Neovim instance, and `omp` runs with the extracted prompt piped via stdin. The terminal-buffer pair stays open.

**Blocked by:** 01 — ompp opens notes in Neovim (need the flow to reach the buffer)

**Status:** ready-for-agent

- [ ] Lua module `custom/omp-prompt.lua` defines autocmd handler for BufWritePost
- [ ] First-time save only is detected (via `b.omp_spawned` buffer-local flag)
- [ ] Prompt is extracted from front-matter `---` block
- [ ] Horizontal terminal split opens at ~40% height
- [ ] `omp` runs with prompt piped via stdin
- [ ] Both buffer and terminal remain visible after save