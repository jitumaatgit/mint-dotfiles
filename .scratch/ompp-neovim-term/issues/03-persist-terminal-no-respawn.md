# 03 — Keep the terminal open; subsequent saves don't re-spawn

**What to build:** After the first save spawns the terminal and runs `omp`, subsequent saves to the buffer write the note file without spawning a new terminal. The buffer and terminal both persist in the Neovim workspace. On neovim exit, the omp process must be killed to prevent shell leakage.

**Blocked by:** 02 — Neovim spawns terminal on first save (must exist before we can guard against re-spawn)

**Status:** in-progress

- [ ] Buffer-local flag `b.omp_spawned` is set after first terminal spawn
- [ ] Subsequent saves skip terminal creation (check flag before opening)
- [ ] Notes content is still written on every save
- [ ] Terminal split remains visible and interactive for subsequent interaction
- [ ] On neovim exit, omp process is killed (no shell leakage)
