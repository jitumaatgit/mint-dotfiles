return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    opts = {
      flavour = "mocha",
      custom_highlights = function(colors)
        return {
          -- Callout backgrounds (darker Surface 0) with brighter, bolder accent text
          RenderMarkdownInfo = { bg = colors.surface0, fg = colors.blue, bold = true },
          RenderMarkdownWarn = { bg = colors.surface0, fg = colors.yellow, bold = true },
          RenderMarkdownError = { bg = colors.surface0, fg = colors.red, bold = true },
          RenderMarkdownSuccess = { bg = colors.surface0, fg = colors.green, bold = true },
          RenderMarkdownHint = { bg = colors.surface0, fg = colors.teal, bold = true },
          RenderMarkdownQuote = { bg = colors.surface0, fg = colors.mauve, bold = true },
          -- Quote line backgrounds for callout content and blockquotes (darker)
          RenderMarkdownQuote1 = { bg = colors.surface0 },
          RenderMarkdownQuote2 = { bg = colors.surface0 },
          RenderMarkdownQuote3 = { bg = colors.surface0 },
          RenderMarkdownQuote4 = { bg = colors.surface0 },
          RenderMarkdownQuote5 = { bg = colors.surface0 },
          RenderMarkdownQuote6 = { bg = colors.surface0 },
           Folded = { bg = 'NONE', fg = colors.lavender },
           FoldColumn = { bg = 'NONE', fg = colors.lavender },
        }
      end,
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin-mocha",
    },
  },
}
