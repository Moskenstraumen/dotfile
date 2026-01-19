-- which-key: Display key hints for mappings
-- Update default hints to use ijkl instead of hjkl
return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  opts = {
    spec = {
      -- Window navigation hints (ijkl)
      { "<C-j>", desc = "Go to Left Window", mode = "n" },
      { "<C-k>", desc = "Go to Lower Window", mode = "n" },
      { "<C-i>", desc = "Go to Upper Window", mode = "n" },
      { "<C-l>", desc = "Go to Right Window", mode = "n" },

      -- Terminal mode navigation hints (ijkl)
      { "<C-j>", desc = "Go to Left Window", mode = "t" },
      { "<C-k>", desc = "Go to Lower Window", mode = "t" },
      { "<C-i>", desc = "Go to Upper Window", mode = "t" },
      { "<C-l>", desc = "Go to Right Window", mode = "t" },

      -- Buffer navigation hints (j/l for prev/next since j=left, l=right)
      { "<S-j>", desc = "Prev Buffer", mode = "n" },
      { "<S-l>", desc = "Next Buffer", mode = "n" },

      -- Movement keys
      { "j", desc = "← Left", mode = { "n", "v", "o" } },
      { "i", desc = "↑ Up", mode = { "n", "v", "o" } },
      { "k", desc = "↓ Down", mode = { "n", "v", "o" } },
      { "l", desc = "→ Right", mode = { "n", "v", "o" } },

      -- Insert mode (remapped from i to h)
      { "h", desc = "Insert", mode = "n" },
      { "H", desc = "Insert at Line Start", mode = "n" },

      -- Move lines up/down
      { "<A-i>", desc = "Move Line Up", mode = "n" },
      { "<A-k>", desc = "Move Line Down", mode = "n" },
      { "<A-i>", desc = "Move Selection Up", mode = "v" },
      { "<A-k>", desc = "Move Selection Down", mode = "v" },

      -- Window resizing
      { "<C-Up>", desc = "Increase Window Height", mode = "n" },
      { "<C-Down>", desc = "Decrease Window Height", mode = "n" },
      { "<C-Left>", desc = "Decrease Window Width", mode = "n" },
      { "<C-Right>", desc = "Increase Window Width", mode = "n" },
    },
  },
}
