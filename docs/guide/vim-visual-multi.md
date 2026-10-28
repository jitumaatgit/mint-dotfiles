# vim-visual-multi — multiple cursors

Plugin: `mg979/vim-visual-multi` (lazy, default mappings on). Leader for VM commands
is `\\` (two backslashes = `\` key). Docs: `:help visual-multi`, `:help vm-mappings`.

Configuration: `home/.config/nvim/lua/plugins/visual-multi.lua` (`VM_leader = "\\"`,
default mappings enabled — `VM_maps` left unset so defaults apply).

## The one workflow to remember

1. Put the cursor on a word.
2. `<C-n>` — selects it and enters VM mode (one cursor/region).
3. `<C-n>` again — selects the next occurrence and adds a cursor.
4. `<C-x>` (Skip Region) — skip an occurrence you don't want.
5. Type — edits all regions at once. `<Esc>` exits VM.

That is 80% of daily use: `<C-n>` to select, repeat to add, type to edit.

## Adding cursors without searching

| Keys | Action |
|---|---|
| `<C-Down>` / `<C-Up>` | Add cursor on the line below / above |
| `<C-LeftMouse>` | Add a cursor where you click |
| `\\` + `\` (Add Cursor At Pos) | Add a single cursor at current position |
| `\\c` (Visual Cursors) | Turn a visual selection into one cursor per line |

## Selecting all occurrences

| Keys | Action |
|---|---|
| `\\A` | Select all occurrences of the word under cursor |
| `\\A` (visual) | Select all occurrences of the visual selection |
| `\\f` / `/` | Find all occurrences matching a pattern |

## Navigating between regions (buffer mode)

Once in VM, these work on the selected regions:

| Keys | Action |
|---|---|
| `n` / `N` | Find next / previous occurrence |
| `]` / `[` | Go to next / previous region |
| `<C-f>` / `<C-b>` | Seek next / previous (fast, page-wise) |
| `q` | Skip the region under cursor |
| `Q` | Remove the region under cursor |

## Editing in VM

| Keys | Action |
|---|---|
| `R` | Replace in all regions (or start replace mode) |
| `s` (Select Operator) | Select with a motion/operator |
| `m` (Find Operator) | Find with a motion/operator |
| `<Tab>` / `<S-Tab>` | Move to next / previous cursor (insert mode) |
| `M` | Toggle multiline mode |
| `S` | Surround (requires vim-surround) |

## Transforms and alignment

| Keys | Action |
|---|---|
| `\\t` | Transpose regions |
| `\\a` | Align regions |
| `\\<` | Align by character |
| `\\>` | Align by regex |
| `\\s` | Split regions by pattern |
| `\\f` | Filter regions by pattern/expression |
| `\\e` | Transform regions with expression |
| `\\m` | Merge overlapping regions |
| `\\d` | Duplicate regions |
| `\\-` / `\\+` | Shrink / enlarge regions |
| `\\L` | Keep at most one region per line |
| `\\n` / `\\N` | Number / number-append regions |

## Numbers

| Keys | Action |
|---|---|
| `<C-A>` / `<C-X>` | Increase / decrease numbers (vim default) |
| `g<C-A>` / `g<C-X>` | Progressive increase / decrease |
| `\\<C-A>` / `\\<C-X>` | Alpha increase / decrease |

## Exiting

| Keys | Action |
|---|---|
| `<Esc>` | Quit VM (also exits insert) |

## Tips

- VM leader is `\` (backslash). Press `\` then the letter; do not hold.
- `<C-n>` selects the **word** under cursor with word boundaries; in visual mode
  `<C-n>` selects the **subword** without boundaries.
- If a mapping conflicts with your terminal or tmux, override it in
  `VM_maps` in `visual-multi.lua`, e.g. `["Find Under"] = "<C-d>"`.
- Run `:VMDebug` (or `:help vm-faq`) for troubleshooting.

## Verify

```sh
nvim --headless -u home/.config/nvim/init.lua -c "qa!"   # config loads
# then in nvim: open any file, put cursor on a word, press <C-n>
```