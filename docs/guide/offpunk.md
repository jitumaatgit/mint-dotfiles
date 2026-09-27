# Offpunk: reference & setup for this machine

Primary sources only: the canonical repo <https://git.sr.ht/~lioploum/offpunk> (read at
commit `b69a5e81`, 2026-09-21, `__version__ = "3.2"`), the official tutorial
<https://offpunk.net/>, the author's release notes on <https://ploum.net>, and the
installed package metadata on this machine. Every claim below was read in the source
or observed by running the program; anything reasoned rather than observed is marked
`[INFERENCE]`.

Versions in play at time of writing (2026-09-25):

| Source | Version |
|---|---|
| `git.sr.ht` master | **3.2** (`b69a5e81`) |
| PyPI `offpunk` | 3.1 |
| Ubuntu noble `offpunk` package | **2.2-1** (installed here, but broken — see §2) |

---

## 1. What Offpunk is

Offpunk is an offline-first, command-line browser and feed reader written in Python by
Lionel Dricot ("Ploum"), a fork of Solderpunk's AV-98 that was originally called
"AV-98-offline" (`man/offpunk.1`, HISTORY section; `README.md`).

- **Command-line only.** No mouse, no tabs; every action is a typed command at a
  `ON>` / `OFF>` prompt, and long pages are paged through `less`
  (<https://offpunk.net/whatisoffpunk.html>, <https://offpunk.net/firststeps.html>).
- **Offline-first.** Everything you visit is cached; content that isn't cached is
  recorded and fetched at the next `sync`. You can then browse offline
  (<https://offpunk.net/offline.html>).
- **Protocols.** `http/https/gemini/gopher/spartan/finger` are handled transparently
  (<https://offpunk.net/whatisoffpunk.html>). `netcache.PROTOCOLS` in the source is the
  authoritative list; `ftp://` is landing in the unreleased 3.3 (`CHANGELOG`).
- **Reads** HTML (via readability and/or unmerdify), Gemtext, Gophermap, txt, RSS,
  Atom and images. Offpunk deliberately does not distinguish "web page" from "feed"
  — any page with links can be subscribed to
  (<https://offpunk.net/subscriptions.html>).
- **Unix philosophy.** Four independently usable tools: `offpunk`, `netcache`,
  `ansicat`, `openk` (`README.md`, `pyproject.toml` `[project.scripts]`; 3.x adds
  `unmerdify` and `xkcdpunk`).

### Install location facts, verified

- Upstream **3.2 with the `[full]` extra** is installed via `uv tool` at
  `~/.local/share/uv/tools/offpunk/`, with all six launchers symlinked into
  `~/.local/bin/`. `zsh -lic 'whence -va offpunk'` resolves to
  `~/.local/bin/offpunk`. The interactive `version` command reports every optional
  dependency as Installed.
- `~/.config/offpunk/offpunkrc` is symlinked to
  `~/mint-dotfiles/home/.config/offpunk/offpunkrc` and loads correctly.
- `~/.offpunk` does not exist (that legacy path would override the XDG config dir
  entirely — leave it absent).

---

## 2. Installing

### Option A — upstream 3.2 into an isolated tool env (recommended here)

Upstream is 3.2; the distro package is 2.2 and currently broken, so install from
source. `uv` is already on this box.

> **You must ask for the `[full]` extra.** Offpunk declares *no* mandatory Python
> dependencies — `feedparser`, `bs4`, `lxml`, `readability-lxml`, `cryptography`,
> `charset-normalizer` and `setproctitle` are all gated behind optional extras in
> `pyproject.toml`. A plain `uv tool install` / `pipx install` therefore produces a
> working-but-crippled Offpunk: no HTML rendering, no RSS/Atom, no certificate
> detail. `[full]` is the extra that pulls them all in. Verified by importing each
> module in the tool venv.

```bash
uv tool install --force "offpunk[full] @ git+https://git.sr.ht/~lioploum/offpunk@v3.2"
# -> installs 17 packages and 6 executables into ~/.local/bin:
#    offpunk netcache ansicat openk unmerdify xkcdpunk
offpunk --version     # Offpunk 3.2
```

Beware the **tilde in the URL**: it is a real `~`, and if your shell or editor
escapes it to `\~` you get `fatal: repository
'https://git.sr.ht//~lioploum/offpunk/' not found` (note the double slash and the
invisible backslash). If that happens, percent-encode it — `%7Elioploum` — which
`git ls-remote` accepts. `uv` resolves the tag to commit
`58a1d4fd532b4aa741238ea4bc5483837418b36c` for `v3.2`.

`~/.local/bin` is already first on this machine's `PATH` (`.profile` and `.zshrc`
both prepend it), so `~/.local/bin/offpunk` wins over `/usr/bin/offpunk` with no
shell change. Confirm with `zsh -lic 'whence -va offpunk'`.

Alternatives from the same source: `pipx install 'offpunk[full] @ git+…'` or a plain
clone — "no build is required. You can launch offpunk.py/openk.py/ansicat.py/
netcache.py directly" (<https://offpunk.net/install.html>), but then *you* must
install the Python deps yourself. Plain PyPI (`pipx install offpunk`) gets **3.1**,
not 3.2.

To remove the broken distro copy once you're on 3.2:
`sudo apt remove offpunk` (this also removes `/usr/bin/offpunk`).

### Option B — distro package

`sudo apt install offpunk` installs 2.2-1 and needs `python3-lxml-html-clean`
alongside it to start at all (2.2's `python3-readability` imports `lxml.html.clean`,
which lxml ≥ 5 dropped). Only worth it if you specifically want a distro-tracked
version. Note the apt 2.2 already becomes inert once `~/.local/bin` is ahead of
`/usr/bin`, but leaving it installed is a trap if your `PATH` ever changes.

### Dependencies (source: `pyproject.toml` extras, `requirements.txt`, `ubuntu_dependencies.txt`, `README.md`)

Strictly mandatory: Python ≥ 3.7 (3.3 will require ≥ 3.9), plus the `less` pager —
Offpunk prints "Please install the pager less to run Offpunk" and exits without it
(`offutils.py`).

Everything else is optional, and the split matters. `version` (interactive) prints
this exact audit; `--features` was meant to but is broken (see §10).

| Extras group | Pulls in |
|---|---|
| `html` | `bs4`, `lxml`, `readability-lxml` |
| `rss` | `feedparser` |
| `better-tofu` | `cryptography` |
| `chardet` | `charset-normalizer` |
| `process-title` | `setproctitle` |
| **`full`** | **all of the above** |

Non-Python binaries come from apt. One line covers everything relevant on Mint
(from `ubuntu_dependencies.txt`):

```bash
sudo apt install less file xdg-utils curl chafa xclip
```

The `python3-*` apt packages from `ubuntu_dependencies.txt` exist too, but they are
**irrelevant to a `uv`/`pipx` install** — those tool venvs do not see
`/usr/lib/python3/dist-packages`. The `[full]` extra is what you need instead.

What each buys you, per `README.md`:

| Package | Without it |
|---|---|
| `less` | Offpunk refuses to start |
| `file` | MIME detection of cached objects |
| `xdg-utils` (`xdg-open`) | no fallback for unrenderable types; `mailto:` |
| `curl` | no http/https at all (3.2 moved HTTP *and* gopher onto curl) |
| `cryptography` | weaker TOFU certificate checking |
| `bs4` + `readability` (+ `lxml-html-clean`) | HTML isn't rendered |
| `feedparser` | RSS/Atom subscriptions don't parse |
| `charset-normalizer` | encoding detection (suggested, not required, since 3.2) |
| `chafa` | no inline images. Currently **missing here** — `apt install chafa` (1.14 is available) |
| `xsel`/`xclip`/`wl-copy` | `go` with no argument and `copy` can't use the clipboard. `xclip` is installed; `xsel`/`wl-copy` are not |
| `setproctitle` | process still shows as `python` |

Rendering a page and rendering an *image* are different code paths: images appear as
blocks while paging with `less`; following the image link directly shows it inline
and "requires a sixel-compatible terminal" (<https://offpunk.net/view.html>).

---

## 3. Configuration — the offpunkrc

This is the part that matters for dotfiles. **There is exactly one config file:**
`offpunkrc`, read by `init_config()` in `offutils.py`:

```python
if not rcfile:
    rcfile = os.path.join(xdg("config"), "offpunkrc")
```

and `xdg("config")` resolves to, in order (`offutils.py`, `xdg()`):

1. `$XDG_CONFIG_HOME/offpunk/` if `XDG_CONFIG_HOME` is set, else `~/.config/offpunk/`
2. **overridden entirely** by `~/.offpunk/` if that legacy directory exists

So on this machine the path is `~/.config/offpunk/offpunkrc`.

The format is **one interactive command per line** — "simply write one command per
line, just like you would type them in offpunk" (`README.md`, "RC files" section).

**There is no comment syntax and no blank-line tolerance.** `init_config()` passes
*every* line of the file to `onecmd()`; there is no `#` check, and nothing is skipped.
A `#` line or an empty line is dispatched like any other command, fails, and prints
`What?`. Verified: a 5-line rc with 3 comments and 1 blank line produced 4 `What?`
errors around the one real `set`.

This is worth internalizing because it makes a heavily-commented rc file actively
hostile: each launch replays every comment as a failed command. Keep the rc file to
bare commands only, and put the explanations in this document (or in a separate
`.md`) instead. `#` *is* meaningful inside **list** files (the `#subscribed` /
`#frozen` tags), which is a different code path and easy to conflate.

### What runs, and when

`init_config(rcfile, skip_go, interactive, verbose)` classifies every line
(`offutils.py`):

| Line starts with | interactive start | `--sync` / non-interactive |
|---|---|---|
| `redirect`, `handler`, `set` | runs | **runs** |
| `go`/`g`/`tour`/`t` | runs (skipped if a URL was given on the CLI) | skipped |
| anything else (`offline`, `theme`, `list …`) | runs | **skipped** |

Verified empirically against scratch `HOME`s. The cleanest test uses a deliberately
invalid value as a probe, since `theme` otherwise applies silently: an rc containing
`theme preset BOGUSNAME` prints "not a valid preset" in an interactive session but is
never dispatched under `--sync`. Meaning: **only `set`, `handler` and `redirect` persist
into non-interactive syncs.** `offline` and `theme` are interactive-only — and the
`offline` line is exactly what Ploum himself uses
(<https://offpunk.net/workflow_ploum.html>: "My offpunk is offline by default. The
config file contains one line: `offline`").

The practical consequence: a `handler` or `redirect` you want during a scheduled
`--sync` works, but you cannot make a sync start offline, because `offline` is skipped
there. `--sync` is offline by nature anyway — it fetches only what lists require.

### `set` does NOT persist on its own — this is the key gotcha

`do_set` (`offpunk.py`) mutates the in-memory `self.options` dict; nothing is written
back to disk. Confirmed empirically: after a session that ran `set width 100`, the
config directory contained no options file at all, and a new session reverted to the
default. **The rc file is how you make `set` permanent** — `README.md`: "This can be
used to make settings controlled with the `set`, `handler` or `themes` commands
persistent."

Same for `handler` and `redirect` (stored in the in-memory `mime_handlers` and
`self.opencache.redirects`; see `openk.py` `set_handler`, `offblocklist.py`). Note
that `offblocklist.py` ships a built-in privacy blocklist+redirect list
(`*medium.com -> libmedium.batsense.net`, `twitter.com`/`x.com`/facebook blocklisted,
`offpunk.net` whitelisted), which is merged with yours in `GeminiClient.__init__`.

### Full list of `set` keys

Defaults copied verbatim from the `self.options` dict at `offpunk.py:187` (3.2):

| Key | Default | Notes |
|---|---|---|
| `debug` | `False` | |
| `beta` | `False` | |
| `timeout` | `600` | long-operation timeout, seconds |
| `short_timeout` | `5` | |
| `width` | `72` | text width; capped by real terminal width |
| `auto_follow_redirects` | `True` | |
| `tls_mode` | `tofu` | `ca` or `tofu` |
| `archives_size` | `200` | items kept in the `archives` list |
| `history_size` | `200` | items kept in `history` |
| `max_size_download` | `10` | MB |
| `editor` | `None` | falls back to `$VISUAL`, then `$EDITOR` (`offutils.py`) |
| `images_mode` | `readable` | `none`/`readable`/`full` — which HTML images to fetch |
| `wikipedia` | `gemini://gemi.dev/cgi-bin/wp.cgi/view/%s?%s` | |
| `search` | `gemini://kennedy.gemi.dev/search?%s` | |
| `websearch` | `https://wiby.me/?q=%s` | used by the `websearch` command |
| `accept_bad_ssl_certificates` | `False` | set by `--assume-yes` at sync |
| `default_protocol` | `gemini` | used when a URL has no scheme |
| `ftr_site_config` | `None` | **path to the ftr-site-config rules repo** (unmerdify) |
| `preformat_wrap` | `False` | |
| `images_size` | `100` | int; clamped to text width |
| `linkmode` | `none` | `none` or `end` |
| `default_cmd` | `links 10` | what Enter on an empty line runs |
| `prompt_on` / `prompt_off` / `prompt_close` | `ON` / `OFF` / `> ` | prompt text |
| `gemini_images` | `True` | |

Value parsing in `do_set`: bare integers become `int`, `true`/`false` become bools,
`"quoted values"` get unquoted, other numerics become `float`, everything else stays a
string. An unrecognised key prints "Unrecognised option" and is ignored. Some options
(`preformat_wrap`, `width`, `linkmode`, `gemini_images`) trigger a cache cleanup so
rendering is redone.

### Other rc-file commands worth persisting

- `redirect ORIGIN DEST` — rewrite a domain to a privacy frontend.
- `redirect ORIGIN BLOCK` — block it (subdomain wildcards with a leading `*`).
- `redirect ORIGIN WHITELIST` — always show that domain in full view, skipping
  readability/unmerdify (both documented at <https://offpunk.net/view.html>, and in
  `do_redirect`'s help text). Reset with `redirect ORIGIN NONE`.
- `handler MIMETYPE CMD` — external handler; `%s` is replaced by the filename and is
  appended automatically if you omit it (`do_handler`). MIME type *or* file extension
  both match (`openk.py` `_get_handler_cmd`).
- `theme preset NAME` — presets are `offpunk1` (default), `yellow`, `cyan`, `bw`
  (`offthemes.themes`). `theme ELEMENT COLOR…` for fine-grained control.

---

## 4. Files and directories (verified by running it)

| Path | Contents |
|---|---|
| `~/.config/offpunk/offpunkrc` | the config file |
| `~/.cache/offpunk/` | the offline cache, as plain `.gmi`/`.html`/`.png` files mirroring the site tree, split per protocol: `gemini/<host>/…`, `https/<host>/…`, plus `.version` |
| `~/.local/share/offpunk/lists/` | one `.gmi` per list: `bookmarks.gmi`, `rss.gmi`, `history.gmi`, `to_fetch.gmi`, `archives.gmi`, `tour.gmi`, … |
| `~/.local/share/offpunk/certs/` | TOFU certificates, `certs/<host>/<ip>/<sha>` |
| `~/.local/share/offpunk/reply/` | remembered reply-to addresses for `reply` |

Important: **lists moved from `~/.config/offpunk/` to
`~/.local/share/offpunk/`** in recent versions — `get_list()` in `offpunk.py` carries a
migration comment. If you are reading older documentation that puts `bookmarks` in the
config dir, it is out of date.

Environment variables the code consults (`offutils.py`): `XDG_CONFIG_HOME`,
`XDG_DATA_HOME`, `XDG_CACHE_HOME`, `OFFPUNK_CACHE_PATH` (full override of the cache
location), `VISUAL`, `EDITOR`. `NO_COLOR` is not consulted `[INFERENCE]`.

The cache is deliberately database-free: "The cache can thus be modified by hand,
content can be removed, used or added by software other than offpunk" (`README.md`).
There is **no automatic trimming** — delete directories by hand when it grows.
`netcache` reads the same cache, so other tooling can consume it.

---

## 5. Command reference (the essentials)

49 `do_*` commands exist; `help` lists them in-app and `help CMD` explains one. The
ones that matter day to day (verified from `help output` and the tutorial):

**Navigation** — `go URL` (`go` with no argument pulls the URL from the clipboard),
`back`/`b`, `forward`/`f`, `up`, `root`, `url`, `info`, `history`, `mark`, `find`.

**Links & views** — `view`/`v` (current page), `v X` (preview link X), `view full`,
`view normal`, `view switch`, `view feed`, `links` (replaces the deprecated `ls` in 3.0).

**Reading lists** — `add [LIST]` (default `bookmarks`), `move LIST`, `archive`,
`bookmarks`/`bm`, `list`, `list LIST`, `list create NAME`, `list edit NAME`,
`list subscribe NAME`, `list freeze NAME`, `list normal NAME`, `list delete NAME`.

**Subscriptions** — `subscribe` offers the feeds found on the current page and files
the chosen one in the auto-created `subscribed` list; `feed` views a discovered feed;
`v full` on a feed shows whole articles rather than titles
(<https://offpunk.net/subscriptions.html>).

**Tour** — a FIFO of pages to visit, saved across sessions. `tour`/`t` (next item),
`t 1 2 3`, `t 1-3`, `t *`, `t LIST`, `t .`, `tour ls`, `tour clear`
(`do_tour` help text).

**Sync / offline** — `offline`, `online`, `reload`, `sync` (interactive; takes a
cache-validity in seconds as argument).

**Externals** — `open` (cached copy via `xdg-open`), `open url` (real browser),
`open 2 4`, `open url 2 4`, `copy url`, `share`, `reply`, `shell`.

**Meta** — `set`, `handler`, `redirect`, `theme`, `alias`, `cookies`,
`version`, `bugreport`, `tutorial`, `help`, `quit`.

---

## 6. CLI flags (from `main()` in `offpunk.py`, 3.2)

| Flag | Meaning |
|---|---|
| `URL …` | go to URL(s); with more than one, they are queued on the tour |
| `--bookmarks` | start on the bookmarks list |
| `--command CMD …` | run command(s) after startup, **space-separated after one flag** |
| `--config-file FILE` | use this rc file instead of `~/.config/offpunk/offpunkrc` |
| `--sync [LIST …]` | non-interactive cache build; no args = all lists |
| `--assume-yes` | auto-accept certificate/redirect questions during sync |
| `--disable-http` | don't fetch http(s) |
| `--fetch-later URL …` | queue URL(s) into `to_fetch` (or `tour` if already cached) and exit |
| `--depth N` | cache-build depth, default 1 |
| `--images-mode …` | `none`/`readable`/`normal`/`full` |
| `--cache-validity SECONDS` | only refresh caches older than this; 0/absent = never refresh |
| `--version`, `--features` | print version / dependency report and exit |

`--command` gotcha, verified: it is `nargs="*"`, so repeating the flag **overwrites**
the previous value. Use one flag:

```bash
offpunk --command "list create rss" "list subscribe rss" "exit"   # correct
offpunk --command "list create rss" --command "list subscribe rss" # WRONG: only the last survives
```

Sync examples, straight from <https://offpunk.net/sync.html>:

```bash
offpunk --sync --cache-validity 43200          # refresh anything older than 12h
offpunk --sync bookmarks tour to_fetch --cache-validity 3600
offpunk --fetch-later https://example.com/some/article
```

Ploum's own morning sync is
`offpunk --sync --assume-yes --cache-validity 51840` plus `t`
(<https://offpunk.net/workflow_ploum.html>).

---

## 7. Lists: the on-disk format

A list is gemtext, hand-editable, with a title line carrying optional status tags.
Real generated file, from the smoke test:

```gemtext
# rss
=> gemini://offpunk.net/ Offpunk, an offline-first command-line browser (offpunk.net)
```

and a system list, which also records visit time:

```gemtext
#history
=> list:/// (unknown) (), visited on Fri Sep 25 17:13:02 2026
=> gemini://offpunk.net/ Offpunk, an offline-first command-line browser (offpunk.net), visited on Fri Sep 25 17:13:02 2026
```

Status tags live on line 1 (`list_modify()`): `#subscribed` makes new links in those
pages land in your tour at sync time, `#frozen` stops them being refreshed, no tag =
plain list that is refreshed but adds nothing to the tour. Adding the tag by hand in
`list edit` is equivalent to running `list subscribe`/`list freeze`
(<https://offpunk.net/subscriptions.html>, <https://offpunk.net/frozen.html>).

System lists are `history`, `to_fetch`, `archives`, `tour` — editable but not
deletable or freezable (`do_list` help text). `archives` keeps the last
`archives_size` (200) archived URLs; `history` keeps `history_size` (200).

---

## 8. Setting this up for this machine (stow)

The repo stows `home/` onto `$HOME`, so the config lives at
`home/.config/offpunk/offpunkrc` and `stow -t $HOME home` puts it in place.

> **`./install.sh` currently aborts, for an unrelated reason.** Stow refuses the
> whole run because `~/.zshrc` is a regular file while `home/.zshrc` is tracked —
> and the two have *diverged* (249 vs 213 lines; `$HOME` has compinit caching,
> `select-quoted` ZLE bindings and a `batstat` alias the repo lacks). Stow's message:
>
> ```
> WARNING! stowing home would cause conflicts:
>   * existing target is neither a link nor a directory: .zshrc
> All operations aborted.
> ```
>
> Until that is reconciled (commit the `$HOME` version into the repo, then re-run,
> or adopt the link with `stow --adopt`), no stowed file can be installed — including
> `offpunkrc`. The rc file in this repo was therefore linked by hand, doing exactly
> what stow would have done:
>
> ```bash
> mkdir -p ~/.config/offpunk
> ln -sfn ../../mint-dotfiles/home/.config/offpunk/offpunkrc ~/.config/offpunk/offpunkrc
> ```
>
> Stow can confirm the rest of the plan without touching the filesystem:
> `stow -n -v --ignore='\.zshrc' -t "$HOME" -d ~/mint-dotfiles home`.

`[INFERENCE]` the only file that belongs in the repo is `offpunkrc`. Do **not** stow
`~/.cache/offpunk`, `~/.local/share/offpunk/lists` (they mutate constantly) or
`~/.local/share/offpunk/certs` — the repo's own `notes/docs/workflow.md` says the same
thing about caches and runtime state. `lists/` is user data, not dotfiles; back it up
separately if it matters.

Proposed `home/.config/offpunk/offpunkrc` for this machine — this is the exact content
now committed in this repo:

```conf
set width 100
set linkmode end
set timeout 30
set history_size 500
set archives_size 500
handler application/pdf zathura %s
```

That is the whole file. **Do not add comments** (§3): a `#` line is dispatched as a
command and prints `What?`. Configuration rationale that would normally live in
comments belongs here instead — every one of those lines is a deliberate choice:

| Line | Why |
|---|---|
| `set width 100` | comfortable at this terminal's width; Offpunk clamps it to the real terminal anyway |
| `set linkmode end` | collect links in a numbered block at the end of the page rather than inline |
| `set timeout 30` | down from the 600 s default; a hung fetch shouldn't look like a freeze |
| `set history_size 500` | up from 200 — cheap insurance for recall |
| `set archives_size 500` | up from 200, same reason |
| `handler application/pdf zathura %s` | zathura 0.5.4 + pdf-poppler is installed at `/usr/bin/zathura` |

Deliberately **not** set, with reasons:

- `offline` — Ploum runs offline-by-default, but it is a workflow change, not a
  default improvement: with it you must type `online` before `go <url>` reaches the
  network. Add it only if you want that.
- `set websearch …` — the default is `https://wiby.me/?q=%s`, which is a reasonable
  privacy-respecting choice. Pointing it at DuckDuckGo's HTML endpoint is a
  preference, not a fix.
- `set ftr_site_config …` — `~/projects/ftr-site-config` does not exist on this
  machine, and a missing rules path is worse than no rules path.
- `handler image/png chafa …` — images already render inline through `chafa`
  automatically once it is installed (§2); a handler would only override the sizing.
- `redirect` for youtube/reddit/twitter — Offpunk's built-in blocklist
  (`offblocklist.py`) already blocks `twitter.com`, `x.com`, `fbcdn.net`,
  `tiktok.com`, `linkedin.com`, doubleclick et al. and redirects medium → scribe.rip.
  Additions here are a privacy preference; make them consciously.
- `set prompt_on` / `prompt_off` — the built-in `ON`/`OFF` defaults are already the
  obvious choice; overriding them with the same values is pure noise.

If you want any of the above, append the bare command to the rc file.

One search tip worth keeping: `~/.cache/offpunk` is a plain-file mirror of
everything you have read, so `grep -r` through it when hunting for something you
saw months ago (<https://offpunk.net/workflow_ploum.html>).

### Optional: unmerdify rule set

3.0 integrated "unmerdify", which strips cruft using the community-maintained
`ftr-site-config` rules; without a rule it falls back to readability
(<https://ploum.net/2026-02-09-offpunk3.html>). `info` tells you which one was used.
Rules are a plain git checkout stored anywhere:

```bash
git clone https://github.com/fivefilters/ftr-site-config ~/projects/ftr-site-config
# then in offpunkrc:
set ftr_site_config /home/mint/projects/ftr-site-config
```

Refresh with `git pull` in that directory (`info` output, <https://offpunk.net/view.html>).
Not currently present on this machine.

### Optional: daily sync

- [ ] make cron job for offpunk daily sync
```bash
# ~/.config/systemd/user/offpunk-sync.service + .timer, or plain cron
offpunk --sync --assume-yes --cache-validity 43200
```

`--cache-validity 43200` = 12 h; `--assume-yes` accepts new TOFU certificates, which is
what Ploum does himself at `51840` (15 h).

---

## 9. Cheatsheet: first run, end to end

```bash
uv tool install --force "offpunk[full] @ git+https://git.sr.ht/~lioploum/offpunk@v3.2"
sudo apt install chafa xclip        # inline images + X11 clipboard
sudo apt remove offpunk             # drop the broken 2.2 copy (already done here)

# Link the rc file. `./install.sh` cannot be used until the ~/.zshrc conflict
# is resolved (see §8) — it aborts the whole stow run.
mkdir -p ~/.config/offpunk
ln -sfn ../../mint-dotfiles/home/.config/offpunk/offpunkrc ~/.config/offpunk/offpunkrc

offpunk                             # browse
# inside: `version` audits your install; `--features` is broken upstream
```

`sudo apt remove offpunk` has already been done on this machine, and the rc symlink is
already in place — the sequence above is for a fresh machine or a rebuild.

First moves inside Offpunk:

```
help            # command list
tutorial        # the built-in tutorial
go gemini://offpunk.net
tour 1-3        # queue links 1..3
t               # next queued page
add toread      # bookmark into a list
list create rss
list subscribe rss
offline         # keep reading from cache
```

---

## 10. Gotchas worth remembering

- **`set` doesn't save itself.** Anything you change interactively is gone at exit
  unless it is in `offpunkrc`. This is the single most common surprise.
- **The rc file takes no comments and no blank lines.** Every line is dispatched as a
  command, so `#` or an empty line prints `What?`. Verified: 3 comments + 1 blank
  line = 4 errors. Keep explanations out of the file (§3, §8).
- **A plain `uv tool install` / `pipx install` has no HTML, no RSS, no crypto.**
  Offpunk's Python dependencies are all optional extras; install `offpunk[full]`.
  Run the interactive `version` command to check what you actually got.
- **`--features` prints nothing (upstream bug).** `main()` calls
  `gc.do_version(None, None)` — passing `print_color=None`, which makes
  `do_version` *return* the report instead of printing it. The only output is the
  chafa warning. Use the interactive `version` command instead. Present in 3.2 and
  on master as of this writing.
- **Repeated `--command` flags overwrite.** Use `--command A B C`.
- **`--sync` only honours some rc lines** (`set`/`handler`/`redirect`). `theme` and
  `offline` are interactive-only.
- **Lists live in `~/.local/share/offpunk/lists`, not next to the config**, despite
  older docs saying otherwise.
- **`go` without an argument reads the clipboard** — needs `xsel`/`xclip`/`wl-copy`.
  This is X11 (Cinnamon), so `xclip` (installed) is the right one; Wayland's
  `wl-copy` is not needed and `xsel` is absent.
- **`offline` does not mean "internet is down".** Offpunk has no connectivity
  detection: online mode always attempts a connection, offline mode never does
  (<https://offpunk.net/offline.html>).
- **There is no cache eviction.** The cache grows forever; prune
  `~/.cache/offpunk` by hand.
- **`archives_size`/`history_size` are caps**, not "keep forever" — raising them to
  500 is cheap insurance if you want a longer recall window.
- The distro 2.2 package fails to start without `python3-lxml-html-clean`; the
  upstream 3.2 tool install avoids that class of risk entirely.

---

## Sources

- Offpunk tutorial: <https://offpunk.net/index.html>, `/whatisoffpunk.html`,
  `/install.html`, `/firststeps.html`, `/tour.html`, `/gemini.html`, `/view.html`,
  `/open.html`, `/offline.html`, `/sync.html`, `/bookmarks.html`, `/lists.html`,
  `/subscriptions.html`, `/frozen.html`, `/help.html`, `/workflow_ploum.html`
- Canonical repo (read at `b69a5e81`, v3.2): <https://git.sr.ht/~lioploum/offpunk> —
  `offpunk.py`, `offutils.py`, `netcache.py`, `openk.py`, `offthemes.py`,
  `offblocklist.py`, `unmerdify.py`, `README.md`, `CHANGELOG`, `man/offpunk.1`,
  `pyproject.toml`, `requirements.txt`, `ubuntu_dependencies.txt`
- Release notes: <https://ploum.net/2026-02-09-offpunk3.html> (3.0),
  <https://ploum.net/2023-11-25-offpunk2.html>
- Package metadata on this machine: `apt-cache policy offpunk`, `dpkg -L offpunk`,
  `/var/log/apt/history.log`, `uv tool list`, the tool venv's `offpunk-3.2.dist-info/METADATA`
- Behaviour verified by executing upstream 3.2 in scratch `HOME`s: rc-file pickup,
  `--sync` rc filtering, list file format, cache layout, `--command` semantics,
  live HTML fetch (`offpunk.net/index.html`), live Gemini fetch
  (`gemini://offpunk.net/`), live RSS parse (`https://ploum.net/feed/`), and
  inline PNG rendering through `chafa` (local HTTP server, `/tmp/test-img.png`).
- The `--features` no-output bug was read directly in
  `offpunk.py:2545-2548` together with `do_version`'s `print_color` parameter.
