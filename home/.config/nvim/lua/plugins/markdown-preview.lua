return {
  "iamcco/markdown-preview.nvim",
  opts = function()
    -- On Linux, leave mkdp_browser empty so markdown-preview.nvim uses xdg-open
    -- to launch the user's default browser. (Windows version pointed at the
    -- Scoop-installed zen.exe shim; no equivalent is hard-coded here.)
    vim.g.mkdp_browser = ""

    -- Optional: Show preview URL for debugging
    vim.g.mkdp_echo_preview_url = 1
  end,
}
