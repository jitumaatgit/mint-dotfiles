local M = {}

M.config = {
  timestamp_format = "> Completed: %Y-%m-%d %H:%M",
  completed_heading = "completed",
  canceled_heading = "canceled",
}

local function find_section_headings(lines)
  local sections = {}
  for i, line in ipairs(lines) do
    if line:match("^#+") then
      local text = line:lower():gsub("^#+%s*", ""):gsub("%s*$", "")
      if text == M.config.completed_heading or text == M.config.canceled_heading then
        table.insert(sections, { line = i, kind = text })
      end
    end
  end
  return sections
end

local function is_in_section(line_num, sections, kind)
  for j, s in ipairs(sections) do
    if s.kind == kind then
      local next_s = sections[j + 1]
      local end_line = next_s and (next_s.line - 1) or 999999
      return line_num > s.line and line_num <= end_line
    end
  end
  return false
end

local function extract_task_group(lines, start_line)
  local task_group = {}
  local end_line = start_line
  local task_line = lines[start_line]
  table.insert(task_group, task_line)
  local base_indent = task_line:match("^(%s*)")

  for i = start_line + 1, #lines do
    local line = lines[i]
    local indent = line:match("^(%s*)")
    if #indent > #base_indent then
      table.insert(task_group, line)
      end_line = i
    elseif line:match("^%s*$") then
      table.insert(task_group, line)
      end_line = i
    else
      break
    end
  end

  return task_group, end_line
end

local function find_nearest_heading(lines, line_num)
  for i = line_num - 1, 1, -1 do
    local heading = lines[i]:match("^#+%s+(.+)$")
    if heading then
      return heading
    end
  end
  return nil
end

local function add_heading_context(task_line, heading)
  local prefix, text = task_line:match("^(%s*%-%s*%[[xX]%]%s*)(.*)$")
  if prefix and text then
    return prefix .. heading .. " > " .. text
  end
  return task_line
end

local function add_timestamp_inline(task_line)
  local timestamp = os.date(M.config.timestamp_format)
  return task_line .. " " .. timestamp
end

function M.process_checkbox_completion()
  local bufnr = vim.api.nvim_get_current_buf()
  local filepath = vim.api.nvim_buf_get_name(bufnr)
  if not filepath:match("%.md$") then return end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  local sections = find_section_headings(lines)

  local task_groups = {}
  local i = 1
  while i <= #lines do
    local in_completed = is_in_section(i, sections, M.config.completed_heading)
    local in_canceled = is_in_section(i, sections, M.config.canceled_heading)
    if not in_completed and not in_canceled then
      if lines[i]:match("^%s*%-%s*%[[xX]%]") and not lines[i]:match("> Completed:") then
        local group_lines, end_i = extract_task_group(lines, i)
        local heading = find_nearest_heading(lines, i)
        if heading then
          group_lines[1] = add_heading_context(group_lines[1], heading)
        end
        group_lines[1] = add_timestamp_inline(group_lines[1])
        table.insert(task_groups, { start_i = i, end_i = end_i, group = group_lines })
        i = end_i + 1
      else
        i = i + 1
      end
    else
      i = i + 1
    end
  end

  if #task_groups == 0 then return end

  local to_remove = {}
  for _, tg in ipairs(task_groups) do
    for j = tg.end_i, tg.start_i, -1 do
      table.insert(to_remove, j)
    end
    local trailing = tg.end_i + 1
    if trailing <= #lines and lines[trailing]:match("^%s*$") then
      table.insert(to_remove, trailing)
    end
  end
  table.sort(to_remove, function(a, b) return a > b end)
  local seen = {}
  for _, idx in ipairs(to_remove) do
    if not seen[idx] then
      seen[idx] = true
      table.remove(lines, idx)
    end
  end

  sections = find_section_headings(lines)
  local has_completed = false
  local has_canceled = false
  for _, s in ipairs(sections) do
    if s.kind == M.config.completed_heading then has_completed = true end
    if s.kind == M.config.canceled_heading then has_canceled = true end
  end

  if not has_completed then
    table.insert(lines, "## Completed")
    table.insert(lines, "")
    table.insert(lines, "## Canceled")
    has_completed = true
    has_canceled = true
    sections = find_section_headings(lines)
  end

  local insert_pos = nil
  local cancel_pos = nil
  for _, s in ipairs(sections) do
    if s.kind == M.config.completed_heading then
      insert_pos = s.line + 1
    end
    if s.kind == M.config.canceled_heading then
      cancel_pos = s.line
    end
  end
  if not insert_pos then insert_pos = #lines + 1 end

  while insert_pos <= #lines and lines[insert_pos]:match("^%s*$") do
    insert_pos = insert_pos + 1
  end
  if cancel_pos and insert_pos >= cancel_pos then
    insert_pos = cancel_pos
  end

  for _, tg in ipairs(task_groups) do
    for _, tl in ipairs(tg.group) do
      if tl:match("^%s*$") == nil then
        table.insert(lines, insert_pos, tl)
        insert_pos = insert_pos + 1
      end
    end
  end

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
end

function M.setup(opts)
  opts = opts or {}
  M.config = vim.tbl_deep_extend("force", M.config, opts)

  vim.api.nvim_create_autocmd("BufWritePost", {
    pattern = "*.md",
    callback = function()
      M.process_checkbox_completion()
    end,
    desc = "Move completed tasks to Completed section on save",
  })
end

return M
