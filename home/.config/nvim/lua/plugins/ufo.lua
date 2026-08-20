return {
  "kevinhwang91/nvim-ufo",
  dependencies = {
    "kevinhwang91/promise-async",
  },
  event = "VeryLazy",
  opts = {
    -- Provider: treesitter for most, custom foldexpr for markdown
    provider_selector = function(bufnr, filetype, buftype)
      if filetype == "markdown" then
        return "" -- Use custom foldexpr, UFO won't manage
      end
      return { "treesitter", "indent" }
    end,

    -- Custom fold text with line count
    fold_virt_text_handler = function(virtText, lnum, endLnum, width, truncate)
      local newVirtText = {}
      local suffix = (" 󰁂 %d "):format(endLnum - lnum)
      local sufWidth = vim.fn.strdisplaywidth(suffix)
      local targetWidth = width - sufWidth
      local curWidth = 0

      for _, chunk in ipairs(virtText) do
        local chunkText = chunk[1]
        local chunkWidth = vim.fn.strdisplaywidth(chunkText)
        if targetWidth > curWidth + chunkWidth then
          table.insert(newVirtText, chunk)
        else
          chunkText = truncate(chunkText, targetWidth - curWidth)
          local hlGroup = chunk[2]
          table.insert(newVirtText, { chunkText, hlGroup })
          chunkWidth = vim.fn.strdisplaywidth(chunkText)
          if curWidth + chunkWidth < targetWidth then
            suffix = suffix .. (" "):rep(targetWidth - curWidth - chunkWidth)
          end
          break
        end
        curWidth = curWidth + chunkWidth
      end

      table.insert(newVirtText, { suffix, "MoreMsg" })
      return newVirtText
    end,

    -- Preview window config (preview/peek is 'K' in normal mode)
    preview = {
      win_config = {
        border = "rounded",
        winhighlight = "Normal:Folded",
        winblend = 0,
      },
      mappings = {
        scrollU = "<C-u>",
        scrollD = "<C-d>",
      },
    },
  },
  config = function(_, opts)
    require("ufo").setup(opts)

    -- Auto-attach UFO to all existing and new buffers
    local function attach_ufo()
      local bufnr = vim.api.nvim_get_current_buf()
      local ok, err = pcall(function()
        require("ufo").attach(bufnr)
      end)
      if not ok then
        -- Silently ignore if UFO can't attach (e.g., markdown with custom foldexpr)
      end
    end

    -- Attach to current buffer
    attach_ufo()

    -- Attach to future buffers
    vim.api.nvim_create_autocmd("BufReadPost", {
      callback = attach_ufo,
    })
  end,
}
