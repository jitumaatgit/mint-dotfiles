# Sourced by every zsh — login, interactive, and non-interactive (`zsh -c`,
# scripts) — which .zshrc is not. `zsh -f` skips it, and bash has no equivalent
# short of exporting BASH_ENV, so a bash script that runs `omp` from $HOME still
# lands in /tmp; nothing in the dotfiles or crontab does that today.
#
# Why the guard: omp silently chdirs to the first existing of ~/tmp, /tmp,
# /var/tmp when it starts in exactly $HOME without --allow-home or --cwd
# (packages/coding-agent/src/cli/startup-cwd.ts), so the session is archived
# with cwd=/tmp and every relative path and tool resolves against the wrong root.
# Subdirectories are untouched.
#
# A function rather than a PATH shim: ~/.local/bin/omp is Tern's managed symlink
# into ~/.local/share/tern/omp/versions/, so writing a script there would destroy
# the binary, and PATH order puts Tern's bin dir first in any case.
# Other spawners carry the flag themselves: ~/.config/nvim/lua/custom/
# omp-prompt.lua and ~/.config/tern/settings.json (agents.custom[].args).
omp() {
  if [[ $PWD == $HOME ]]; then
    command omp --allow-home "$@"
  else
    command omp "$@"
  fi
}
