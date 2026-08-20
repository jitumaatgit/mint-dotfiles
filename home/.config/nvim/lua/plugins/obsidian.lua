return {
  "epwalsh/obsidian.nvim",
  version = "*",
  lazy = true,
  ft = "markdown",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "hrsh7th/nvim-cmp",
  },
  opts = {
    footer = {
      enabled = true,
      separator = false,
      format = "({{backlinks}} backlinks)", -- limit to backlinks
    },
    workspaces = {
      {
        name = "notes",
        path = vim.fn.expand("~/notes"),
      },
    },
    notes_subdir = "",
    daily_notes = {
      folder = "docs/30-dailynotes",
      date_format = "%Y/%m/%Y-%m-%d",
      alias_format = "%B %-d, %Y",
      default_tags = { "daily-notes" },
      template = "docs/50-templates/dailynote-template.md",
    },
    completion = {
      nvim_cmp = true,
      min_chars = 2,
    },
    mappings = {
      ["gf"] = {
        action = function()
          return require("obsidian.util").gf_passthrough()
        end,
        opts = { desc = "Follow link", noremap = false, expr = true, buffer = true },
      },
      -- Note: daily note keybindings defined globally in keys table so they can be used from dashboard
    },
    new_notes_location = "current_dir",
    note_id_func = function(title)
      if title ~= nil then
        return title:gsub(" ", "-"):gsub("[^A-Za-z0-9-]", ""):lower()
      else
        local suffix = ""
        for _ = 1, 4 do
          suffix = suffix .. string.char(math.random(65, 90))
        end
        return suffix
      end
    end,
    wiki_link_func = "use_alias_only", -- confirmed working; `wiki_link_path_prefix` causes broken links
    -- wiki_link_func = function(opts)
    --   return require("obsidian.util").wiki_link_path_prefix(opts)
    -- end, -- kept for reference: this alternative caused broken wiki-links in practice
    preferred_link_style = "wiki",
    templates = {
      folder = "docs/50-templates",
      date_format = "%Y-%m-%d",
      time_format = "%H:%M",
      substitutions = {},
    },
    follow_url_func = function(url)
      vim.fn.jobstart({ "xdg-open", url }, { detach = true })
    end,
    picker = {
      name = "telescope.nvim",
      note_mappings = {
        new = "<C-x>",
        insert_link = "<C-l>",
      },
      tag_mappings = {
        tag_note = "<C-x>",
        insert_tag = "<C-l>",
      },
    },
    sort_by = "modified",
    sort_reversed = true,
    open_notes_in = "current",
    attachments = {
      img_folder = "assets/imgs",
      img_name_func = function()
        return string.format("%s-", os.time())
      end,
      img_text_func = function(client, path)
        path = client:vault_relative_path(path) or path
        return string.format("![%s](%s)", path.name, path)
      end,
    },
    -- Disable obsidian UI (using render-markdown.nvim instead)
    ui = { enable = false },
    -- Disable frontmatter for files in the tasks folder or kanban files to avoid conflicts with kanban.nvim
    disable_frontmatter = function(filename)
      return filename:match("[\\/]tasks[\\/]") or filename:match("^tasks[\\/]") or filename:match("kanban%.md$") or filename:match("[\\/]prompts[\\/]") or filename:match("^prompts[\\/]")
    end,
  },
  keys = {
    { "<leader>nr", "<cmd>ObsidianRename<cr>", desc = "Rename note" },
    { "<leader>nn", "<cmd>ObsidianNew<cr>", desc = "New note" },
    { "<leader>nt", "<cmd>ObsidianToday<cr>", desc = "Open today's daily note" },
    { "<leader>ny", "<cmd>ObsidianToday -1<cr>", desc = "Open yesterday's note" },
    { "<leader>nu", "<cmd>ObsidianToday 1<cr>", desc = "Open tomorrow's note" },
    { "<leader>nw", "<cmd>ObsidianWeekly<cr>", desc = "Open weekly note" },
    { "<leader>ns", "<cmd>ObsidianSearch<cr>", desc = "Search notes" },
    { "<leader>nb", "<cmd>ObsidianBacklinks<cr>", desc = "Show backlinks" },
    { "<leader>nl", "<cmd>ObsidianLinks<cr>", desc = "Show outgoing links" },
    { "<leader>ni", "<cmd>ObsidianPasteImg<cr>", desc = "Paste image" },
    { "<leader>nc", "<cmd>ObsidianToggleCheckbox<cr>", desc = "Toggle checkbox" },
    { "<leader>ne", "<cmd>ObsidianExtractNote<cr>", desc = "Extract note from selection", mode = "v" },
  },
  config = function(_, opts)
    require("obsidian").setup(opts)
  require("custom.weekly-note")
  vim.api.nvim_create_user_command("ObsidianFollowLink", function(data)
    if require("custom.weekly-note").follow_weekly_link() then
      return
    end
    local client = require("obsidian").get_client()
    local opts = {}
    if data.args and string.len(data.args) > 0 then
      opts.open_strategy = data.args
    end
    client:follow_link_async(nil, opts)
  end, { nargs = "?", desc = "Follow link (with weekly note support)" })
  vim.api.nvim_create_autocmd("FileType", {
      pattern = "markdown",
      callback = function(ev)
        vim.keymap.set("n", "<CR>", function()
          local ok, actions = pcall(require, "obsidian.actions")
          if ok then
            actions.smart_action()
          else
            -- Fallback: try manual fold toggle
            local line = vim.api.nvim_win_get_cursor(0)[1]
            local foldlevel = vim.fn.foldlevel(line)
            if foldlevel > 0 then
              vim.cmd("normal! za")
            else
              -- Normal Enter behavior
              vim.cmd("normal! j")
            end
          end
        end, {
          buffer = true,
          desc = "Obsidian smart action or toggle fold",
        })
      end,
    })
    vim.api.nvim_create_user_command("ObsidianExtractNote", function(data)
      local client = require("obsidian").get_client()
      local util = require("obsidian.util")
      local log = require("obsidian.log")

      local viz = util.get_visual_selection()
      if not viz then
        log.err("ObsidianExtractNote must be called with visual selection")
        return
      end

      local content = vim.split(viz.selection, "\n", { plain = true })

      local title
      if data.args and string.len(data.args) > 0 then
        title = util.strip_whitespace(data.args)
      else
        title = util.input("Enter title (optional): ")
        if not title then
          log.warn("Aborted")
          return
        elseif title == "" then
          title = nil
        end
      end

      local orig_buf = vim.api.nvim_get_current_buf()
      local orig_win = vim.api.nvim_get_current_win()

      local note = client:create_note({ title = title })
      local link = client:format_link(note)

      if vim.api.nvim_get_current_buf() ~= orig_buf then
        vim.api.nvim_win_set_buf(orig_win, orig_buf)
      end

      local lines = vim.api.nvim_buf_get_lines(orig_buf, viz.csrow - 1, viz.cerow, false)
      if #lines == 0 then
        log.err("Failed to get lines for extraction")
        return
      end

      local cscol_byte = math.max(1, math.min(viz.cscol, #lines[1] + 1))
      local cecol_byte = math.max(1, math.min(viz.cecol, #lines[#lines] + 1))

      local new_lines
      if #lines == 1 then
        new_lines = { lines[1]:sub(1, cscol_byte - 1) .. link .. lines[1]:sub(cecol_byte + 1) }
      else
        new_lines = {
          lines[1]:sub(1, cscol_byte - 1) .. link,
          lines[#lines]:sub(cecol_byte + 1),
        }
      end

      vim.api.nvim_buf_set_lines(orig_buf, viz.csrow - 1, viz.cerow, false, new_lines)
      client:update_ui(orig_buf)

      client:open_note(note, { sync = true })
      vim.api.nvim_buf_set_lines(0, -1, -1, false, content)
    end, { nargs = "?", range = true, desc = "Extract selected text into a new note" })
  end,
}
