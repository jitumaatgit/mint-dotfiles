# Restored from linux-dotfiles home/zsh.nix (materialized, no home-manager)
# https://ohmyz.sh/
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""
plugins=(git z sudo colored-man-pages extract command-not-found)
source $ZSH/oh-my-zsh.sh

HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_IGNORE_DUPS HIST_IGNORE_SPACE EXTENDED_HISTORY SHARE_HISTORY
setopt ignore_eof # so C-d doesnt close window on an empty prompt

autoload -Uz compinit && compinit
eval "$(omp completions zsh 2>/dev/null)"
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

alias lg='lazygit'
alias i='z -i'
alias zi='z -i'
alias vim='nvim'
alias oc='opencode'
alias preview='bat --style=plain --paging=always'
alias wm='workmux'
alias dotsync='cd ~/mint-dotfiles && ./sync-from-home.sh && git diff'

if [[ -o interactive ]]; then
  alias ls='eza --icons --group-directories-first -a'
  alias cat='bat --paging=never'
  alias grep='rg --color=auto'
fi

export FZF_DEFAULT_OPTS="--height=40% --layout=reverse --border --info=inline"
export FZF_DEFAULT_COMMAND="fd --type f --strip-cwd-prefix --no-ignore --hidden"
export FZF_CTRL_T_COMMAND="fd --type f --strip-cwd-prefix --no-ignore --hidden"
export FZF_ALT_C_COMMAND="fd --type d --strip-cwd-prefix --hidden"
# apt fzf 0.44 lacks `fzf --zsh`; source the shipped example files instead.
if [[ -o interactive ]] && [[ -t 0 ]]; then
  source /usr/share/doc/fzf/examples/key-bindings.zsh
  source /usr/share/doc/fzf/examples/completion.zsh
fi

setopt auto_cd correct hist_reduce_blanks

set_win_title() { echo -ne "\033]0;$(basename "$PWD")\007" }
starship_precmd_user_func="set_win_title"

snap() {
  local ts=$(date +%Y%m%d-%H%M%S)
  sudo btrfs subvolume snapshot -r / /.snapshots/snap-"$ts"
}

occ() {
  if [ $# -gt 0 ]; then
    opencode run "$@"
    return
  fi
  opencode run --command commit
}

omc() {
  yes | omp commit "$@"
}

ocp() {
  if [ $# -gt 0 ]; then
    opencode --prompt "$*"
    return
  fi
  mkdir -p ~/notes/90-archive/prompts
  local f="$HOME/notes/90-archive/prompts/$(date +%Y%m%d-%H%M%S).md"
  ${EDITOR:-nvim} "$f"
  [ -s "$f" ] || return
  local p="$(command awk 'NR==1 && /^---$/{f=1; next} f && /^---$/{f=0; next} !f' "$f")"
  [ -n "$p" ] || return
  opencode --prompt "$p"
}

ompp() {
  local use_nvim=0
  if [ $# -gt 0 ] && [ "$1" = "--nvim" ]; then
    use_nvim=1
    shift
  fi
  if [ $# -gt 0 ]; then
    omp "$*"
    return
  fi
  mkdir -p ~/notes/90-archive/prompts
  local f="$HOME/notes/90-archive/prompts/$(date +%Y%m%d-%H%M%S).md"
  ${EDITOR:-nvim} "$f"
  if [ "$use_nvim" -eq 1 ]; then
    return
  fi
  [ -s "$f" ] || return
  local p="$(command awk 'NR==1 && /^---$/{f=1; next} f && /^---$/{f=0; next} !f' "$f")"
  [ -n "$p" ] || return
  omp "$p"
}

export EDITOR="nvim"
export VISUAL="nvim"
export OPENCODE_DISABLE_AUTOUPDATE=true
export PLANNOTATOR_DATA_DIR="$HOME/notes/docs/plannotator"
export MANPAGER="sh -c 'col -bx | bat -l man -p'"
export MANROFFOPT="-c"
export NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt
export RIPGREP_CONFIG_PATH="$HOME/.ripgreprc"
export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$HOME/.bun/bin:$PATH"

for f in ~/notes/*.env(N); do [ -f "$f" ] && . "$f"; done
unset f

eval "$(starship init zsh)"
eval "$(zoxide init zsh)"
eval "$(workmux completions zsh)"
# Default browser for CLI tools (python webbrowser, xdg fallbacks, mail/tui)
# zen-browser launches the system Flatpak.
export BROWSER="zen-browser"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
