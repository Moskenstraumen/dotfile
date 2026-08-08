-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

local function update_remote_nav_title()
  local current = vim.fn.winnr()
  local keys = {}

  if vim.fn.winnr("h") ~= current then
    keys[#keys + 1] = "j"
  end
  if vim.fn.winnr("j") ~= current then
    keys[#keys + 1] = "k"
  end
  if vim.fn.winnr("k") ~= current then
    keys[#keys + 1] = "i"
  end
  if vim.fn.winnr("l") ~= current then
    keys[#keys + 1] = "l"
  end

  vim.o.title = true
  vim.o.titlestring = "nvim:" .. table.concat(keys)
end

vim.api.nvim_create_autocmd({
  "BufWinEnter",
  "TabEnter",
  "VimEnter",
  "VimResized",
  "WinClosed",
  "WinEnter",
  "WinNew",
}, {
  group = vim.api.nvim_create_augroup("remote_nav_title", { clear = true }),
  callback = function()
    vim.schedule(update_remote_nav_title)
  end,
})
