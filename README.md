# mint-dotfiles

Dotfiles for the Linux Mint machine. Companion to [`nixarch-dotfiles`](https://github.com/jitumaatgit/nixarch-dotfiles) (Arch + Nix + Home Manager on the Dell Latitude 7450).

## Overview

This repository holds dotfiles for my Linux Mint machine. All config files that live in directories under `$HOME` such as `~/.config`, `~/.vimrc`, `~/.bashrc`, etc. are managed from this repo.

The repository uses **GNU stow**: it creates symlinks in the home directory that point to the files in this repo.

### Development

#### Installation

Run `./install.sh` to deploy all dotfiles using GNU Stow:

```bash
./install.sh
```

The script will:
- Check for Stow and guide installation if missing
- Symlink the `home/` package to `$HOME`

#### Syncing from live system

Run `./sync-from-home.sh` to copy any live config changes back into the repo. Only files already tracked in `home/` are synced.

```bash
./sync-from-home.sh
git add -p && git commit -m "Sync configs"
```

### Stow workflow

- All dotfiles are in `home/` with the same structure as `$HOME`
- Use `stow <package> -t $HOME` to deploy, `-D` to remove
- The `home` package contains all tracked files

### Example commands

```bash
# Deploy all dotfiles
stow -t $HOME home

# Remove a specific package
stow -D nvim -t $HOME

# Deploy a single package
stow -t $HOME .config

# Remove all dotfiles (dry-run)
stow -D -t $HOME --dry-run home
```

## Structure

- `home/`: dotfiles root (mirrors `$HOME`), managed by stow
- `docs/`: documentation
- `notes/`: markdown notes
- `install.sh`: deployment script
- `sync-from-home.sh`: sync script for live changes