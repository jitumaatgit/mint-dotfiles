return {
  {
    "hrsh7th/nvim-cmp",
    enabled = true,
    lazy = false,
    priority = 100,
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "saadparwaiz1/cmp_luasnip",
      "L3MON4D3/LuaSnip",
      "onsails/lspkind.nvim",
    },
    opts = function()
      local cmp = require("cmp")
      local lspkind = require("lspkind")

      return {
        completion = {
          completeopt = "menu,menuone,noinsert",
        },
        snippet = {
          expand = function(args)
            require("luasnip").lsp_expand(args.body)
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-L>"] = cmp.mapping.confirm({ select = true }),
          ["<C-E>"] = cmp.mapping.abort(),
          ["<C-Y>"] = cmp.mapping.complete(),
          ["<C-J>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<C-K>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            else
              fallback()
            end
          end, { "i", "s" }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "luasnip" },
          { name = "path" },
          { name = "obsidian" },
          { name = "buffer" },
        }),
        formatting = {
          format = lspkind.cmp_format({
            mode = "symbol_text",
            maxwidth = 50,
            ellipsis_char = "...",
          }),
        },
        preselect = cmp.PreselectMode.Item,
      }
    end,
  },

  -- Octo (imports extras.lang.git for issue/PR highlighting + cmp-git source).
  -- Imported here, AFTER the nvim-cmp spec above, on purpose: the git extra's
  -- nvim-cmp hook does `table.insert(opts.sources, ...)` and lazy.nvim runs
  -- spec fragments oldest-first, so our `sources` must already exist when that
  -- hook runs. Enabling octo via lazyvim.json instead makes it import before
  -- this file and crashes startup at extras/lang/git.lua.
  { import = "lazyvim.plugins.extras.util.octo" },
}
