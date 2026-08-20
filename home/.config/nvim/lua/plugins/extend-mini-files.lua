return {
  "nvim-mini/mini.files",
  keys = {
    {
      "<leader>e",
      function()
        require("mini.files").open(vim.api.nvim_buf_get_name(0), true)
      end,
      desc = "Open mini.files (directory of current file)",
    },
    {
      "<leader>E",
      function()
        require("mini.files").open(vim.uv.cwd(), true)
      end,
      desc = "Open mini.files (cwd)",
    },
    {
      "<leader>fm",
      function()
        require("mini.files").open(LazyVim.root(), true)
      end,
      desc = "Open mini.files (root)",
    },
  },
  opts = {
    windows = {
      width_focus = 40,
      width_nofocus = 20,
      width_preview = 70,
      preview = true,
    },
  },
  config = function(_, opts)
    require("mini.files").setup(opts)

    local git_ns = vim.api.nvim_create_namespace("minifiles_git")

    local show_dotfiles = true
    local filter_show = function()
      return true
    end
    local filter_hide = function(fs_entry)
      return not vim.startswith(fs_entry.name, ".")
    end

    local toggle_dotfiles = function()
      show_dotfiles = not show_dotfiles
      MiniFiles.refresh({ content = { filter = show_dotfiles and filter_show or filter_hide } })
    end

    local yank_path = function()
      local path = (MiniFiles.get_fs_entry() or {}).path
      if path == nil then
        return vim.notify("Cursor is not on valid entry")
      end
      vim.fn.setreg(vim.v.register, path)
    end

    local ui_open = function()
      local entry = MiniFiles.get_fs_entry()
      if entry then
        vim.ui.open(entry.path)
      end
    end

    local set_cwd = function()
      local path = (MiniFiles.get_fs_entry() or {}).path
      if path == nil then
        return vim.notify("Cursor is not on valid entry")
      end
      vim.fn.chdir(vim.fs.dirname(path))
    end

    local map_split = function(buf_id, lhs, direction)
      local rhs = function()
        local cur_target = MiniFiles.get_explorer_state().target_window
        local new_target = vim.api.nvim_win_call(cur_target, function()
          vim.cmd(direction .. " split")
          return vim.api.nvim_get_current_win()
        end)
        MiniFiles.set_target_window(new_target)
      end
      vim.keymap.set("n", lhs, rhs, { buffer = buf_id, desc = "Split " .. direction })
    end

    local flatten = function(t)
      local result = {}
      for _, v in ipairs(t) do
        if type(v) == "table" then
          for _, sv in ipairs(v) do
            result[#result + 1] = sv
          end
        else
          result[#result + 1] = v
        end
      end
      return result
    end

    local string_replace = function(s, pattern, replacement)
      local result = s
      local count = 0
      local offset = 1
      while true do
        local start = string.find(result, pattern, offset, true)
        if not start then
          break
        end
        local before = string.sub(result, 1, start - 1)
        local after = string.sub(result, start + #pattern)
        result = before .. replacement .. after
        count = count + 1
        offset = start + #replacement
      end
      return result, count
    end

    local get_obsidian_vault = function()
      local ok, client = pcall(function()
        return require("obsidian").get_client()
      end)
      if not ok or not client then
        return nil, nil
      end
      return tostring(client.dir), client
    end

    local get_ref_forms = function(ref)
      return {
        "[[" .. ref .. "]]",
        "[[" .. ref .. "|",
        "[[" .. ref .. "\\|",
        "[[" .. ref .. "#",
        "](" .. ref .. ")",
        "](" .. ref .. "#",
      }
    end

    local count_obsidian_refs = function(vault, old_forms)
      local rg_args = { "rg", "--no-config", "--type=md", "--fixed-strings", "--count-matches" }
      for _, form in ipairs(old_forms) do
        rg_args[#rg_args + 1] = "-e"
        rg_args[#rg_args + 1] = form
      end
      rg_args[#rg_args + 1] = vault
      local ok, result = pcall(vim.fn.systemlist, rg_args)
      if not ok or vim.v.shell_error ~= 0 then
        return 0
      end
      local total = 0
      for _, line in ipairs(result) do
        local count = tonumber(line:match(":(%d+)$"))
        if count then
          total = total + count
        end
      end
      return total
    end

    local replace_obsidian_refs_in_file = function(path, old_forms, new_forms)
      local f = io.open(path, "r")
      if not f then
        return 0
      end
      local lines = {}
      local total_count = 0
      for line in f:lines() do
        local modified = line
        for i = 1, #old_forms do
          local n
          modified, n = string_replace(modified, old_forms[i], new_forms[i])
          total_count = total_count + n
        end
        lines[#lines + 1] = modified
      end
      f:close()
      if total_count > 0 then
        f = io.open(path, "w")
        if f then
          for _, l in ipairs(lines) do
            f:write(l .. "\n")
          end
          f:close()
        end
      end
      return total_count
    end

    local update_obsidian_refs = function(old_path, new_path)
      if not (type(old_path) == "string" and type(new_path) == "string") then
        return
      end
      if not (old_path:match("%.md$") and new_path:match("%.md$")) then
        return
      end
      local vault, client = get_obsidian_vault()
      if not vault then
        return
      end
      local norm_vault = vim.fs.normalize(vault)
      local norm_old = vim.fs.normalize(old_path)
      local norm_new = vim.fs.normalize(new_path)
      if not (norm_old:sub(1, #norm_vault) == norm_vault and norm_new:sub(1, #norm_vault) == norm_vault) then
        return
      end
      local old_id = vim.fs.basename(norm_old):gsub("%.md$", "")
      local new_id = vim.fs.basename(norm_new):gsub("%.md$", "")
      local old_rel = tostring(client:vault_relative_path(norm_old, { strict = true }))
      local new_rel = tostring(client:vault_relative_path(norm_new, { strict = true }))
      local old_rel_noext = old_rel:gsub("%.md$", "")

      local old_forms = flatten({
        get_ref_forms(old_id),
        get_ref_forms(old_rel),
        get_ref_forms(old_rel_noext),
      })
      local new_forms = flatten({
        get_ref_forms(new_id),
        get_ref_forms(new_rel),
        get_ref_forms(new_id),
      })

      local ref_count = count_obsidian_refs(norm_vault, old_forms)
      if ref_count == 0 then
        return
      end

      local msg = string.format("Update %d wiki-link reference(s) from '%s' to '%s'?", ref_count, old_id, new_id)
      local choice = vim.fn.confirm(msg, "&Yes\n&No", 1)
      if choice ~= 1 then
        return
      end

      local rg_args = { "rg", "--no-config", "--type=md", "--fixed-strings", "-l" }
      for _, form in ipairs(old_forms) do
        rg_args[#rg_args + 1] = "-e"
        rg_args[#rg_args + 1] = form
      end
      rg_args[#rg_args + 1] = norm_vault
      local ok, files = pcall(vim.fn.systemlist, rg_args)
      if not ok or vim.v.shell_error ~= 0 then
        return
      end

      local total_replaced = 0
      local file_count = 0
      for _, file_path in ipairs(files) do
        if file_path ~= norm_new then
          local n = replace_obsidian_refs_in_file(file_path, old_forms, new_forms)
          if n > 0 then
            total_replaced = total_replaced + n
            file_count = file_count + 1
          end
        end
      end

      vim.cmd.checktime()
      vim.notify(
        string.format("Updated %d reference(s) across %d file(s)", total_replaced, file_count),
        vim.log.levels.INFO
      )
    end

    local manual_obsidian_ref_update = function()
      local entry = MiniFiles.get_fs_entry()
      if not entry or not entry.path then
        return vim.notify("Cursor is not on a valid entry", vim.log.levels.WARN)
      end
      local path = entry.path
      if not path:match("%.md$") then
        return vim.notify("Not a markdown file", vim.log.levels.WARN)
      end
      local vault, client = get_obsidian_vault()
      if not vault then
        return vim.notify("Obsidian not available", vim.log.levels.WARN)
      end
      local cur_id = vim.fs.basename(path):gsub("%.md$", "")
      local new_name = vim.fn.input("Update references from '" .. cur_id .. "' to: ", cur_id)
      if new_name == "" or new_name == cur_id then
        return
      end
      local new_path = vim.fs.dirname(path) .. "/" .. new_name .. ".md"
      update_obsidian_refs(path, new_path)
    end

    local git_sign_map = {
      ["A "] = { text = "++", hl = "MiniFilesGitAdded" },
      ["M "] = { text = "✓", hl = "MiniFilesGitStaged" },
      [" M"] = { text = "✗", hl = "MiniFilesGitModified" },
      ["AM"] = { text = "✗", hl = "MiniFilesGitModified" },
      ["??"] = { text = "?", hl = "MiniFilesGitUntracked" },
      ["R "] = { text = "↕", hl = "MiniFilesGitRenamed" },
      [" D"] = { text = "▼", hl = "MiniFilesGitDeleted" },
      ["D "] = { text = "▼", hl = "MiniFilesGitDeleted" },
      ["MM"] = { text = "✗", hl = "MiniFilesGitModified" },
      ["AD"] = { text = "▼", hl = "MiniFilesGitDeleted" },
      ["RM"] = { text = "↕", hl = "MiniFilesGitRenamed" },
    }

    local git_status = function(dir)
      local repo = vim.fs.find(".git", { path = dir, upward = true, type = "directory" })[1]
      if repo == nil then
        return {}
      end
      local root = vim.fs.dirname(repo)
      local ok, out = pcall(vim.fn.systemlist, {
        "git",
        "-C",
        root,
        "status",
        "--porcelain=v1",
        "--",
        ".",
      })
      if not ok or vim.v.shell_error ~= 0 then
        return {}
      end
      local result = {}
      for _, line in ipairs(out) do
        if line ~= "" then
          local code = line:sub(1, 2)
          local name = line:sub(4)
          if code:sub(2, 2) == "R" then
            name = name:match("-> (.+)$") or name
          end
          result[name] = git_sign_map[code] or { text = "·", hl = "MiniFilesGitOther" }
        end
      end
      return result, root
    end

    local set_git_extmarks = function(buf_id)
      vim.api.nvim_buf_clear_namespace(buf_id, git_ns, 0, -1)
      local dir = vim.fs.dirname(tostring(vim.api.nvim_buf_get_name(buf_id):gsub("minifiles://", "")))
      local status, root = git_status(dir)
      if root == nil then
        return
      end
      for i = 1, vim.api.nvim_buf_line_count(buf_id) do
        local entry = MiniFiles.get_fs_entry(buf_id, i)
        if entry then
          local rel = vim.fs.dirname(entry.path:sub(#root + 2))
          if rel == "" then
            rel = "."
          end
          local key = rel == "." and entry.name or (rel .. "/" .. entry.name)
          local s = status[key] or status[entry.name]
          if s then
            vim.api.nvim_buf_set_extmark(buf_id, git_ns, i - 1, 0, {
              virt_text = { { " " .. s.text, s.hl } },
              virt_text_pos = "right_align",
              hl_mode = "combine",
            })
          end
        end
      end
    end

    local define_git_highlights = function()
      local hi = vim.api.nvim_set_hl
      hi(0, "MiniFilesGitAdded", { link = "GitSignsAdd" })
      hi(0, "MiniFilesGitStaged", { link = "GitSignsStaged" })
      hi(0, "MiniFilesGitModified", { link = "GitSignsChange" })
      hi(0, "MiniFilesGitUntracked", { link = "GitSignsUntracked" })
      hi(0, "MiniFilesGitRenamed", { link = "GitSignsRename" })
      hi(0, "MiniFilesGitDeleted", { link = "GitSignsDelete" })
      hi(0, "MiniFilesGitOther", { link = "DiagnosticWarn" })
    end
    define_git_highlights()
    vim.api.nvim_create_autocmd("ColorScheme", { callback = define_git_highlights })

    vim.api.nvim_create_autocmd("User", {
      pattern = "MiniFilesBufferCreate",
      callback = function(args)
        local buf_id = args.data.buf_id
        vim.keymap.set("n", "g.", toggle_dotfiles, { buffer = buf_id, desc = "Toggle dotfiles" })
        vim.keymap.set("n", "gy", yank_path, { buffer = buf_id, desc = "Yank path" })
        vim.keymap.set("n", "gX", ui_open, { buffer = buf_id, desc = "OS open" })
        vim.keymap.set("n", "g~", set_cwd, { buffer = buf_id, desc = "Set cwd" })
        vim.keymap.set("n", "gl", manual_obsidian_ref_update, { buffer = buf_id, desc = "Update obsidian refs" })
        map_split(buf_id, "<C-s>", "belowright horizontal")
        map_split(buf_id, "<C-v>", "belowright vertical")
      end,
    })

    vim.api.nvim_create_autocmd("User", {
      pattern = "MiniFilesExplorerOpen",
      callback = function()
        local set_mark = function(id, path, desc)
          MiniFiles.set_bookmark(id, path, { desc = desc })
        end
        set_mark("c", vim.fn.stdpath("config"), "Config")
        set_mark("w", vim.fn.getcwd, "Working directory")
        set_mark("~", "~", "Home")
        set_mark("d", "~/notes/docs/30-dailynotes", "Daily Notes")
        set_mark("a", "~/notes/docs/10-areas", "Areas")
        set_mark("r", "~/notes/docs/20-resources", "Resources")
        set_mark("p", "~/notes/docs/00-projects", "Projects")
      end,
    })

    vim.api.nvim_create_autocmd("User", {
      pattern = "MiniFilesBufferUpdate",
      callback = function(args)
        vim.schedule(function()
          set_git_extmarks(args.data.buf_id)
        end)
      end,
    })

    vim.api.nvim_create_autocmd("User", {
      pattern = "MiniFilesActionRename",
      callback = function(args)
        vim.schedule(function()
          update_obsidian_refs(args.data.from, args.data.to)
        end)
      end,
    })

    vim.api.nvim_create_autocmd("User", {
      pattern = "MiniFilesActionMove",
      callback = function(args)
        vim.schedule(function()
          update_obsidian_refs(args.data.from, args.data.to)
        end)
      end,
    })
  end,
}
