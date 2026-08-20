return {
  "rareitems/anki.nvim",
  -- anki.nvim needs to load on startup to register the .anki filetype association
  -- opts removed: config is passed directly to setup() in the config function below
  -- to avoid issues with lazy.nvim's opts resolution and double-nesting
  config = function()
    require("anki").setup({
      -- tex_support = false: keeps filetype as "anki" instead of "tex.anki"
      tex_support = false,
      -- move_cursor_after_creation: jumps cursor to first field after creating a form
      move_cursor_after_creation = true,
      -- contexts: predefined tag/field presets, used with :AnkiSetContext <name>
      -- e.g. :AnkiSetContext sec -> pre-fills tags with "security-plus comptia"
      contexts = {
        sec = { tags = "security-plus comptia" },
        net = { tags = "network-plus comptia" },
      },
      -- models: maps Anki notetype names to default deck names
      -- these keys MUST match the actual notetype names in Anki (they're passed to AnkiConnect)
      -- the values are the deck names to send cards to by default
      models = {
        ["Basic"] = "Comptia Sec+",
        ["Basic (and reversed card)"] = "Comptia Sec+",
        ["Basic (optional reversed card)"] = "Comptia Sec+",
        ["Basic (type in the answer)"] = "Comptia Sec+",
        ["Cloze"] = "Comptia Sec+",
        ["Image Occlusion"] = "Comptia Sec+",
        ["Multiple Choice"] = "Comptia Sec+",
      },
    })

    -- :AnkiSec <notetype> — explicitly sends to the Comptia Sec+ deck
    -- e.g. :AnkiSec Basic, :AnkiSec Cloze
    -- useful when you want to override the default deck for a notetype
    vim.api.nvim_create_user_command("AnkiSec", function(cmd_opts)
      require("anki").ankiWithDeck("Comptia Sec+", cmd_opts.args, nil)
    end, {
      nargs = 1, -- requires exactly 1 argument (the notetype name)
      complete = function()
        return { "Basic", "Basic (and reversed card)", "Basic (optional reversed card)", "Basic (type in the answer)", "Cloze", "Image Occlusion", "Multiple Choice" }
      end,
    })

    -- :AnkiNet <notetype> — explicitly sends to the CompTIA Net+ deck
    -- e.g. :AnkiNet Cloze, :AnkiNet Basic
    -- lets you send any notetype to Net+ regardless of the models config default
    vim.api.nvim_create_user_command("AnkiNet", function(cmd_opts)
      require("anki").ankiWithDeck("CompTIA Net+", cmd_opts.args, nil)
    end, {
      nargs = 1,
      complete = function()
        return { "Basic", "Basic (and reversed card)", "Basic (optional reversed card)", "Basic (type in the answer)", "Cloze", "Image Occlusion", "Multiple Choice" }
      end,
    })
  end,
}
