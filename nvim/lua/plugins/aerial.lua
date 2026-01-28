-- aerial.nvim: Code outline window showing LSP symbols and Treesitter
return {
  "stevearc/aerial.nvim",
  event = "VeryLazy",
  opts = {
    -- Priority list of preferred backends for aerial
    backends = { "lsp", "treesitter", "markdown", "asciidoc", "man" },

    layout = {
      -- These control the width of the aerial window
      max_width = { 40, 0.2 },
      width = nil,
      min_width = 10,

      -- Determines the default direction to open the aerial window
      default_direction = "prefer_right",

      -- Determines where the aerial window will be opened
      placement = "window",
    },

    -- Determines how the aerial window decides which buffer to display symbols for
    attach_mode = "window",

    -- List of enum values that configure when to auto-close the aerial window
    close_automatic_events = {},

    -- Keymaps in aerial window
    keymaps = {
      ["?"] = "actions.show_help",
      ["g?"] = "actions.show_help",
      ["<CR>"] = "actions.jump",
      ["<2-LeftMouse>"] = "actions.jump",
      ["<C-v>"] = "actions.jump_vsplit",
      ["<C-s>"] = "actions.jump_split",
      ["p"] = "actions.scroll",
      ["{"] = "actions.prev",
      ["}"] = "actions.next",
      ["[["] = "actions.prev_up",
      ["]]"] = "actions.next_up",
      ["q"] = "actions.close",
      ["o"] = "actions.tree_toggle",
      ["za"] = "actions.tree_toggle",
      ["O"] = "actions.tree_toggle_recursive",
      ["zA"] = "actions.tree_toggle_recursive",
      ["l"] = "actions.tree_open",
      ["zo"] = "actions.tree_open",
      ["L"] = "actions.tree_open_recursive",
      ["zO"] = "actions.tree_open_recursive",
      ["h"] = "actions.tree_close",
      ["zc"] = "actions.tree_close",
      ["H"] = "actions.tree_close_recursive",
      ["zC"] = "actions.tree_close_recursive",
      ["zr"] = "actions.tree_increase_fold_level",
      ["zR"] = "actions.tree_open_all",
      ["zm"] = "actions.tree_decrease_fold_level",
      ["zM"] = "actions.tree_close_all",
      ["zx"] = "actions.tree_sync_folds",
      ["zX"] = "actions.tree_sync_folds",
    },

    -- Show box drawing characters for the tree hierarchy
    show_guides = true,

    -- Customize the characters used when show_guides = true
    guides = {
      mid_item = "├─",
      last_item = "└─",
      nested_top = "│ ",
      whitespace = "  ",
    },

    -- Options for filtering symbols
    filter_kind = {
      "Class",
      "Constructor",
      "Enum",
      "Function",
      "Interface",
      "Module",
      "Method",
      "Struct",
    },
  },

  -- Setup keybindings
  keys = {
    { "<leader>a", "<cmd>AerialToggle!<CR>", desc = "Toggle Aerial (Code Outline)" },
    { "<leader>ca", "<cmd>AerialToggle<CR>", desc = "Aerial (Code Outline)" },
  },

  -- Optional dependencies
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "nvim-tree/nvim-web-devicons",
  },
}
