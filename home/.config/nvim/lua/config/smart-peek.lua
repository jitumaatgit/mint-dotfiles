-- Smart peek module: Universal fold peek that works with UFO, custom foldexpr, or LSP hover
local M = {}

-- Get the content of a fold as a table of lines
function M.get_fold_content(lnum)
  local fold_start = vim.fn.foldclosed(lnum)
  if fold_start == -1 then
    return nil -- Not on a closed fold
  end
  local fold_end = vim.fn.foldclosedend(lnum)
  local lines = vim.api.nvim_buf_get_lines(0, fold_start - 1, fold_end, false)
  return lines, fold_start, fold_end
end

-- Create a floating window to show fold content
function M.peek_fold_content()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local lines, fold_start, fold_end = M.get_fold_content(lnum)

  if not lines then
    return nil -- Not on a fold
  end

  -- Calculate window size
  local width = math.min(80, vim.o.columns - 4)
  local height = math.min(20, #lines)

  -- Create buffer for content
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = vim.bo.filetype
  vim.bo[buf].modifiable = false

  -- Calculate position (centered)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  -- Create window
  local win_opts = {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = " Fold Preview (lines " .. fold_start .. "-" .. fold_end .. ")",
    title_pos = "center",
  }

  local win = vim.api.nvim_open_win(buf, false, win_opts)

  -- Set window highlights
  vim.wo[win].winhighlight = "Normal:Folded,FloatBorder:FloatBorder"

  -- Close window on any key press or cursor move
  local function close_peek()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end

  -- Auto-close autocmds
  local augroup = vim.api.nvim_create_augroup("SmartPeek" .. win, { clear = true })
  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "BufLeave" }, {
    group = augroup,
    buffer = 0,
    once = true,
    callback = close_peek,
  })

  -- Close on 'q' or '<Esc>' in normal mode
  vim.keymap.set("n", "q", close_peek, { buffer = buf, nowait = true, silent = true })
  vim.keymap.set("n", "<Esc>", close_peek, { buffer = buf, nowait = true, silent = true })

  return win
end

-- Main peek function with error notifications only
function M.smart_peek()
  -- Try UFO first (for UFO-managed filetypes)
  local ufo_ok, ufo_winid = pcall(function()
    return require("ufo").peekFoldedLinesUnderCursor()
  end)

  if ufo_ok and ufo_winid then
    return -- UFO peek succeeded (silent)
  end

  -- UFO failed or returned nil, try custom fold peek
  local fold_win = M.peek_fold_content()
  if fold_win then
    return -- Custom fold peek succeeded (silent)
  end

  -- Not on a fold, check if we have LSP
  local has_lsp = #vim.lsp.get_clients({ bufnr = 0 }) > 0
  if not has_lsp then
    vim.notify("No fold or LSP info available", vim.log.levels.INFO)
    return
  end

  -- Try LSP hover (let LSP handle its own notifications)
  local hover_ok = pcall(vim.lsp.buf.hover)

  -- Don't add notification here - LSP will show "No information available" if needed
  -- or show hover window if info exists
end

return M
