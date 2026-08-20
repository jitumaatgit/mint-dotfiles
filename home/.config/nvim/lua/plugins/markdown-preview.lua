return {
  "iamcco/markdown-preview.nvim",
  opts = function()
    -- No hardcoded browser path; let markdown-preview use xdg-open (system default).
    vim.g.mkdp_browser = ""

    -- Optional: Show preview URL for debugging
    vim.g.mkdp_echo_preview_url = 1
  end,
}