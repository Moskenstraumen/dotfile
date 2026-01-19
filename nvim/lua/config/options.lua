-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Disable relative line numbers
vim.opt.relativenumber = false

-- Enable text wrapping
vim.opt.wrap = true
vim.opt.linebreak = true -- Break lines at word boundaries

-- Enable kitty keyboard protocol for proper Ctrl+i/j/k/l handling
-- This distinguishes Ctrl+i from Tab
if os.getenv("TERM") == "xterm-kitty" then
  vim.cmd([[
    " Enable kitty keyboard protocol on VimEnter
    autocmd VimEnter * if &term == "xterm-kitty" | set termguicolors | endif
  ]])
end
