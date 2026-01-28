return {
  {
    "folke/snacks.nvim",
    opts = {
      picker = {
        win = {
          input = {
            keys = {
              -- Custom movement keys (ijkl instead of hjkl)
              ["k"] = "list_down", -- k = down
              ["i"] = "list_up", -- i = up
              ["j"] = false, -- disable j
              ["h"] = false, -- h is now insert mode
            },
          },
          list = {
            keys = {
              -- Custom movement keys (ijkl instead of hjkl)
              ["k"] = "list_down", -- k = down
              ["i"] = "list_up", -- i = up
              ["j"] = false, -- disable j
              ["h"] = false, -- h is now insert mode
            },
          },
          preview = {
            keys = {
              -- Custom movement keys (ijkl instead of hjkl)
              ["k"] = "list_down", -- k = down
              ["i"] = "list_up", -- i = up
              ["j"] = false, -- disable j
              ["h"] = false, -- h is now insert mode
            },
          },
        },
        -- Explorer-specific configuration
        sources = {
          explorer = {
            win = {
              list = {
                keys = {
                  -- Custom movement keys (ijkl) for explorer
                  ["i"] = "list_up", -- i = up
                  ["k"] = "list_down", -- k = down
                  ["j"] = false, -- disable j
                  ["h"] = false, -- h is insert mode
                },
              },
            },
          },
        },
      },
    },
  },
}
