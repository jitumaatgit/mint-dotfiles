local M = {}

---@class obsidian_task_filter.Opts
---@field picker string|? The picker to use (telescope, fzf-lua, mini.pick, or nil to use obsidian.nvim's picker)
---@field layout_strategy string|? Telescope layout strategy (horizontal, vertical, center, cursor, bottom_pane, ivy, flex)
---@field task_patterns table Patterns for matching different task states
---@field show_completed boolean Whether to show completed tasks
---@field preview_context integer Number of context lines to show in preview
---@field format string Format string for task display

-- Cache compiled patterns for performance (vim.regex objects)
local cached_patterns = {}

---Default configuration
---@type obsidian_task_filter.Opts
M.opts = {
  picker = nil,
  layout_strategy = "ivy",
  task_patterns = {
    incomplete = "^%s*%- %[%s%]",
    in_progress = "^%s*%- %[/]",
    completed = "^%s*%- %[x]",
  },
  show_completed = false,
  preview_context = 3,
  format = "{filename}:{line} [{tags}] {task}",
}

---Compile and cache patterns as vim.regex objects
local function ensure_patterns_cached()
  if not vim.tbl_isempty(cached_patterns) then
    return cached_patterns
  end
  for name, pattern in pairs(M.opts.task_patterns) do
    cached_patterns[name] = vim.regex(pattern)
  end
  return cached_patterns
end

---Setup function
---@param opts obsidian_task_filter.Opts|?
M.setup = function(opts)
  M.opts = vim.tbl_deep_extend("force", M.opts, opts or {})
  M.register_commands()
end

---Register commands
M.register_commands = function()
  vim.api.nvim_create_user_command("ObsidianTasksByTag", function(args)
    local tags = {}
    if args.args and args.args ~= "" then
      tags = vim.split(args.args, "[%s,]+", { trimempty = true })
      tags = vim.tbl_map(function(t) return t:gsub("^#", "") end, tags)
    end
    M.filter_tasks_by_tags(tags)
  end, {
    nargs = "*",
    desc = "Filter tasks by file-level tags",
    complete = function()
      -- Could add tag completion here
      return {}
    end,
  })
end

---Check if a line is a task
---@param line string
---@return string|? task_type The type of task (incomplete, in_progress, completed) or nil
M.is_task_line = function(line)
  local patterns = ensure_patterns_cached()

  -- Fast path: incomplete and in-progress tasks
  if patterns.incomplete:match_str(line) then
    return "incomplete"
  end
  if patterns.in_progress:match_str(line) then
    return "in_progress"
  end

  -- Check completed only if enabled
  if M.opts.show_completed and patterns.completed:match_str(line) then
    return "completed"
  end

  return nil
end

---Extract the task text from a line
---@param line string
---@return string
M.extract_task_text = function(line)
  -- Match checkbox patterns like "- [ ]", "- [x]", "- [/]"
  -- and capture the rest of the line
  return line:match("^%s*%- %[[%sx/]%]%s*(.*)$") or line
end

---Filter tasks by tags
---@param tags string[] Array of tag names (without # prefix)
M.filter_tasks_by_tags = function(tags)
  local ok, obsidian = pcall(require, "obsidian")
  if not ok then
    vim.notify("obsidian-task-filter requires obsidian.nvim to be installed", vim.log.levels.ERROR)
    return
  end

  local client = obsidian.get_client()
  if not client then
    vim.notify("obsidian.nvim client not available", vim.log.levels.ERROR)
    return
  end

  -- If no tags provided, prompt user
  if #tags == 0 then
    M.prompt_for_tags(client, function(selected_tags)
      M.find_and_display_tasks(client, selected_tags)
    end)
  else
    M.find_and_display_tasks(client, tags)
  end
end

---Prompt user for tags
---@param client obsidian.Client
---@param callback function(string[])
M.prompt_for_tags = function(client, callback)
  -- Get all tags in the vault
  client:list_tags_async(nil, function(all_tags)
    -- Use vim.ui.select for tag selection (could be enhanced with telescope/etc)
    if #all_tags == 0 then
      vim.notify("No tags found in vault", vim.log.levels.WARN)
      return
    end

    -- For now, use a simple input prompt
    -- In a full implementation, this would use the picker
    vim.ui.input({
      prompt = "Enter tags (comma or space separated): ",
    }, function(input)
      if not input or input == "" then
        return
      end
      local selected_tags = {}
      for tag in string.gmatch(input, "[^%s,]+") do
        table.insert(selected_tags, (tag:gsub("^#", "")))
      end
      callback(selected_tags)
    end)
  end)
end

---Find and display tasks
---@param client obsidian.Client
---@param tags string[]
M.find_and_display_tasks = function(client, tags)
  if #tags == 0 then
    vim.notify("No tags specified", vim.log.levels.WARN)
    return
  end

  -- Show loading message
  vim.notify("Searching for tasks with tags: " .. table.concat(tags, ", "), vim.log.levels.INFO)

  -- Create a combined list of all matching files
  local all_matching_files = {}
  local processed_paths = {}
  local search_complete = { inline = false, frontmatter = false }

  local function check_complete()
    if search_complete.inline and search_complete.frontmatter then
      -- All searches complete, process results
      if vim.tbl_isempty(all_matching_files) then
        vim.notify("No files found with tags: " .. table.concat(tags, ", "), vim.log.levels.WARN)
        return
      end

      -- Convert to tag_locations format for processing
      local combined_locations = {}
      for path, file_data in pairs(all_matching_files) do
        for tag, _ in pairs(file_data.tags) do
          table.insert(combined_locations, {
            path = path,
            tag = tag,
            note = file_data.note,
          })
        end
      end

      -- Group by file and filter for files that have ALL tags
      local files_with_tasks = M.process_tag_locations(client, combined_locations, tags)

      if #files_with_tasks == 0 then
        vim.notify("No tasks found in files with all specified tags", vim.log.levels.INFO)
        return
      end

      -- Display in picker
      M.show_task_picker(client, files_with_tasks, tags)
    end
  end

  -- 1. Find inline tags
  client:find_tags_async(tags, function(tag_locations)
    if tag_locations then
      for _, loc in ipairs(tag_locations) do
        local path = tostring(loc.path)
        if not processed_paths[path] then
          processed_paths[path] = { tags = {}, note = loc.note }
          all_matching_files[path] = processed_paths[path]
        end
        processed_paths[path].tags[loc.tag] = true
      end
    end
    search_complete.inline = true
    check_complete()
  end, { search = { sort = true } })

  -- 2. Find frontmatter tags by scanning all files
  local Note = require("obsidian.note")
  local found_frontmatter_files = {}

  client:apply_async_raw(function(path)
    -- Try to load the note to check frontmatter
    local ok, note = pcall(Note.from_file_async, path)
    if ok and note and note.tags then
      -- Build tag set for O(1) lookup
      local fm_tag_set = {}
      for _, fm_tag in ipairs(note.tags) do
        fm_tag_set[fm_tag] = true
      end
      -- Check if any of the requested tags are in frontmatter
      for _, required_tag in ipairs(tags) do
        if fm_tag_set[required_tag] then
          found_frontmatter_files[path] = { note = note, tag = required_tag }
          break
        end
      end
    end
  end, {
    on_done = function()
      -- Add frontmatter matches to the combined list
      for path, data in pairs(found_frontmatter_files) do
        if not processed_paths[path] then
          processed_paths[path] = { tags = {}, note = data.note }
          all_matching_files[path] = processed_paths[path]
        end
        processed_paths[path].tags[data.tag] = true
      end
      search_complete.frontmatter = true
      check_complete()
    end,
  })
end

---Process tag locations and extract tasks
---@param client obsidian.Client
---@param tag_locations obsidian.TagLocation[]
---@param required_tags string[]
---@return table[] Array of file data with tasks
M.process_tag_locations = function(client, tag_locations, required_tags)
  -- Group locations by file
  local files = {}
  for _, loc in ipairs(tag_locations) do
    local path = tostring(loc.path)
    if not files[path] then
      local fm_tag_set = {}
      if loc.note and loc.note.tags then
        for _, fm_tag in ipairs(loc.note.tags) do
          fm_tag_set[fm_tag] = true
        end
      end
      files[path] = {
        path = path,
        note = loc.note,
        tags = {},
        fm_tag_set = fm_tag_set,
        tag_locations = {},
      }
    end
    files[path].tags[loc.tag] = true
    table.insert(files[path].tag_locations, loc)
  end

  -- Filter for files that have ALL required tags
  local matching_files = {}
  for path, file_data in pairs(files) do
    local has_all_tags = true
    for _, required_tag in ipairs(required_tags) do
      -- Check inline tags OR frontmatter tags (both are O(1) now)
      if not file_data.tags[required_tag] and not file_data.fm_tag_set[required_tag] then
        has_all_tags = false
        break
      end
    end

    if has_all_tags then
      -- Extract tasks from this file
      local tasks = M.extract_tasks_from_file(file_data.path, file_data.note)
      if #tasks > 0 then
        file_data.tasks = tasks
        table.insert(matching_files, file_data)
      end
    end
  end

  return matching_files
end

---Extract tasks from a file
---@param path string
---@param note obsidian.Note
---@return table[] Array of task data
M.extract_tasks_from_file = function(path, note)
  local tasks = {}

  -- Read file lines using vim's built-in function
  local lines = vim.fn.readfile(path)
  if not lines or #lines == 0 then
    return tasks
  end

  -- Find task lines
  for i, line in ipairs(lines) do
    local task_type = M.is_task_line(line)
    if task_type then
      table.insert(tasks, {
        line_num = i,
        text = M.extract_task_text(line),
        raw_line = line,
        type = task_type,
        context = M.get_context(lines, i),
      })
    end
  end

  return tasks
end

---Get context lines around a task
---@param lines string[]
---@param line_num integer
---@return string[]
M.get_context = function(lines, line_num)
  local context = {}
  local start_line = math.max(1, line_num - M.opts.preview_context)
  return vim.list_slice(lines, start_line, end_line)
end

---Show task picker
---@param client obsidian.Client
---@param files table[]
---@param tags string[]
M.show_task_picker = function(client, files, tags)
  local items = {}
  local tag_str = table.concat(tags, ",")
  local path_cache = {}

  -- Build picker items
  for _, file_data in ipairs(files) do
    local filename = path_cache[file_data.path]
    if not filename then
      filename = vim.fn.fnamemodify(file_data.path, ":t")
      path_cache[file_data.path] = filename
    end

    for _, task in ipairs(file_data.tasks) do
      local display = M.opts.format
        :gsub("{filename}", filename)
        :gsub("{line}", tostring(task.line_num))
        :gsub("{tags}", tag_str)
        :gsub("{task}", task.text)

      table.insert(items, {
        display = display,
        path = file_data.path,
        line = task.line_num,
        text = task.text,
        context = task.context,
        tags = tags,
      })
    end
  end

  -- Use appropriate picker
  if M.opts.picker == "telescope" then
    M.show_telescope_picker(items)
  elseif M.opts.picker == "fzf-lua" then
    M.show_fzf_lua_picker(items)
  else
    -- Use obsidian.nvim's built-in picker or vim.ui.select
    M.show_obsidian_picker(client, items)
  end
end

---Show picker using obsidian.nvim's picker
---@param client obsidian.Client
---@param items table[]
M.show_obsidian_picker = function(client, items)
  -- Use vim.ui.select for all cases (simplified and reliable)
  vim.ui.select(items, {
    prompt = "Select task: ",
    format_item = function(item)
      return item.display
    end,
  }, function(selected)
    if selected then
      M.open_task(selected)
    end
  end)
end

---Show telescope picker
---@param items table[]
M.show_telescope_picker = function(items)
  local ok, telescope = pcall(require, "telescope")
  if not ok then
    vim.notify("Telescope not available", vim.log.levels.ERROR)
    return
  end

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local previewers = require("telescope.previewers")

  local themes = require("telescope.themes")

  -- Get the ivy theme if requested
  local picker_opts = {}
  if M.opts.layout_strategy == "ivy" then
    picker_opts = themes.get_ivy({
      layout_config = {
        height = 0.40, -- change height of ivy theme for picker in obsidian task filter
      },
    })
  else
    picker_opts = {
      layout_strategy = M.opts.layout_strategy,
    }
  end

  pickers
    .new(picker_opts, {
      prompt_title = "Tasks by Tag",
      finder = finders.new_table({
        results = items,
        entry_maker = function(item)
          return {
            value = item,
            display = item.display,
            ordinal = item.display,
            path = item.path,
            lnum = item.line,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      previewer = previewers.new_buffer_previewer({
        title = "Task Context",
        define_preview = function(self, entry)
          local item = entry.value
          local lines = item.context or { item.text }
          vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)

          -- Highlight the task line
          local task_line = M.opts.preview_context + 1
          if task_line <= #lines then
            vim.api.nvim_buf_add_highlight(self.state.bufnr, -1, "ObsidianTask", task_line - 1, 0, -1)
          end
        end,
      }),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if selection then
            M.open_task(selection.value)
          end
        end)
        return true
      end,
    })
    :find()
end

---Show fzf-lua picker
---@param items table[]
M.show_fzf_lua_picker = function(items)
  local ok, fzf_lua = pcall(require, "fzf-lua")
  if not ok then
    vim.notify("fzf-lua not available", vim.log.levels.ERROR)
    return
  end

  local n = #items
  local formatted_items = {}
  for i = 1, n do
    local item = items[i]
    formatted_items[i] = string.format("%s|%d|%s", item.path, item.line, item.display)
  end

  fzf_lua.fzf_exec(formatted_items, {
    prompt = "Tasks by Tag> ",
    actions = {
      ["default"] = function(selected)
        if selected and #selected > 0 then
          local parts = vim.split(selected[1], "|")
          if #parts >= 2 then
            local item = {
              path = parts[1],
              line = tonumber(parts[2]),
            }
            M.open_task(item)
          end
        end
      end,
    },
  })
end

---Open a task location
---@param item table
M.open_task = function(item)
  vim.cmd("edit " .. vim.fn.fnameescape(item.path))
  vim.api.nvim_win_set_cursor(0, { item.line, 0 })
  vim.cmd("normal! zz") -- Center the line
end

return M
