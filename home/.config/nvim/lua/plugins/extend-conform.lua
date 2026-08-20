return {
  "stevearc/conform.nvim",
  optional = true,
  opts = {
    default_format_opts = {
      timeout_ms = 1000,
    },
    formatters = {
      ["markdown-toc"] = {
        condition = function(_, ctx)
          for _, line in ipairs(vim.api.nvim_buf_get_lines(ctx.buf, 0, -1, false)) do
            if line:find("<!%-%- toc %-%->") then
              return true
            end
          end
        end,
      },
      ["markdownlint-cli2"] = {
        args = { "--config", "~/.markdownlint-cli2.jsonc", "--" },
        condition = function(_, ctx)
          local diag = vim.tbl_filter(function(d)
            return d.source == "markdownlint"
          end, vim.diagnostic.get(ctx.buf))
          return #diag > 0
        end,
      },
      ["prettypst"] = {
        prepend_args = { "--use-configuration" },
      },
      ["typstyle"] = {
        prepend_args = { "--wrap-text" },
      },
      ["codeblock_blankline"] = {
        command = "perl",
        args = {
          "-0777",
          "-pe",
          -- Add 1 blank line right after the opening fence, and 1 blank line
          -- right before the closing fence
          [[s/^(\s*```[^\n]*)\n(?!\n)/$1\n\n/gm; s/(?<!\n)\n(?=^\s*```\s*$)/\n\n/gm;]],
        },
        stdin = true,
      },
      ["codeblock_remove_opening_blank"] = {
        command = "perl",
        args = {
          "-0777",
          "-pe",
          [[
my @lines = split(/\n/, $_, -1);
my $in = 0;
my $drop_next_blank = 0;
my @out;

for my $line (@lines) {
  if (!$in) {
    if ($line =~ /^\s*```/) {
      $in = 1;
      $drop_next_blank = 1;
      push @out, $line;
      next;
    }
    push @out, $line;
    next;
  }

  if ($line =~ /^\s*```\s*$/) {
    # Remove ONE blank line right above the closing fence (only if it exists)
    if (@out && $out[-1] =~ /^\s*$/) {
      pop @out;
    }
    $in = 0;
    $drop_next_blank = 0;
    push @out, $line;
    next;
  }

  # Remove ONE blank line right after the opening fence (only if it exists)
  if ($drop_next_blank && $line =~ /^\s*$/) {
    $drop_next_blank = 0;
    next;
  }

  $drop_next_blank = 0;
  push @out, $line;
}

$_ = join("\n", @out);
]],
        },
        stdin = true,
      },
    },
    formatters_by_ft = {
      -- I was having issues formatting .templ files, all the lines were aligned
      -- to the left.
      -- When I ran :ConformInfo I noticed that 2 formatters showed up:
      -- "LSP: html, templ"
      -- But none showed as `ready` This fixed that issue and now templ files
      -- are formatted correctly and :ConformInfo shows:
      -- "LSP: html, templ"
      -- "templ ready (templ) /Users/linkarzu/.local/share/neobean/mason/bin/templ"
      templ = { "templ" },
      -- Not sure why I couldn't make ruff work, so I'll use ruff_format instead
      -- it didn't work even if I added the pyproject.toml in the project or
      -- root of my dots, I was getting the error [LSP][ruff] timeout
      python = { "ruff_format" },
      -- php = { nil },

      -- sqeeze_blanks is a conform formatter that removes extra blank lines. So
      -- below, first the typstyle formatter is ran, then the sqeeze_blanks one
      --
      -- codeblock_blankline adds a single blank line right after the opening
      -- triple backticks in code blocks (example: ```bash), so the content starts
      -- separated from the fence for better readability
      -- typst = { "typstyle", "squeeze_blanks", "codeblock_blankline", lsp_format = "never" },
      typst = { "typstyle", "squeeze_blanks", "codeblock_remove_opening_blank", lsp_format = "never" },
      -- typst = { "typstyle", lsp_format = "prefer" },
      -- typst = { "prettypst" },

      ["markdown"] = function(bufnr)
        -- Skip formatting for files in tasks folder or kanban files (special characters in filenames break shell commands)
        local filepath = vim.api.nvim_buf_get_name(bufnr)
        if filepath:match("[\\/]tasks[\\/]") or filepath:match("kanban%.md$") then
          return {}
        end
        return { "markdownlint-cli2", "markdown-toc" }
      end,
      ["markdown.mdx"] = { "markdownlint-cli2", "markdown-toc" },
    },
  },
}
