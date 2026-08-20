## Non-obvious Learnings

### Expression mappings: user count prepends to returned string

In Neovim `expr` mappings, the count typed by the user is NOT consumed by the expression — it **prepends** to whatever string the expression returns. If the expression also embeds a count, they combine (e.g., `2j` → expression returns `"2j"` → counts stack to `"22j"`). Fix: return bare motion keys (no embedded count) unless you intentionally need to consume the original count.

### `m'` consumes the pending count in a returned key sequence

When `m'` appears in an expression-returned key string, it **consumes** the pending count (marks don't use counts, but the count is still consumed by the first command in the sequence). Pattern for `j`/`k` with jumplist `m'`:
- Count < 3: return `'j'` — original count applies naturally to `j`
- Count >= 3: return `"m'" . v:count . 'j'` — `m'` absorbs original count, then explicit count feeds `j`

### `vim.cmd("normal!")` forbidden in expression mappings

Calling `vim.cmd("normal!")` from within an `expr` mapping callback throws `E523: Not allowed here`. Use key strings in the return value instead of `:normal!` side effects.
