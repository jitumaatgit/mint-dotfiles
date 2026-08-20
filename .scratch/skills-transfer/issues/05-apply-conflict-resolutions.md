# 05 — Apply conflict resolutions (16 skills)

**What to build:** For the 16 non-handoff skills with real content differences (grilling, wayfinder, wizard, ask-matt, code-review, diagnosing-bugs, prototype, triage, setup-matt-pocock-skills, tdd, codebase-design, domain-modeling, grill-me, grill-with-docs, improve-codebase-architecture, loop-me): confirm local (upstream) versions are kept; no file ops needed. Verify no stale repo copies shadow local installs.

**Blocked by:** 01 — handoff decision informs whether handoff is part of this verification.

**Status:** ready-for-agent

- [ ] For each of 16 skills: local SKILL.md matches upstream (fresh install), not repo copy
- [ ] No repo-copy directories accidentally placed in `~/.agents/skills/` shadowing local
- [ ] handoff handled per 01 decision