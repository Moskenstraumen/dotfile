-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local map = vim.keymap.set

-- ============================================================================
-- CUSTOM MOVEMENT KEYS (ijkl instead of hjkl)
-- ============================================================================
-- j = left, i = up, k = down, l = right

-- Basic movement in normal, visual, and operator-pending modes
map({ "n", "v", "o" }, "j", "h", { desc = "Move left" })
map({ "n", "v", "o" }, "i", "k", { desc = "Move up" })
map({ "n", "v", "o" }, "k", "j", { desc = "Move down" })
map({ "n", "v", "o" }, "l", "l", { desc = "Move right" })

-- Remap h to insert mode (since i is now up)
map("n", "h", "i", { desc = "Insert mode" })
map("n", "H", "I", { desc = "Insert at line start" })

-- Window navigation (ijkl) - handled by vim-tmux-navigator plugin
-- See plugins/vim-tmux-navigator.lua for C-ijkl navigation

-- Window resizing
map("n", "<C-Up>", "<cmd>resize +2<cr>", { desc = "Increase window height" })
map("n", "<C-Down>", "<cmd>resize -2<cr>", { desc = "Decrease window height" })
map("n", "<C-Left>", "<cmd>vertical resize -2<cr>", { desc = "Decrease window width" })
map("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = "Increase window width" })

-- Keep visual selection when indenting
map("v", "<", "<gv", { desc = "Indent left" })
map("v", ">", ">gv", { desc = "Indent right" })

-- Move lines up/down with Alt+k/i (since k=down, i=up)
map("n", "<A-k>", "<cmd>m .+1<cr>==", { desc = "Move line down" })
map("n", "<A-i>", "<cmd>m .-2<cr>==", { desc = "Move line up" })
map("v", "<A-k>", ":m '>+1<cr>gv=gv", { desc = "Move selection down" })
map("v", "<A-i>", ":m '<-2<cr>gv=gv", { desc = "Move selection up" })

-- ============================================================================
-- BUFFER NAVIGATION
-- ============================================================================

-- Silent buffer navigation triggered by kitty (cmd+1-9 -> leader+1-9)
map("n", "<leader>1", function() require('bufferline').go_to(1, true) end, { desc = "Go to buffer 1", silent = true })
map("n", "<leader>2", function() require('bufferline').go_to(2, true) end, { desc = "Go to buffer 2", silent = true })
map("n", "<leader>3", function() require('bufferline').go_to(3, true) end, { desc = "Go to buffer 3", silent = true })
map("n", "<leader>4", function() require('bufferline').go_to(4, true) end, { desc = "Go to buffer 4", silent = true })
map("n", "<leader>5", function() require('bufferline').go_to(5, true) end, { desc = "Go to buffer 5", silent = true })
map("n", "<leader>6", function() require('bufferline').go_to(6, true) end, { desc = "Go to buffer 6", silent = true })
map("n", "<leader>7", function() require('bufferline').go_to(7, true) end, { desc = "Go to buffer 7", silent = true })
map("n", "<leader>8", function() require('bufferline').go_to(8, true) end, { desc = "Go to buffer 8", silent = true })
map("n", "<leader>9", function() require('bufferline').go_to(9, true) end, { desc = "Go to buffer 9", silent = true })

-- Quick buffer navigation (using j/l now instead of h/l)
map("n", "<S-j>", "<cmd>bprevious<cr>", { desc = "Prev Buffer" })
map("n", "<S-l>", "<cmd>bnext<cr>", { desc = "Next Buffer" })

