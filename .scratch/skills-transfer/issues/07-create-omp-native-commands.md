# 07 — Create omp-native slash commands (optional)

**What to build:** Create `~/.omp/agent/commands/*.md` for any commands you want to shadow opencode's (e.g., `commit`, `learn`, `rmslop`, `plannotator-annotate`, `plannotator-last`, `plannotator-review`). omp discovers these at user level and they shadow opencode provider on name collisions.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

- [ ] Desired command set chosen (subset of 6 opencode commands + docs mode)
- [ ] `.md` files created in `~/.omp/agent/commands/`
- [ ] `omp` command discovery shows new commands (or `ls ~/.omp/agent/commands/`)