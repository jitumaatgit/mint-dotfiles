local M = {}

local function extract_prompt_from_buffer(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local in_frontmatter = false
  local frontmatter_ended = false
  local prompt_lines = {}

  for _, line in ipairs(lines) do
    if line:match("^---%s*$") then
      if not in_frontmatter then
        in_frontmatter = true
      else
        frontmatter_ended = true
      end
    elseif frontmatter_ended then
      table.insert(prompt_lines, line)
    end
  end

  -- Remove leading/trailing blank lines
  while #prompt_lines > 0 and prompt_lines[1] == "" do
    table.remove(prompt_lines, 1)
  end
  while #prompt_lines > 0 and prompt_lines[#prompt_lines] == "" do
    table.remove(prompt_lines)
  end

  return table.concat(prompt_lines, "\n")
end

local function spawn_omp_terminal(prompt)
  local snacks = require("snacks")

  -- Open horizontal terminal split using snacks.terminal (same as C-/)
  -- Pass prompt as argv to omp (not stdin)
  local term = snacks.terminal.open({ "omp", prompt }, {
    win = { position = "bottom", height = 15 },
  })
  local term_buf = term.buf

  -- Terminal persists; no stdin sending needed
  return term_buf
end

function M.setup(opts)
  opts = opts or {}

  vim.api.nvim_create_autocmd("BufWritePost", {
    pattern = "*/notes/90-archive/prompts/*.md",
    callback = function(args)
      local bufnr = args.buf

      -- Check if already spawned
      if vim.b[bufnr].omp_spawned then
        return
      end

      local prompt = extract_prompt_from_buffer(bufnr)
      if prompt == "" then
        return
      end

      -- Mark as spawned before opening terminal to prevent re-entry
      vim.b[bufnr].omp_spawned = true

      spawn_omp_terminal(prompt)
    end,
  })
end

return M