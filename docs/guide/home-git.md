# home-git — versioning the whole home directory

A local-only git repository that tracks `$HOME`, so agent-made file changes can be
diffed and restored.

## Layout

| What | Where |
|---|---|
| Object store (bare) | `/home/mint/.home-git` |
| Work tree | `/home/mint` (the whole home dir) |
| Ignore rules | `/home/mint/.config/home-git/ignore` |
| 10MB + gitlink guards | `/home/mint/.home-git/hooks/pre-commit` |
| Commands | `/home/mint/.local/bin/{hgit,hsnap,hrestore}` |

There is no `.git` directory in `$HOME`, so plain `git` anywhere in the home tree
still reports "not a git repository" and nested repos (`mint-dotfiles`, `notes`,
`projects/*`) resolve to their own `.git`. Only the three commands above touch
home-git.

## Commands

```sh
hsnap                      # snapshot: default message "snapshot <timestamp>"
hsnap "before refactor"    # snapshot with a message
hsnap                      # on a clean tree: "nothing to snapshot", no commit

hrestore                   # list the 20 most recent snapshots
hrestore -- .zshrc         # restore one path from the latest snapshot
hrestore HEAD~3 -- .zshrc  # restore one path from an older snapshot
hrestore HEAD~3            # restore ALL tracked files (prompts; shows delete count)
hrestore HEAD~3 --yes      # same, no prompt
hrestore .zshrc            # a bare path is treated as a path, not a revision

hgit status                # any git command against the home repo
hgit log --oneline
hgit diff <rev> -- .config
```

Paths are always relative to `$HOME`, whatever the current directory.

## What is tracked

Roughly 520 files, ~38MB of object store. Tracked: dotfiles, `.config` (minus
browsers), `.agents/skills`, omp config/skills/extensions, `.local/bin` scripts,
`.ssh`, `.npmrc`, fcm-router config and token files, `Downloads` (minus large
binaries), `Documents`.

Deliberately excluded (see the ignore file for the full list):

- **Nested repos** — `mint-dotfiles`, `notes`, `projects`, `pso`, `other-dotfiles`,
  `nixarch-dotfiles`, `~/.nvm`, `~/.oh-my-zsh`, `.config/tmux/plugins`. They keep
  their own history; they are never submodules.
- **Vendored/bulk state** — `.steam`, `.var`, `.bun`, `.rustup`, `.cargo`, `.npm`,
  `.cache`, `.local/share`, `.local/opt`, `.opencode/bin`, `.omp/{cache,natives,wt,logs}`,
  `.omp/plugins/node_modules`, `.omp/agent/{sessions,memories,blobs,*.db}`.
- **Vendored tool binaries in `.local/bin`** — terraform, ntfy, uv, yazi, lazygit, yq, starship.
- **Logs and scratch** — `*.log`, `.xsession-errors`, `.wget-hsts`, `.Xauthority`,
  `.steampid`, `.z`, `.z.lock`, `.zsh_history`, `.zcompdump*`, fcm telemetry.
- **Secrets are NOT excluded** — this is deliberate and local-only. `.ssh/`,
  `.npmrc`, `.dmrc`, fcm tokens and `*.env` are tracked so they can be restored.

## Two guards in the pre-commit hook

1. **10MB limit.** Any staged blob over 10MB is dropped from the commit; the file
   stays on disk. Already-tracked files are *reset* rather than removed, so a file
   that grows past the limit is not recorded as a deletion. The commit still
   succeeds — the guard reports and continues.
2. **No gitlinks.** A staged embedded repo (mode 160000) is refused, so a nested
   repo cannot become a submodule.

Both print to stderr and suggest adding an ignore rule.

## Maintenance

**Nothing recurring.** There is no timer, no daemon and no service. `hsnap` is the
whole workflow, and it is a no-op when the tree is clean. A 2-minute idle sample
left the tree at 0 changes, so both guards stay quiet until something actually
moves.

Git's own housekeeping (`gc`, packing loose objects) runs automatically under
git's default `gc.auto`. Snapshots are cheap: git stores only changed blobs, so
re-snapshotting an unchanged tree costs almost nothing.

### Occasional, all reactive

| Situation | What to do |
|---|---|
| A snapshot warns about a >10MB file | Add the path to `~/.config/home-git/ignore`, then `hgit rm --cached -- <path>`. The rule alone will not untrack a file that is already tracked. |
| The hook refuses an embedded repo | Add that directory to the ignore file. It keeps its own history. |
| A nested repo appears somewhere new | Same, before the hook complains on the next snapshot. |
| Disk pressure | `hgit gc --aggressive` reclaims packs. `/` was at 89% with 27G free. |
| History wanted off this machine | `git --git-dir=/home/mint/.home-git bundle create backup.bundle --all` — the repo has no remote by design. |

### Deliberate permanent noise

`.free-coding-models.json` and `.free-coding-models.backups/` change on their own
because the fcm daemon rewrites them. A snapshot taken after the daemon has
touched them will include them. Expected, not a fault.

### What home-git does not cover

Nothing inside `mint-dotfiles`, `notes`, `projects`, `pso`, `other-dotfiles` or
`nixarch-dotfiles` — those are separate repositories with their own remotes and
history, and they snapshot with their own tooling. Ignored directories are not
versioned either, so a restore cannot recover a deleted `~/.cache` or `~/.steam`
file.

## Caveats

- **A full restore rewrites these scripts.** `hrestore`, `hsnap` and the hook are
  tracked files inside the tree they operate on, so `hrestore <old-rev> --yes`
  reverts the tooling too. Restore to a recent revision, or restore paths
  individually.
- **Restoring a path to a revision that predates it deletes the file.** That is
  what the revision says. `hrestore` lists such paths and asks first; `--yes`
  skips the prompt.
- Do not `export GIT_DIR`/`GIT_WORK_TREE` in a shell you then run other git
  commands in — incidental `git add -A` in an unrelated directory then lands in
  the home repo. The scripts set both internally and only for their own process.

## Verification

```sh
hgit log --oneline | head                     # history
hgit ls-files | wc -l                         # ~520
hgit ls-files -s | awk '$1=="160000"' | wc -l # must print 0
hsnap                                         # clean tree -> "nothing to snapshot"
hgit status --porcelain | wc -l               # 0 when clean
```

## Follow-ups

- All API keys in this repo should be rotated: the user accepted tracking them
  deliberately, on the basis that they are free-tier keys (except opencode-go)
  and would be rotated once the setup was done.
- `.config/gh/hosts.yml` and `.android/adbkey` are tracked but were not part of
  the original decision. Exclude them if that was not intended.
