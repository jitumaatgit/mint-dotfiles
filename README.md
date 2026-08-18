# mint-dotfiles

Dotfiles for the Linux Mint machine. Companion to [`nixarch-dotfiles`](https://github.com/jitumaatgit/nixarch-dotfiles) (Arch + Nix + Home Manager on the Dell Latitude 7450).

## Overview
This repository holds dotfiles for my Linux Mint machine.  All config files that live in directories under `$HOME` such as `~/.config`, `~/.vimrc`, `~/.bashrc`, etc. are managed from this repo.

The repository is intended to be used with **GNU stow**: it creates a symlink in the home directory that points to the file in the repo.  Run `stow -t $HOME .` from the repo root to deploy.

If you want to copy an existing config file into the repo use `stow --add <file> -t ~`.  Updates to the config files are managed by editing the file in this repository, then rerunning `stow` after committing.

The structure of the repo is intentionally flat ― every dotfile lives in a sub‑directory named after the destination directory (e.g. `nvim/` for `~/.config/nvim`).
* Any directory that is not tracked will be ignored by stow.

---

Detailed usage:

```bash
# pull latest changes
git pull
# install all symlinks
stow -t $HOME .
# remove a particular directory
stow -D nvim -t $HOME
```