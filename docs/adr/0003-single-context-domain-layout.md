# 0003. Single-context domain layout

Date: 2026-10-01

## Status

Accepted

## Context

`AGENTS.md` states a single-context layout — one `CONTEXT.md` and one
`docs/adr/` at the repo root — but neither existed. `docs/agents/domain.md`
instructs agents to read them and to *proceed silently* if absent, so nothing
surfaced the gap; the claim was simply false.

This repo is one context. It deploys one package to one machine's `$HOME`,
with one boundary to a second repo (ADR-0002). A `CONTEXT-MAP.md` routing to
per-context files would add indirection for no gain.

## Decision

Adopt the single-context layout for real: `CONTEXT.md` at the root, ADRs in
`docs/adr/`. No `CONTEXT-MAP.md`.

ADRs are numbered sequentially from `0001` and never reused, including for
moved or withdrawn decisions — a retired ADR stays on disk so the number keeps
referring to one decision.

## Consequences

- `AGENTS.md`'s claim is now true rather than aspirational.
- Rejected entries are recorded rather than deleted, so "why is it like this"
  is answerable without archaeology through git history.
- `CONTEXT.md` carries the glossary. Per `docs/agents/domain.md`, output that
  names a domain concept should use the term defined there; if a needed term is
  absent, that is a real gap, not an invitation to coin a synonym.
- Renaming a term in `CONTEXT.md` is a breaking change for any agent that
  adopted the old one. Update it deliberately, not incidentally.