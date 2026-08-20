-- Custom null-ls source for luacheck.
-- none-ls (the maintained null-ls fork) dropped its luacheck builtin,
-- so we define it here using the plain formatter with ranges.
local h = require("null-ls.helpers")
local methods = require("null-ls.methods")
local u = require("null-ls.utils")

local DIAGNOSTICS = methods.internal.DIAGNOSTICS

return h.make_builtin({
  name = "luacheck",
  meta = {
    url = "https://github.com/lunarmodules/luacheck",
    description = "A static analyzer and linter for Lua.",
  },
  method = DIAGNOSTICS,
  filetypes = { "lua" },
  generator_opts = {
    command = "luacheck",
    args = { "--formatter", "plain", "--codes", "--ranges", "--filename", "$FILENAME", "-" },
    to_stdin = true,
    format = "line",
    check_exit_code = function(code)
      return code <= 2 -- 0 = clean, 1 = warnings, 2 = errors
    end,
    on_output = h.diagnostics.from_pattern(
      -- e.g. stdin:1:7-16: (W211) unused variable 'x'
      [[:(%d+):(%d+)-(%d+): %((%a)(%d+)%) (.+)]],
      { "row", "col", "end_col", "severity", "code", "message" },
      {
        severities = {
          E = h.diagnostics.severities["error"],
          W = h.diagnostics.severities["warning"],
          _fallback = h.diagnostics.severities["warning"],
        },
      }
    ),
    cwd = h.cache.by_bufnr(function(params)
      return u.root_pattern(".luacheckrc")(params.bufname)
    end),
  },
  factory = h.generator_factory,
})