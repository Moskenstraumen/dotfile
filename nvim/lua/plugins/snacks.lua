return {
  {
    "folke/snacks.nvim",
    opts = {
      picker = {
        win = {
          input = {
            keys = {
              -- Custom movement keys (ijkl instead of hjkl)
              -- j = left, i = up, k = down, l = right
              ["k"] = "list_down", -- k = down
              ["i"] = "list_up", -- i = up
              ["j"] = false, -- disable j (left doesn't apply here)
              ["h"] = false, -- h is now insert mode
            },
          },
          list = {
            keys = {
              -- Custom movement keys (ijkl instead of hjkl)
              ["k"] = "list_down", -- k = down
              ["i"] = "list_up", -- i = up
              ["j"] = false, -- disable j (left doesn't apply here)
              ["h"] = false, -- h is now insert mode
            },
          },
          preview = {
            keys = {
              -- Custom movement keys (ijkl instead of hjkl)
              ["k"] = "list_down", -- k = down (scroll down in preview)
              ["i"] = "list_up", -- i = up (scroll up in preview)
              ["j"] = false, -- disable j
              ["h"] = false, -- h is now insert mode
              -- Note: preview scrolling uses list_down/list_up actions
            },
          },
        },
      },
    },
  },
}
