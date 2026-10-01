# Workflow and Architecture Overview

## 1. Purpose of **GNU stow**

`stow` is a lightweight package manager that creates **symbolic links** from a *source directory* (here `./home/`) to a *target directory* (usually `$HOME`).

* **Single source of truth** – all configuration files live in the repository; the symlinks in `~` simply point to them.
* **Atomic deployment** – `stow --no-folding -t ~ -d ~/mint-dotfiles home` creates every link in one step. `--no-folding` matters: without it a fresh machine (no `~/.config` yet) gets `~/.config` as a single directory symlink into the repo, so all app writes and runtime state land there. See ADR-0004.
* **Undo/rollback** – `stow -D -t ~ home` removes the symlinks cleanly. (`-R` is *restow*, not rollback: it re-applies the package, replacing existing links.)

Use it when:
* You want version‑controlled dotfiles.
* The set of files is stable and well‑structured.
* You need to share the same config across multiple machines.

Do *not* use `stow` for temporary or runtime files (caches, fonts, runtime state).

## 2. Repository Layout

```
/.            – Project root  (git repo, build artefacts, CI scripts, shared utils)
/home/        – Stowe source (containing the real files to be symlinked)
  .bashrc
  .config/
  .local/          # Only small, stable files – not linked via stow
  .ripgreprc

/.gitignore   – Determines what is ignored over the repo
/install.sh    – Thin wrapper that runs `stow -t $HOME -d ./home`.
/sync-from-home.sh – Safety‑aware sync that pulls real files from $HOME back into the repo.

# Config Flow
#   User edits a file in ~   →   live file is a symlink to the repo → the repo file is updated instantly.
#   User adds a new config file   →   `dotsync` places it in the repo via rsync.
```

## 3. Core Tasks & Scripts

| Utility | Purpose | When to Run |
|---------|---------|-------------|
| `install.sh` | Create or restore the `$HOME` symlink tree from `./home/`, file by file (`--no-folding`). | First‑time setup or after a major change to the repo layout. |
| `sync-from-home.sh` | Pull **git-tracked** files under `home/` back from `$HOME`, using rsync `-aL`. Untracked files are never swept in. | After editing a file that lives in `$HOME`. |
| `dotsync` alias | Convenience wrapper: `cd ~/mint-dotfiles && ./sync-from-home.sh && git diff`. | After you modify a stowed file and want to review changes before committing. |
| `home/.config/nvim/lua/config/autocmds.lua` | `BufWritePost` on `*/mint-dotfiles/home/**` → "run :!dotsync". | During development – ensures you remember to `dotsync`. |

## 4. Typical Workflow

1. **Edit** a config file in your home directory (`$HOME`). Because the file is a symlink to `~/mint-dotfiles/home/<path>`, the change is instantly reflected in the repo.
2. **Sync** any *non‑stowed* changes back into the repo:
   ```
   dotsync   # expands to the sync script + a quick diff
   ```
3. **Review** and stage selective changes:
   ```bash
   git diff                    # see what changed
   git add -p                 # pick patches to commit
   git commit -m "msg"
   git push
   ```
4. **Keep the symlink tree up‑to‑date** if you have added new files under `home/` (e.g. from a `stow --adopt` operation):
   ```bash
   stow --no-folding -R -t ~ -d "~/mint-dotfiles" home
   ```
5. **Re‑run the helper scripts** yourself after editing them. Nothing sources `install.sh` or `sync-from-home.sh`, so a saved change to either takes effect on the *next* invocation, not automatically.

## 5. When to Use Scripts vs Stow

* **Use `stow`** when you want to:
   * Create or restore the symlink layout.
   * Keep the repo layout declarative.
   * Re‑instantiate the target (e.g. after a fresh clone).

* Use **scripts** when you need behaviour that `stow` cannot provide, e.g.:
   * Synchronising files that are *not* under `home/`.
   * Running custom commands before/after symlinks are created (linting, formatting, CI steps).
   * Managing non‑config assets (fonts, database files, cache directories) that must never be version‑controlled.

## 6. Extending the Setup

* **Custom modules** – add a new directory under `home/` and it deploys with the rest. It will not appear in `$HOME` until a `stow -R` run; `sync-from-home.sh` reports tracked‑but‑absent paths as "repo‑only".
* **Hooks** – place a `.git/hooks/pre-commit` script to enforce commit conventions.
* **Documentation** – keep reading `AGENTS.md`, `CONTEXT.md`, the `README.md`, and `docs/adr/` for decisions that constrain the setup.

---

*Feel free to modify this file as the workload evolves.*