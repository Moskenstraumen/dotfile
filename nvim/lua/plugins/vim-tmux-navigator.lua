-- vim-tmux-navigator: Seamless navigation between tmux panes and vim splits
return {
  "christoomey/vim-tmux-navigator",
  init = function()
    -- Disable default tmux navigator key bindings (we use ijkl instead of hjkl)
    vim.g.tmux_navigator_no_mappings = 1
  end,
  keys = {
    { "<C-j>", "<cmd>TmuxNavigateLeft<cr>", desc = "Navigate left (tmux+nvim)" },
    { "<C-k>", "<cmd>TmuxNavigateDown<cr>", desc = "Navigate down (tmux+nvim)" },
    { "<C-i>", "<cmd>TmuxNavigateUp<cr>", desc = "Navigate up (tmux+nvim)" },
    { "<C-l>", "<cmd>TmuxNavigateRight<cr>", desc = "Navigate right (tmux+nvim)" },
  },
}
