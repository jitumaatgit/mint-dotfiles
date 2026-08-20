_G.MarkdownHeadingFold = function(lnum)
  local line = vim.fn.getline(lnum)
  
  if lnum <= 5 and (line:match("^---") or line:match("^[a-z]+:")) then
    return "0"
  end
  
  local level = line:match("^(#+)")
  if level then
    return ">" .. #level
  end
  
  if line:match("^```") then
    return ">1"
  end
  
  return "="
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    vim.wo.foldmethod = "expr"
    vim.wo.foldexpr = "v:lua.MarkdownHeadingFold(v:lnum)"
    vim.wo.foldlevel = 99
  end,
})

for _, buf in ipairs(vim.api.nvim_list_bufs()) do
  if vim.bo[buf].filetype == "markdown" and vim.api.nvim_buf_is_loaded(buf) then
    local winid = vim.fn.bufwinid(buf)
    if winid ~= -1 then
      vim.wo[winid].foldmethod = "expr"
      vim.wo[winid].foldexpr = "v:lua.MarkdownHeadingFold(v:lnum)"
      vim.wo[winid].foldlevel = 99
    end
  end
end
