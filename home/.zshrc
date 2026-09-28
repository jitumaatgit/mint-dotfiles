# Restored from linux-dotfiles home/zsh.nix (materialized, no home-manager)
# https://ohmyz.sh/
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""
plugins=(
# Only one syntax highlighter, and only one autosuggestions. Adding
# zsh-autosuggestions or a second highlighter as an omz plugin *and* sourcing
# the /usr/share copy below means the last one loaded silently wins.
# zsh-syntax-highlighting is sourced near the bottom of this file, where it
# must be, so that it wraps every widget created above it.
# The omz `git` plugin was removed: it defined ~190 aliases (gst/gco/gcam/...)
# none of which were used, and forked `git version` on every shell start for
# them. It also provided no prompt, since ZSH_THEME="" and starship owns that.
  sudo
  extract
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
setopt share_history             # share history between live sessions.
                                 # Do NOT also enable inc_append_history.

# oh-my-zsh's lib/history.zsh runs during the `source` above and turns on
# extended_history, hist_ignore_dups and hist_expire_dups_first. Commenting
# those out does nothing, so they are explicitly unset to keep the old intent.
# Everything in this block runs after that, so it wins.
unsetopt extended_history        # no timestamps bloating the history file
unsetopt hist_ignore_dups        # superseded by hist_ignore_all_dups below
unsetopt hist_expire_dups_first  # with HISTSIZE==SAVEHIST it degrades to
                                 # hist_ignore_all_dups anyway
setopt hist_ignore_all_dups      # drop repeats entirely, not just at save time
setopt hist_reduce_blanks        # drop leading/trailing blank lines
setopt hist_ignore_space         # lines starting with a space stay out of history
setopt hist_verify               # show lines containing ! before running them
setopt hist_no_store             # keep `fc -l` out of the history list

setopt no_beep             # silence the terminal bell entirely (also covers
                           # the history-widget beep, so no_hist_beep is
                           # redundant and has been dropped)
setopt extendedglob        # ls ^bla.* will not show ^bla.txt for example

# `correct` (command names only) is kept; `correctall` was removed. correctall
# also checked ARGUMENTS, so any near-miss filename or path triggered an
# [nyae] query mid-command. Worse, matches are edit-distance over all of $PATH
# with no notion of intent: after the omz git plugin was dropped, a mistyped
# `gtst` was offered as `tset` (a real binary at /usr/bin/tset), not
# `git status`. `nocorrect <cmd>` still opts out per command.
setopt correct

# PROMPT_CR is left at its default (on). zsh documents it as load-bearing:
# "multi-line editing is only possible if the editor knows where the start of
# the line appears." Turning it off breaks cursor movement and redraw on
# wrapped or pasted multi-line input -- and vi-mode, used heavily here, is
# exactly where that shows up. It is also what PROMPT_SP compensates for, so
# disabling it silently neutered PROMPT_SP. The old comment here claimed it
# prevented "the prompt overwriting output", which is PROMPT_SP's job; that is
# now handled by the default PROMPT_SP=on.

unsetopt nomatch           # a non-matching glob is passed through literally
                           # instead of erroring. Convenient, but it turns a
                           # typo'd pattern into a confusing error from the
                           # tool rather than "no matches found" from zsh.
setopt prompt_subst        # Enable prompt substition
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

# `command grep` bypasses any grep alias (including the one oh-my-zsh caches),
# so this cannot pick up a stray --color=always the way the old version did.
# -m1 so two batteries can't pass two args to upower.
alias batstat='upower -i "$(upower -e | command grep -m1 BAT)" | command grep -B 1 percentage'
alias lg='lazygit'

# home-git tracks all of $HOME, so lazygit needs the bare gitdir and the
# worktree passed explicitly. Run hlgf <path> to scope the history to one area.
alias hlg='lazygit -w "$HOME" -g "$HOME/.home-git"'
alias hlgf='lazygit -w "$HOME" -g "$HOME/.home-git" -f'
alias homp='GIT_DIR="$HOME/.home-git" GIT_WORK_TREE="$HOME" omp'
alias i='z -i'
alias vim='nvim'
alias oc='opencode'
alias preview='bat --style=plain --paging=always'
alias wm='workmux'
alias dotsync='cd ~/mint-dotfiles && ./sync-from-home.sh && git diff'
# --color=auto (not =always) so piping into another command stays clean.
# -S is already set by ~/.ripgreprc, so it is not repeated here.
alias rg='rg --hidden --color=auto'
alias r='fc -s'
if [[ -o interactive ]]; then
  # NOTE: there is deliberately no `grep` alias. rg's -r means --replace, not
  # recursive, so `grep -rn foo .` silently printed matches with every hit
  # replaced by "n". It also breaks -v, -E and --include=. Use rg (below),
  # which is already aliased, or `command grep` when you need real grep.
  alias ls='eza --color=always --icons --group-directories-first -a'
  alias cat='bat --style=plain --paging=never'
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

# ${PWD:t} is zsh-native, so this avoids a basename fork on every prompt.
set_win_title() { print -Pn "\e]0;${PWD:t}\a" }

# starship_precmd_user_func is a BASH-only hook -- starship's own comment in the
# binary reads "Run the bash precmd function". zsh never reads it, so the window
# title was silently never being set. add-zsh-hook is the zsh equivalent.
autoload -Uz add-zsh-hook
add-zsh-hook precmd set_win_title

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

# Strips a leading `---` YAML frontmatter block from a prompt note.
# Tolerates CRLF and trailing whitespace on the fences, and exits 3 if the
# block opens but never closes -- previously that case silently produced an
# empty prompt and the function exited as if nothing had happened.
_omp_fm_strip='NR==1 { if ($0 !~ /^---[[:space:]]*\r?$/) plain=1; else f=1; next }
f && /^---[[:space:]]*\r?$/ { f=0; next }
f { next }
{ print }
END { if (f) exit 3 }'

# Shared body for ocp/ompp. $1 = agent command, $2 = inline|delegate.
# Keeping this in one place is the point: the frontmatter parser below is the
# most bug-prone line in this file and used to be duplicated verbatim.
_omp_note() {
  local agent=$1 mode=$2
  mkdir -p ~/notes/90-archive/prompts
  local f="$HOME/notes/90-archive/prompts/$(date +%Y%m%d-%H%M%S).md"
  ${EDITOR:-nvim} "$f" || return 1
  [ -s "$f" ] || { print -u2 "omp: note is empty, nothing to run."; return 1; }
  if [ "$mode" = delegate ]; then
    # neovim's BufWritePost hook (~/.config/nvim/lua/custom/omp-prompt.lua)
    # runs the agent itself on save, so there is nothing left to do here.
    return 0
  fi
  local p
  p="$(command awk "$_omp_fm_strip" "$f")" || {
    print -u2 "omp: $f opens a --- frontmatter block that never closes."
    return 1
  }
  [ -n "$p" ] || { print -u2 "omp: no prompt body found in $f"; return 1; }
  "$agent" "$p"
}

# ocp  -> opencode. Usage: ocp ["prompt"] | ocp      (opens $EDITOR on a note)
ocp() {
  (( $# )) && { opencode --prompt "$*"; return $? }
  _omp_note opencode inline
}

# ompp -> omp. Usage: ompp ["prompt"] | ompp | ompp --nvim
# --nvim opens the note and lets the neovim plugin run omp on write. It cannot
# be combined with an inline prompt, so that is rejected rather than silently
# discarding the flag.
ompp() {
  if [ "$1" = "--nvim" ]; then
    shift
    if (( $# )); then
      print -u2 "ompp: --nvim opens a note for editing; it cannot take a prompt."
      return 1
    fi
    _omp_note omp delegate
    return $?
  fi
  (( $# )) && { omp "$*"; return $? }
  _omp_note omp inline
}

export EDITOR="nvim"
export VISUAL="nvim"
export OPENCODE_DISABLE_AUTOUPDATE=true
export PLANNOTATOR_DATA_DIR="$HOME/notes/docs/plannotator"
# Man page styling. Three things had to change to get colour working:
#   1. the colored-man-pages omz plugin is gone (see plugins= above). It defined
#      `man` as a *function* forcing PAGER=less and GROFF_NO_SGR=1, which
#      silently overrode MANPAGER -- that alone made every man page plain.
#   2. `col` must NOT be in this pipeline. col turns SGR escapes back into
#      overstrike characters, stripping exactly the styling bat would use.
#      Verified: groff emits 8 escapes, `| col -bx` leaves 0.
#   3. MANROFFOPT is unset below for the same reason -- -c tells groff not to
#      emit bold/underline in the first place.
# bat then applies its own man theme on top, so the result is styled.
export MANPAGER="sh -c 'bat -l man -p --color=always --style=plain'"
export PAGER=less
export LESS="-R"        # let less pass the SGR escapes through
unset MANROFFOPT        # was "-c", which suppressed the styling entirely
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

# nvm is lazy-loaded. Sourcing nvm.sh costs ~80ms and forking uname/getconf/od
# on every shell start, which is a lot to pay for a tool most sessions never
# touch. The first call to node/npm/npx/etc. sources it for real; everything
# after that is a plain function call.
# The shims are functions, not aliases: an alias would still be in effect after
# nvm.sh loads and would recurse into itself. Each replaces itself with a
# direct call, so only the first invocation pays the load cost.
if [ -s "$NVM_DIR/nvm.sh" ]; then
  nvm() {
    unset -f nvm node npm npx yarn pnpm corepack
    . "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
    nvm "$@"
  }
  # Each shim bakes its own command name in at definition time. Two traps here,
  # both of which silently produce zero working shims:
  #   - a single-quoted body leaves $_nc to expand at CALL time, by which point
  #     it is unset, so every shim ends up calling nothing;
  #   - eval '_nc() {...}' defines a function literally named `_nc`.
  # `functions[name]=` is used rather than eval for the same reason.
  for _nc in node npm npx yarn pnpm corepack; do
    functions[$_nc]="unset -f $_nc; nvm; $_nc \"\$@\""
  done
  unset _nc
fi

[ -f ~/.free-coding-models.env ] && . ~/.free-coding-models.env  # free-coding-models-env

# tldr completion. This is appended after oh-my-zsh has already run compinit, so
# it is not in the compdump -- but zsh still autoloads _tldr from fpath on
# demand, so completion works. Verified: `tldr gi<TAB>` completes.

# zsh-syntax-highlighting MUST be sourced last. It walks the widget list once
# at source time and wraps each widget; anything that registers a ZLE widget
# afterwards (fzf's Ctrl-R/Ctrl-T widgets, pay-respects' ^X^X) is never
# wrapped and so gets no highlighting. zsh-autosuggestions does not have this
# constraint because it re-binds on every precmd.
source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

