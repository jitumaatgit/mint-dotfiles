-- Parse query once outside function for performance
local callout_query = vim.treesitter.query.parse(
  "markdown",
  [[
  (block_quote
    (paragraph) @callout_header
    (#match? @callout_header "^\\[!\\w+\\]"))
]]
)

-- Map callout types to highlight groups
local callout_highlights = {
  note = "RenderMarkdownInfo",
  tip = "RenderMarkdownSuccess",
  important = "RenderMarkdownHint",
  warning = "RenderMarkdownWarn",
  caution = "RenderMarkdownError",
  abstract = "RenderMarkdownInfo",
  info = "RenderMarkdownInfo",
  todo = "RenderMarkdownInfo",
  success = "RenderMarkdownSuccess",
  question = "RenderMarkdownHint",
  failure = "RenderMarkdownError",
  danger = "RenderMarkdownError",
  bug = "RenderMarkdownError",
  example = "RenderMarkdownHint",
  quote = "RenderMarkdownQuote",
}

-- Extract callout type from header text
local function get_callout_type(text)
  local callout_type = text:match("%[!(%w+)%]")
  if callout_type then
    return callout_type:lower()
  end
  return nil
end

-- Main parse function for custom callout backgrounds
local function parse_callout_backgrounds(ctx)
  local marks = {}
  local buf = ctx.buf
  local root = ctx.root

  for _, node in callout_query:iter_captures(root, buf) do
    -- Get the header text to determine callout type
    local header_text = vim.treesitter.get_node_text(node, buf)
    local callout_type = get_callout_type(header_text)
    local highlight_group = callout_type and callout_highlights[callout_type] or "RenderMarkdownQuote"

    -- Get the parent block_quote to find all lines
    local block_quote = node:parent()
    if block_quote and block_quote:type() == "block_quote" then
      local quote_start_row, _, quote_end_row, _ = block_quote:range()

      -- Add background to all lines in the callout (starting from line 2)
      for row = quote_start_row + 1, quote_end_row - 1 do
        -- Get the line text to calculate width
        local line_text = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""
        -- Calculate visual width (handles unicode, tabs, etc.)
        local text_width = vim.fn.strdisplaywidth(line_text)

        -- Background highlight mark - limited to text width (like code blocks)
        if text_width > 0 then
          marks[#marks + 1] = {
            conceal = false,
            start_row = row,
            start_col = 0,
            opts = {
              end_row = row,
              end_col = text_width, -- Stop at text width instead of hl_eol
              hl_group = highlight_group,
            },
          }

          -- Border character mark (█)
          marks[#marks + 1] = {
            conceal = false,
            start_row = row,
            start_col = 0,
            opts = {
              virt_text = { { "█", highlight_group } },
              virt_text_pos = "overlay",
            },
          }
        end
      end
    end
  end

  return marks
end

return {
  "MeanderingProgrammer/render-markdown.nvim",
  -- dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-mini/mini.nvim' },            -- if you use the mini.nvim suite
  dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-mini/mini.icons" }, -- if you use standalone mini plugins
  -- dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' }, -- if you prefer nvim-web-devicons
  ---@module 'render-markdown'
  ---@type render.md.UserConfig
  opts = {
    bullet = {
      -- Turn on / off list bullet rendering
      enabled = true,
    },
    checkbox = {
      -- Turn on / off checkbox state rendering
      enabled = true,
      -- Determines how icons fill the available space:
      --  inline:  underlying text is concealed resulting in a left aligned icon
      --  overlay: result is left padded with spaces to hide any additional text
      position = "inline",
      unchecked = {
        -- Replaces '[ ]' of 'task_list_marker_unchecked'
        icon = "   󰄱 ",
        -- Highlight for the unchecked icon
        highlight = "RenderMarkdownUnchecked",
        -- Highlight for item associated with unchecked checkbox
        scope_highlight = nil,
      },
      checked = {
        -- Replaces '[x]' of 'task_list_marker_checked'
        icon = "   󰱒 ",
        -- Highlight for the checked icon
        highlight = "RenderMarkdownChecked",
        -- Highlight for item associated with checked checkbox
        scope_highlight = "@markup.strikethrough",
      },
      custom = {
        todo = {
          raw = "[-]",
          rendered = "   󰜺 ",
          highlight = "DiagnosticError",
        },
        in_progress = {
          raw = "[/]",
          rendered = "   󰍟 ",
          highlight = "DiagnosticWarn",
        },
      },
    },
    html = {
      -- Turn on / off all HTML rendering
      enabled = true,
      comment = {
        -- Turn on / off HTML comment concealing
        conceal = false,
      },
    },
    -- Add custom icons lamw26wmal
    -- link = {
    --   image = vim.g.neovim_mode == "skitty" and "" or "󰥶 ",
    --   custom = {
    --     youtu = { pattern = "youtu%.be", icon = "󰗃 " },
    --   },
    -- },
    heading = {
      sign = false,
      icons = { "󰎤 ", "󰎧 ", "󰎪 ", "󰎭 ", "󰎱 ", "󰎳 " },
      -- Backgrounds/foregrounds removed - using treesitter @markup.heading groups instead
      -- This allows folds to preserve heading colors when foldtext=""
    },
    quote = {
      -- Thick block character for left border on callouts
      icon = "█",
      -- Background colors for quote lines (all 6 nesting levels)
      highlight = {
        "RenderMarkdownQuote1",
        "RenderMarkdownQuote2",
        "RenderMarkdownQuote3",
        "RenderMarkdownQuote4",
        "RenderMarkdownQuote5",
        "RenderMarkdownQuote6",
      },
    },
    callout = {
      -- GitHub callouts
      note = { quote_icon = "█", highlight = "RenderMarkdownInfo" },
      tip = { quote_icon = "█", highlight = "RenderMarkdownSuccess" },
      important = { quote_icon = "█", highlight = "RenderMarkdownHint" },
      warning = { quote_icon = "█", highlight = "RenderMarkdownWarn" },
      caution = { quote_icon = "█", highlight = "RenderMarkdownError" },
      -- Obsidian callouts
      abstract = { quote_icon = "█", highlight = "RenderMarkdownInfo" },
      info = { quote_icon = "█", highlight = "RenderMarkdownInfo" },
      todo = { quote_icon = "█", highlight = "RenderMarkdownInfo" },
      success = { quote_icon = "█", highlight = "RenderMarkdownSuccess" },
      question = { quote_icon = "█", highlight = "RenderMarkdownHint" },
      failure = { quote_icon = "█", highlight = "RenderMarkdownError" },
      danger = { quote_icon = "█", highlight = "RenderMarkdownError" },
      bug = { quote_icon = "█", highlight = "RenderMarkdownError" },
      example = { quote_icon = "█", highlight = "RenderMarkdownHint" },
      quote = { quote_icon = "█", highlight = "RenderMarkdownQuote" },
    },
    -- Custom handler to add backgrounds and borders to callout content lines
    custom_handlers = {
      markdown = {
        extends = true,
        parse = parse_callout_backgrounds,
      },
    },
  },
}
