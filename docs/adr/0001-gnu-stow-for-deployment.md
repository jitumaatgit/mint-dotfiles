# 0001. Deploy dotfiles with GNU stow

Date: 2026-08-27

## Status

Accepted

## Context

Config files for this machine need to be version-controlled while still
existing at their expected paths under `$HOME`. Something has to place them
there, and that mechanism has to survive a fresh clone on another machine
without a manual checklist.

Considered:

- **Hand-rolled symlink script.** Simple, but no record of intent: nothing
  knows which paths are meant to be linked versus deliberately absent.
- **chezmoi.** More capable, but adds a template language and a state file.
  Overkill for a single-user, single-machine dotfiles set.
- **yadm.** Would track all of `$HOME`, which collides head-on with
  `~/.home-git` (see ADR-0002).

## Decision

Use GNU stow with a single package, `home/`. `install.sh` runs
`stow -t "$HOME" -d "$REPO_ROOT" home`.

Deployment stays reversible: `stow -D -t ~ home` removes the links,
`stow -R` re-applies the package. Nothing is copied, only symlinked, so the
repo copy is always authoritative and there is no second version to drift.

## Consequences

- `home/` must mirror `$HOME` exactly. Restructuring paths means restructuring
  `$HOME`, which is the point — not a cost.
- `stow` will not overwrite a real file with a symlink. First adoption needs a
  manual move; stow then takes over.
- Deployment is a single command, so forgetting it is not a failure mode worth
  defending against.
- Any tooling that writes through a path under `$HOME` (editors writing
  configs, live tools persisting settings) writes *into this repo*. That is
  desirable for config, and a hazard for anything the tool regenerates —
  which is why runtime state is excluded by invariant 2 in `CONTEXT.md`.