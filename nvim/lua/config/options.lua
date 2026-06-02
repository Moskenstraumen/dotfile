-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Disable relative line numbers
vim.opt.relativenumber = false

local has_native_clipboard = vim.fn.executable("pbcopy") == 1
  or (vim.env.WAYLAND_DISPLAY and (vim.fn.executable("wl-copy") == 1 or vim.fn.executable("waycopy") == 1))
  or (vim.env.DISPLAY and (vim.fn.executable("xsel") == 1 or vim.fn.executable("xclip") == 1))
  or vim.fn.executable("lemonade") == 1
  or vim.fn.executable("doitclient") == 1
  or vim.fn.executable("win32yank") == 1
  or vim.fn.executable("clip") == 1
  or vim.fn.executable("termux-clipboard-set") == 1

if not has_native_clipboard then
  vim.g.clipboard = "osc52"
end

-- Enable text wrapping
vim.opt.wrap = true
vim.opt.linebreak = true -- Break lines at word boundaries

vim.opt.cursorline = true
vim.opt.cursorlineopt = "number"
