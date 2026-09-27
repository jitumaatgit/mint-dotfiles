# Restored from linux-dotfiles home/zsh.nix (materialized, no home-manager)
# https://ohmyz.sh/
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""
plugins=(
  fast-syntax-highlighting
  zsh-autosuggestions
  git
  sudo
  zoxide
  colored-man-pages
  extract
  command-not-found
  vi-mode
)
# Removed but i want to add back zsh-autopair, and idk if vim-mode or vi-mode is better
#  # zsh-autopair
   # zsh-vim-mode

source $ZSH/oh-my-zsh.sh

# text object selection for quoted strings in command prompt
autoload -U select-quoted
zle -N select-quoted
for m in visual viopp; do
    for c in {a,i}{\',\",\`}; do
        bindkey -M $m $c select-quoted
    done
done
VI_MODE_RESET_PROMPT_ON_MODE_CHANGE=false
VI_MODE_SET_CURSOR=true

HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000
setopt append_history           # append the history
setopt share_history            # Share history between sessions
                                # with this option, you should not enable
                                # inc_append_history

#setopt extended_history         # include statistics of when/how long/etc
                                # command has run

#setopt hist_ignore_dups         # do not store dupes executed after eachother

# When HISTSIZE is smaller than SAVEHIST hist_expire_dups_first acts
# as hist_ignore_all_dups, so let's just set the correct options when that
# happens

#setopt hist_expire_dups_first   # removes copies when the histfile fills up
setopt hist_ignore_all_dups     # removes copies of the same line

setopt hist_save_no_dups        # don't save dupes from the same session
setopt hist_find_no_dups        # if we find dupes in the history, don't show
                                # them in editor commands)
setopt hist_reduce_blanks       # remove blank lines from the command which
                                # mean nothing to the shell

# Disable this on boxes that are affected by bug
# https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=924736
is-at-least 5.5   &&  unsetopt hist_reduce_blanks
# bugfix is incoming, lets see what it does
is-at-least 5.7.2 &&  setopt hist_reduce_blanks

setopt hist_ignore_space   # lines starting with space don't go into the
                           # history
setopt no_hist_beep        # silence..!
setopt hist_verify
setopt hist_no_store       # don't store history/fc commands
#setopt hist_no_functions   # don't show history of functions

setopt bg_nice             # nice bg commands
setopt notify              # notify when a command returns exit code

setopt no_beep             # silence..!

unsetopt auto_cd           # disable $ ./bin as cd ./bin
setopt extendedglob        # ls ^bla.* will not show ^bla.txt for example

setopt correct             # correct incorrent cmd's
setopt correctall          # correct everything, use
                           # `nocorrect mv foo bar` to negate this feature
                           # for a command

setopt hash_list_all       # fill the lookup table for tab completions

unsetopt promptcr          # prevent the prompt overwriting output when
                           # there is no newline
                           #
unsetopt shwordsplit

unsetopt nomatch           #
setopt prompt_subst        # Enable prompt substition

setopt glob_subst          # global substitution

setopt longlistjobs
setopt completeinword

# Directories
setopt auto_pushd          # cd foo == pushd foo
setopt pushd_ignore_dups   # no duplicates in the list
setopt pushdminus
setopt auto_name_dirs      # foo=/path/to/foo is the same as
                           # hash -d foo=/path/to/foo

# Misc
setopt interactivecomments # $ # foo doesn't become an error when hitting
                           # enter
setopt ignore_eof # so C-d doesnt close window on an empty prompt

eval "$(omp completions zsh 2>/dev/null)"
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

alias batstat='upower -i $(upower -e | grep BAT) | grep -B 1 percentage'
alias lg='lazygit'
alias i='z -i'
alias zi='z -i'
alias vim='nvim'
alias oc='opencode'
alias preview='bat --style=plain --paging=always'
alias wm='workmux'
alias dotsync='cd ~/mint-dotfiles && ./sync-from-home.sh && git diff'
alias rg='rg --hidden -S --color=always'
if [[ -o interactive ]]; then
  alias ls='eza --color=always --icons --group-directories-first -a'
  alias cat='bat --paging=never'
fi

# apt fzf 0.44 lacks `fzf --zsh`; source the shipped example files instead.
if [[ -o interactive ]] && [[ -t 0 ]]; then
  source /usr/share/doc/fzf/examples/key-bindings.zsh
  source /usr/share/doc/fzf/examples/completion.zsh
fi
export FZF_DEFAULT_OPTS="--height=40% --layout=reverse --border --info=inline"
export FZF_DEFAULT_COMMAND="fd --type f --strip-cwd-prefix --no-ignore --hidden"
export FZF_CTRL_T_COMMAND="fd --type f --strip-cwd-prefix --no-ignore --hidden"
export FZF_ALT_C_COMMAND="fd --type d --strip-cwd-prefix --hidden"

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
eval "$(pay-respects zsh)"
# Default browser for CLI tools (python webbrowser, xdg fallbacks, mail/tui)
# zen-browser launches the system Flatpak.
export BROWSER="zen-browser"
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"

[ -f ~/.free-coding-models.env ] && . ~/.free-coding-models.env  # free-coding-models-env

# tldr zsh completion
fpath=(/usr/local/lib/node_modules/tldr/bin/completion/zsh $fpath)

# You might need to force rebuild zcompdump:
# rm -f ~/.zcompdump; compinit

# If you're using oh-my-zsh, you can force reload of completions:
# autoload -U compinit && compinit

# Cache compinit to speed up startup. Must run AFTER oh-my-zsh.sh and after
# the tldr fpath entry above, or those completions are missed.
if (( ! $+functions[compinit] )); then
  autoload -Uz compinit
  if [ -n "$(find ~/.zcompdump -mtime -1 2>/dev/null)" ]; then
    compinit -C
  else
    compinit
  fi
fi
