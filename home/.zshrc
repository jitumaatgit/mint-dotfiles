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

# `kj` in insert mode -> normal mode (vim's jk). vi-mode only binds ESC/^[
# out of the box. main and viins are the same keymap under `bindkey -v`, so
# binding both is belt-and-braces, not two separate maps.
#
# The cost, per plugins/vi-mode/README.md#low-keytimeout: once `kj` is a
# binding, a BARE `k` in insert mode has to wait out $KEYTIMEOUT to see
# whether a `j` follows. The default (1) is 10ms -- too short for two human
# keystrokes to ever register as one. 20 is the compromise: fast enough to
# hit, and a lone `k` stalls 200ms. Raise it if `kj` is flaky, lower it if
# typing `k` feels laggy -- you cannot have both.
KEYTIMEOUT=20
bindkey -M main 'kj' vi-cmd-mode
bindkey -M viins 'kj' vi-cmd-mode

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

# omp silently downgrades `edit.mode: hashline` to `replace` when the active
# model classifies as kimi/mimo/minimax/deepseek/stepfun, which silently drops
# the [path#TAG] drift check AND the seen-line guard -- `enforce_seen_lines`
# is only passed to HashlineEngine, the other four modes don't accept it.
# `mimo-v2.6-flash` and `deepseek-v4.1-flash` are role primaries and fallbacks,
# so the active model itself triggers it. Strict mode keeps the flag set in config.yml.
export PI_STRICT_EDIT_MODE=1
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
# hister writes structured log lines to stdout at journald priority 6 (info):
#   <RFC3339> | LEVEL | file.go:123 > message
# journald only colours the priority field, and that field is uniform here, so
# journalctl itself can never highlight an error. Colour the LEVEL token that
# hister puts in the message body instead -- that is where the real severity
# lives. -o cat drops journald's own prefix so the parse is not confused by it.
hister-f() {
    # Trailing args are passed through to journalctl, so `hister-f -n 50` and
    # `hister-f -p warning` work; with none, it follows.
    local -a follow
    (( $# )) || follow=(-f)
    stdbuf -oL journalctl --user -u hister $follow "$@" -o cat |
        awk '
        function seg(s, a, b) { return substr(s, a, b - a + 1) }
        {
            line = $0
            p1 = index(line, "|")
            if (p1 == 0) { print line; next }
            p2 = index(substr(line, p1 + 1), "|")
            if (p2 == 0) { print line; next }
            p2 += p1
            ts   = seg(line, 1, p1 - 1)
            rest = substr(line, p1 + 1, p2 - p1 - 1)
            tail = substr(line, p2 + 1)
            lvl = rest
            gsub(/^[ \t]+|[ \t]+$/, "", lvl)
            if (lvl ~ /ERROR|FATAL|PANIC/) c = "1;31"
            else if (lvl ~ /WARN/)          c = "1;33"
            else if (lvl ~ /DEBUG|TRACE/)    c = "90"
            else                             c = "36"
            gt = index(tail, ">")
            if (gt > 0) { loc = substr(tail, 1, gt); msg = substr(tail, gt + 1) }
            else { loc = ""; msg = tail }
            gsub(/^[ \t]+/, "", loc); gsub(/[ \t]+$/, "", loc)
            printf "\033[90m%s\033[0m \033[2m|\033[0m \033[%sm%-5s\033[0m \033[2m|\033[0m \033[35m%s\033[0m %s\n",
                ts, c, lvl, loc, msg
        }'
}
alias rg='rg --hidden --color=auto'
alias r='fc -s'
if [[ -o interactive ]]; then
  # NOTE: there is deliberately no `grep` alias. rg's -r means --replace, not
  # recursive, so `grep -rn foo .` silently printed matches with every hit
  # replaced by "n". It also breaks -v, -E and --include=. Use rg (below),
  # which is already aliased, or `command grep` when you need real grep.
  alias ls='eza --color=always --icons --group-directories-first -a'
  alias cat='bat'
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
# An agent-spawned shell can inherit TERM=dumb, which makes journald, git and
# friends silently drop all colour. Only downgrade-in is a real case; never
# override a TERM that is already capable, since that would clobber a
# deliberately restrictive value (e.g. running inside a dumb CI pty on purpose).
if [[ -z "$TERM" || "$TERM" == "dumb" ]]; then
    [[ -n "$TMUX" ]] && export TERM=tmux-256color || export TERM=xterm-256color
fi
export SYSTEMD_COLORS=1

export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$HOME/.bun/bin:$PATH"

# jobsparser-fork venv: make `python` resolve to the project interpreter.
# omp's debug device spawns the debugpy adapter as `python` (not `python3`),
# and only the venv has the project's deps (textual, rich, jobspy, pandas).
# Guarded so re-sourcing cannot grow PATH without bound.
_jobsparser_venv="$HOME/projects/jobsparser-fork/.venv/bin"
[[ -d "$_jobsparser_venv" && ":$PATH:" != *":$_jobsparser_venv:"* ]] && export PATH="$_jobsparser_venv:$PATH"
unset _jobsparser_venv

# Docker (rootless). The daemon runs as this user, so its socket lives in the
# per-user runtime dir, not /run/docker.sock. DOCKER_HOST is set here rather
# than relying on `docker context use rootless` because non-CLI tools (compose,
# testcontainers, agents) only read the environment. Consequence: while this is
# exported, `docker context use` no longer changes which daemon the CLI talks
# to -- the environment wins. Derived from XDG_RUNTIME_DIR/uid instead of a
# hardcoded 1001 so it stays correct if the uid ever changes.
export DOCKER_HOST="unix://${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/docker.sock"

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

# Hister crawl job helpers.
#
#   hlog  [log]     live tail, scrollable, q quits     (no colour -- see below)
#   hlogc [log] [n] last n lines, Catppuccin coloured, paged   (static)
#   hstat [job]     crawl job STATE counters, coloured        (static)
#
# WHY NO `watch`, and why not `tail -f | bat`: those two cannot be combined.
#
#   bat buffers stdin until EOF, so `tail -f ... | bat` renders nothing at
#   all, forever. bat 0.26.1 has no --follow either (`-r` is --line-range).
#   A redrawing loop is the usual workaround, and `watch` is the obvious
#   choice -- but procps-ng 4.0.4 does not hand the command to a shell, it
#   re-tokenises it itself. Under a real pty it printed its own header and
#   then nothing at all: the `| bat ...` half never ran. That is why the old
#   hlog/hstat came out uncoloured and full-screen.
#
#   So the two behaviours are split across two functions instead of faked
#   into one:
#     - live tail  -> `tail -f | less -R +F`. less follows the stream, keeps
#       scrollback, `q` quits, F toggles follow. No colour: a pipe into less
#       is just bytes, there is no highlighter in the chain.
#     - colour     -> bat reading a FINITE chunk, so it sees EOF and renders.
#       Catppuccin via ~/.config/bat/config; --color/--decorations=always are
#       spelled out because config deliberately leaves them at `auto` (that
#       is what keeps `bat f | rg x` clean for scripts). Do not set
#       XDG_CONFIG_HOME -- that bypasses the stowed config and silently
#       reverts the theme.
#
#   --file-name makes bat's header show the real path; without it bat prints
#   STDIN, because it is reading a pipe.
# NO PATH DEFAULT, deliberately. The old default was /tmp/hister-sectionb.log,
# a job that finished on 2026-09-29 — a dead file. That is the worst possible
# default for a follow-mode command: `tail -f` on a file that will never grow
# never prints anything and never exits, so hlog looks broken and has to be
# killed. Same for HISTER_JOB pointing at the finished section-b crawl.
#
# With no argument, hlog/hlogc now track hister's live journal, which is the
# only hister feed that is current whenever hister is running. Pass a path to
# follow or snapshot a specific file instead:  hlog /tmp/whatever.log
#
# Do not add a [ -t 1 ] guard here. These are run in a real terminal; an
# agent-side tool call is non-TTY and must simply not run hlog at all.
HREINDEX_UNIT="${HREINDEX_UNIT:-hister.service}"

hlog() {
  if [[ -n "$1" ]]; then
    tail -f "$1" | less -R +F
  else
    journalctl --user -u "$HREINDEX_UNIT" -f -o cat | less -R +F
  fi
}

hlogc() {
  #   hlogc            -> 40 lines of the journal
  #   hlogc 200        -> 200 lines of the journal
  #   hlogc FILE [N]   -> N lines of FILE (default 40)
  # A bare number is a line count, not a path. Without that, `hlogc 3` is read
  # as a file named "3" and dies with a confusing tail error.
  local log="" n=40
  if [[ -z "$1" || "$1" == <-> ]]; then
    [[ -n "$1" ]] && n="$1"
  else
    log="$1"
    [[ -n "$2" ]] && n="$2"
  fi
  if [[ -n "$log" ]]; then
    tail -n "$n" "$log" | bat -l log --color=always --paging=always --file-name="$log"
  else
    journalctl --user -u "$HREINDEX_UNIT" --no-pager -o cat -n "$((n * 20))" \
      | tail -n "$n" | bat -l log --color=always --paging=always --file-name="$HREINDEX_UNIT"
  fi
}

HISTER_JOB="${HISTER_JOB:-section-b-urls.txt}"   # a crawl job name, not a path

# hstat deliberately shows only the STATE block. `hister crawl show` also dumps
# the full ValidatorRules JSON, which is static and just pushes the counters
# off screen. It is a one-shot on purpose: re-run it (or `!!`) rather than sit
# in a full-screen loop for four numbers that move once a minute.
hstat() {
  local job="${1:-$HISTER_JOB}"
  hister crawl show "$job" | sed -n '/STATE/,/^$/p' | bat --color=always --paging=never --file-name="$job" -l log
}

# --- hister reindex ------------------------------------------------------
# The reindex CLIENT is silent: `hister reindex` writes to its own stdout only
# when the whole rebuild finishes, so /tmp/hister-reindex.log stays at 0 bytes
# for the entire run. All live progress comes from the SERVER, which logs a
# "Reindexed [N/total]" line to the journal every 50 documents, alongside
# per-document extraction failures. These helpers read the journal, not the log.
HREINDEX_UNIT="${HREINDEX_UNIT:-hister.service}"

# Live follow: progress counters and extraction failures as they happen.
hrlog() {
  journalctl --user -u "$HREINDEX_UNIT" -f -o cat \
    | grep --line-buffered -E "Reindexed \[|Failed to extract|ERROR"
}

# Coloured snapshot of the last N matching lines.
hrlogc() {
  local n="${1:-40}"
  journalctl --user -u "$HREINDEX_UNIT" --no-pager -o cat -n 20000 \
    | grep -E "Reindexed \[|Failed to extract|ERROR" | tail -n "$n" \
    | bat -l log --color=always --paging=always --file-name="$HREINDEX_UNIT"
}

# One-shot: current count, rate, ETA, and extraction failure count.
#
# Everything is scoped to THIS run. The journal accumulates, so a naive
# "first Reindexed line" reaches back into the previous session's reindex and
# yields a nonsense rate; and "-n 20000" for the failure count silently includes
# every prior run's warnings. The run's start is taken from the client process
# start time, which is exact and needs no guessing from log content.
hrstat() {
  local u="${1:-$HREINDEX_UNIT}" pid since prog d0 d1 t0 t1 c0 c1 tot
  local rate eta warns
  local -a since_arg

  pid=$(pgrep -f 'hister reindex' | head -1)
  if [[ -n "$pid" ]]; then
    since=$(date -d "$(ps -o lstart= -p "$pid" 2>/dev/null)" +"%Y-%m-%d %H:%M:%S" 2>/dev/null)
  else
    since=""
  fi
  # Must be an array: zsh does not word-split unquoted expansions, so
  # ${since:+--since "$since"} reaches journalctl as ONE argument and --since
  # silently matches nothing.
  [[ -n "$since" ]] && since_arg=(--since "$since")

  prog=$(journalctl --user -u "$u" --no-pager -o short-unix \
    "${since_arg[@]}" 2>/dev/null | grep -E "Reindexed \[")
  if [[ -z "$prog" ]]; then
    print -r -- "STATE  no 'Reindexed [N/total]' lines yet in $u"
    return
  fi

  # zsh parameter expansion cannot do this -- "*Reindexed [" is a bad pattern
  # because "[" opens a character class -- and [[ =~ ]] mis-parses the escaped
  # bracket here, leaving c1/tot empty and dividing by zero. sed is unambiguous.
  d1=$(print -r -- "$prog" | tail -1)
  read -r c1 tot <<< "$(print -r -- "$d1" | sed -nE 's/.*Reindexed \[([0-9]+)\/([0-9]+)\].*/\1 \2/p')"
  if [[ -z "$c1" || -z "$tot" || "$tot" -eq 0 ]]; then
    print -r -- "STATE  could not parse a 'Reindexed [N/total]' line"
    return
  fi
  print -r -- "STATE  $c1 / $tot  ($(( c1 * 100 / tot ))%)"

  if [[ -n "$pid" ]]; then
    print -r -- "PROC   running (pid $pid, up $(( $(ps -o etimes= -p "$pid" | tr -d ' ') / 60 ))m)"
  else
    print -r -- "PROC   idle -- no 'hister reindex' process"
  fi

  # Rate from a RECENT window (last 6 counters, ~250 docs), not the whole run:
  # a long average hides the fact that early extraction-heavy documents are far
  # slower than later ones.
  d0=$(print -r -- "$prog" | tail -6 | head -1)
  c0=$(print -r -- "$d0" | sed -nE 's/.*Reindexed \[([0-9]+)\/.*/\1/p')
  t0=${d0%%.*}; t1=${d1%%.*}
  if [[ -n "$c0" && "$c1" != "$c0" && "$t1" != "$t0" ]]; then
    rate=$(( (c1 - c0) * 60 / (t1 - t0) ))
    print -r -- "RATE   ~${rate} docs/min  (last $(( c1 - c0 )) docs)"
    if [[ $rate -gt 0 ]]; then
      eta=$(( (tot - c1) * 60 / rate ))
      print -r -- "ETA    ~$(( eta / 60 ))m $(( eta % 60 ))s"
    fi
  fi

  warns=$(journalctl --user -u "$u" --no-pager -o cat \
    "${since_arg[@]}" 2>/dev/null | grep -c "Failed to extract")
  print -r -- "FAILS  $warns extraction failures this run"
}
# `caps` toggles Caps Lock. Caps Lock is ON whenever you are typing in ALL
# CAPS, which is exactly when you want to turn it off -- but zsh alias lookup
# is case-SENSITIVE, so typing it with Caps Lock on yields `CAPS`, which would
# not match a `caps` alias. Hence one alias per case variant.
#
# Why a command is needed at all: keyd remaps the CapsLock KEY on the internal
# laptop keyboard to tap=Escape / hold=Control (/etc/keyd/laptop.conf). The Menu
# key still gives real Caps Lock, and `caps` gives it from anywhere.
for _c in caps CAPS Caps cAPs CaPs caPS capS CapS capstog CAPSTOG CapsTog; do
	alias $_c='capstog'
done
unset _c

# zsh-syntax-highlighting MUST be sourced last. It walks the widget list once
# at source time and wraps each widget; anything that registers a ZLE widget
# afterwards (fzf's Ctrl-R/Ctrl-T widgets, pay-respects' ^X^X) is never
# wrapped and so gets no highlighting. zsh-autosuggestions does not have this
# constraint because it re-binds on every precmd.
source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

