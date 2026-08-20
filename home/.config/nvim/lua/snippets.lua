local ls = require("luasnip")
local s = ls.snippet
local f = ls.function_node
local d = ls.dynamic_node
local i = ls.insert_node
local t = ls.text_node
local sn = ls.snippet_node

-- Cloze snippet for anki.nvim: type CT to expand {{c1::|}}, auto-increments to c2, c3...
-- vim.g.anki_cloze tracks the current cloze number, resets when you start a new card
local function cloze_same_line(_, _, _, _)
  local a = vim.g.anki_cloze or 1
  local t0 = t({ "{{c" .. a .. "::" })
  local t1 = i(1)
  local t2 = t({ "}}" })
  local t3 = i(0)
  vim.g.anki_cloze = a + 1
  return sn(nil, { t0, t1, t2, t3 })
end

ls.add_snippets("all", {
  s("date", {
    f(function() return { os.date("%Y-%m-%d") } end),
  }),
  s("time", {
    f(function() return { os.date("%H:%M") } end),
  }),
  s("datetime", {
    f(function() return { os.date("%Y-%m-%d %H:%M") } end),
  }),
})

-- Cloze snippets: only active in anki filetype (.anki files)
ls.add_snippets("anki", {
  s("CT", {
    d(1, cloze_same_line, {}, {}),
  }),
})
