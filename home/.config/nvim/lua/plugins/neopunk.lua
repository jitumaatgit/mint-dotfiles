-- neopunk.nvim: fetch gemini pages via openk and append to the current buffer
-- https://git.thatit.be/neopunk.nvim.git
return {
  "https://git.thatit.be/neopunk.nvim.git",
  config = function()
    local cfg = {
      key = "go",
      -- plugin defaults to `openk.py`, which is not installed; the binary is `openk`
      execute_command = "openk --linkmode=end %s",
    }

    -- setup() never sets this, but fetch_url() (the <Leader>go mapping) reads it.
    vim.g.neopunk_config = cfg

    -- plugin/neopunk.lua calls setup() with no args during startup, clobbering the
    -- mapping and :Go with the broken `openk.py` default. VimEnter runs after it.
    vim.api.nvim_create_autocmd("VimEnter", {
      once = true,
      callback = function()
        require("neopunk").setup(cfg)
      end,
    })

    -- route gf on http(s) through openk instead of netrw's downloader
    vim.g.netrw_http_cmd = "openk --linkmode=end %s >"
  end,
}
