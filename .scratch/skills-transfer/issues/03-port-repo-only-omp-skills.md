# 03 — Port repo-only omp skills (28 from dotfiles)

**What to build:** Copy 28 skill directories from `dotfiles:.agents/skills/` to `~/.agents/skills/`; verify `omp skill list` (or `ls ~/.agents/skills`) includes all 28.

Skills: ask-matt, code-review, code-review-and-quality, code-simplification, codebase-design, design-an-interface, diagnose, domain-modeling, find-skills, git-guardrails-claude-code, implement, improve-codebase-architecture, migrate-to-shoehorn, request-refactor-plan, resolving-merge-conflicts, setup-matt-pocock-skills, setup-pre-commit, setup-ts-deep-modules, tdd, to-spec, to-tickets, triage, ubiquitous-language, wayfinder, write-a-skill, writing-great-skills, zoom-out, caveman, create-readme, cross-port, edit-article, impeccable, kotlin-coroutines-flows, kotlin-patterns, kotlin-testing, obsidian-vault, plannotator-compound, qa, repo-cleanup, request-refactor-plan, responsive-bashrc, shift-automator, socratic-review, tasker-automation, ubiquitous-language, write-a-skill, writing-great-skills, zoom-out.

(Note: caveman, create-readme, etc. appear in both lists — deduplicate; final set is ~28 unique skills not in upstream.)

**Blocked by:** 01 — only gates the `handoff` skill file within this batch; other 27 can proceed independently.

**Status:** ready-for-agent

- [ ] All 28 unique skill directories copied to `~/.agents/skills/`
- [ ] `ls ~/.agents/skills/` shows all 28 skill names
- [ ] No file conflicts with existing local skills (33 overlap already installed)
- [ ] `handoff` skill handled per 01 decision