return {
  "cameron-wags/rainbow_csv.nvim",
  config = function()
    vim.g.disable_rainbow_hover = 1
    require("rainbow_csv").setup({})
  end,
  ft = {
    "csv",
    "tsv",
    "csv_semicolon",
    "csv_whitespace",
    "csv_pipe",
    "rfc_csv",
    "rfc_semicolon",
  },
  cmd = {
    "RainbowDelim",
    "RainbowDelimSimple",
    "RainbowDelimQuoted",
    "RainbowMultiDelim",
  },
}
