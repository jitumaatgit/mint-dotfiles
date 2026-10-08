-- Seed brand-new vault notes with the daily note of the day they are made.
--
-- BufNewFile covers :ObsidianNew (obsidian.nvim creates the note with
-- no_write, so opening it runs :edit on a nonexistent path), and append()
-- covers :ObsidianExtractNote, whose note exists on disk before it is
-- opened. notes/scripts/related_notes.py later rewrites the whole section
-- from the true git creation date, so anything seeded here is absorbed
-- rather than fought. Periodic notes (docs/30-dailynotes) never get a
-- section, exactly like the script.

local M = {}

local VAULT = vim.fn.expand("~/notes")
local SECTION_HEADING = "## Related Notes"

---@param bufnr integer
---@return boolean
local function is_vault_note(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  local prefix = VAULT .. "/docs/"
  if not vim.startswith(name, prefix) or not vim.endswith(name, ".md") then
    return false
  end
  return not vim.startswith(name, prefix .. "30-dailynotes/")
end

---@param bufnr integer
---@return boolean
local function has_section(bufnr)
  for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
    if line:lower():match("^##%s+related notes%s*$") then
      return true
    end
  end
  return false
end

---Append "## Related Notes" with today's daily note to `bufnr`.
---@param bufnr integer|nil current buffer by default
---@return boolean appended
function M.append(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if
    not vim.api.nvim_buf_is_valid(bufnr)
    or not vim.bo[bufnr].modifiable
    or not is_vault_note(bufnr)
    or has_section(bufnr)
  then
    return false
  end
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  if #lines > 0 and lines[#lines] ~= "" then
    table.insert(lines, "")
  end
  table.insert(lines, SECTION_HEADING)
  table.insert(lines, "* [[" .. os.date("%Y-%m-%d") .. "]]")
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  return true
end

function M.setup()
  vim.api.nvim_create_autocmd("BufNewFile", {
    group = vim.api.nvim_create_augroup("DailyRelatedLink", { clear = true }),
    pattern = "*.md",
    desc = "Seed Related Notes with the creation-day daily note",
    callback = function(ev)
      -- Scheduled so obsidian.nvim's frontmatter write (which happens right
      -- after :edit returns) lands first and the section is appended after
      -- it instead of interleaving.
      vim.schedule(function()
        M.append(ev.buf)
      end)
    end,
  })
end

return M
