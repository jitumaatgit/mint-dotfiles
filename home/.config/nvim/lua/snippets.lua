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

-- Markdown exponent superscript snippets: ^<num> → Unicode superscript
local superscripts = {
  ["0"] = "⁰", ["1"] = "¹", ["2"] = "²", ["3"] = "³", ["4"] = "⁴",
  ["5"] = "⁵", ["6"] = "⁶", ["7"] = "⁷", ["8"] = "⁸", ["9"] = "⁹",
  ["+"] = "⁺", ["-"] = "⁻", ["="] = "⁼", ["("] = "⁽", [")"] = "⁾",
  ["a"] = "ᵃ", ["b"] = "ᵇ", ["c"] = "ᶜ", ["d"] = "ᵈ", ["e"] = "ᵉ",
  ["f"] = "ᶠ", ["g"] = "ᵍ", ["h"] = "ʰ", ["i"] = "ⁱ", ["j"] = "ʲ",
  ["k"] = "ᵏ", ["l"] = "ˡ", ["m"] = "ᵐ", ["n"] = "ⁿ", ["o"] = "ᵒ",
  ["p"] = "ᵖ", ["r"] = "ʳ", ["s"] = "ˢ", ["t"] = "ᵗ", ["u"] = "ᵘ",
  ["v"] = "ᵛ", ["w"] = "ʷ", ["x"] = "ˣ", ["y"] = "ʸ", ["z"] = "ᶻ",
  ["A"] = "ᴬ", ["B"] = "ᴮ", ["D"] = "ᴰ", ["E"] = "ᴱ", ["G"] = "ᴳ",
  ["H"] = "ᴴ", ["I"] = "ᴵ", ["J"] = "ᴶ", ["K"] = "ᴷ", ["L"] = "ᴸ",
  ["M"] = "ᴹ", ["N"] = "ᴺ", ["O"] = "ᴼ", ["P"] = "ᴾ", ["R"] = "ᴿ",
  ["T"] = "ᵀ", ["U"] = "ᵁ", ["V"] = "ⱽ", ["W"] = "ᵂ",
}
local exp_snippets = {}
for char, sup in pairs(superscripts) do
  exp_snippets[#exp_snippets + 1] = s("^" .. char, {
    t({ sup }),
    i(0),
  })
end

-- Markdown table snippets
local md_snippets = vim.list_extend({
  s("t2", {
    t({ "| ${1:Header} | ${2:Header} |" }),
    t({ "", "|--------|--------|" }),
    t({ "", "| ${3:cell} | ${4:cell} |" }),
    i(0),
  }),
  s("t3", {
    t({ "| ${1:Header} | ${2:Header} | ${3:Header} |" }),
    t({ "", "|--------|--------|--------|" }),
    t({ "", "| ${4:cell} | ${5:cell} | ${6:cell} |" }),
    i(0),
  }),
  s("t4", {
    t({ "| ${1:Header} | ${2:Header} | ${3:Header} | ${4:Header} |" }),
    t({ "", "|--------|--------|--------|--------|" }),
    t({ "", "| ${5:cell} | ${6:cell} | ${7:cell} | ${8:cell} |" }),
    i(0),
  }),
}, exp_snippets)
ls.add_snippets("markdown", md_snippets)

-- Cloze snippets: only active in anki filetype (.anki files)
ls.add_snippets("anki", {
  s("CT", {
    d(1, cloze_same_line, {}, {}),
  }),
})
