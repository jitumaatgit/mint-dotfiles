# Managing Dotfiles with GNU Stow on Linux Mint

## 1. Repository layout

```
./home/                # real files as letters, symlink‑targeted by stow
├─ .bashrc
├─ .gitconfig
├─ .config/
│  ├─ nvim/
│  ├─ wezterm/
│  └─ ...
└─ ...
```

* Keep a single‑root repository (e.g. `~/mint-dotfiles`).
* Slice the configuration into *packages* – groups of related files.
  * `home/` for top‑level dotfiles.
  * `config/` for `~/.config` sub‑directories.
  * Optional site‑specific or machine‑specific packages (e.g. `mint‑desktop`).
* Place a `README.md` in the root describing the package tree.

## 2. Installing Stow

```bash
sudo apt update
sudo apt install stow        # already in Mint's repos
```

## 3. Basic workflow

```bash
# One‑time: move existing core configs into repo
cp ~/.bashrc ~/mint-dotfiles/home/
cp -r ~/.config/nvim ~/mint-dotfiles/home/.config/

# Deploy
cd ~/mint-dotfiles
./install.sh   # typically `stow -v -R -t ~ home config`

# Sync changes back
./sync-from-home.sh

git add -p && git commit -m "Sync configs"
```

* `install.sh` should use `-R` (recursive) and `--ignore-dot-files` to avoid stow creating dots on top‑level files.
* `sync-from-home.sh` copies the *live* files into the repo and stages them.

## 4. Ignore patterns

* In the repo: `.gitignore` should exclude anything that changes per‑machine.
* In Stow: use `--ignore=foo` or add an `~/.gitignore`‑style file under `home/.stow-local-ignore`.
* Example:

```
# .stow-local-ignore in home/
.venv
secret.json
```

## 5. Conflicts & safety

* Stow refuses to overwrite files that already exist in the target.
* Always back up before the first run:

`cp -r ~ ~/.dotfiles-backup`

* When stowing on a fresh machine, it will complain if a real file exists. Remove it or rename, then run stow again.
* Use `--dotfiles` to treat `.foo` literally.

## 6. Machine‑specific extensions

### Pattern: `hostname‑package`

```
/home/hostname-mint/  # files only for this host
```

Workflow:

1. Create the package.
2. Add it to the install list with a `-m`, `-M`, or similar flag.
3. In `install.sh`, conditionally stow the machine‑specific directory:

```bash
if [[ "$HOSTNAME" == "mint" ]]; then
  stow -R -t ~ hostname-mint
fi
```

### `local.d/` fallback

Place `$HOME/.config/…/local.d/` for per‑user tweaks that should never be stowed.
Keep those files outside the repo and point your application at that directory.

## 7. Encryption & secrets

* Do **not** commit secrets to a public repo.
* Use `age` or `gpg` with git `clean`/`smudge` filters.
  * Store encrypted files under `home/secret.json.age`.
  * A small script runs `age-decrypt` before `stow`.
* Keep the private key out of the repo; use cache or prompt.

## 8. Automation scripts

### install.sh

```bash
#!/usr/bin/env bash
set -e

# Deploy core packages
stow -t ~ ...
```

* `-R` for recursive packages.
* `-d` to delete existing links before recreating.
* `-v` for verbose.

### sync-from-home.sh

```bash
#!/usr/bin/env bash
set -e

# Pull live changes into repo
rsync -av --prune-source $HOME/* ~/mint-dotfiles/home/
rsync -av --prune-source ~/.config/* ~/mint-dotfiles/home/.config/
```

* Exclude ignored local files via `--exclude`.

## 9. Git best practices

* Keep all config files in a single repo; no sub‑repos unless you intentionally isolate a set.
* Use a branching strategy: `main` for stable configs, `dev` for experimental changes.
* Commit changes only after verifying the symlinked files work.
* Add a `post‑merge` hook to run `stow -dR -t ~` automatically on pulls.

## 10. Testing & verification

* After a change, run `stow -t ~ -v -R` and verify links.
* Simple smoke test: open a program (e.g., `nvim`) and ensure it picks up the new config.
* For automated CI, run `stow -R -t /tmp/test …` and check that all target files exist and are readable.

## 11. Common pitfalls

| Pitfall | Fix |
|---------|-----|
| Creating a symlinked file that already exists naturally in the filesystem |  Back up or rename the existing file before stowing. |
| Forgetting to add `~` as the target directory | Use `-t ~` explicitly. |
| Stow treats `.` (dot) as a regular file | Use `--dotfiles`. |
| Mixing local `~/.config/foo` and `./home/.config/foo` | Adopt a consistent `home/.config/` structure and note the dot in `.config` if required. |
| Overwriting private secrets on a shared machine | Keep secrets separate, encrypt, or exclude with `.gitignore`. |

## 12. Resources

* [GNU Stow Manual](https://www.gnu.org/software/stow/manual/stow.html)
* [Awesome Dotfiles](https://github.com/junegunn/awesome-dotfiles)
* [Linux Junkies Guide to Stow](https://linuxjunkies.org/guides/manage-dotfiles-with-stow)
* [Age Encryption Git Filter Example](https://github.com/mic92/age-git-filter)
* [Linux Mint Documentation](https://help.ubuntu.com/lts/ubuntu-help/mint.html)