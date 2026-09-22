-- Nothing is installed automatically; language servers and formatters
-- are added by hand through :Mason. Drop what core LazyVim ships.
return {
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = vim.tbl_filter(function(name)
        return name ~= "stylua" and name ~= "shfmt"
      end, opts.ensure_installed or {})
    end,
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        lua_ls = { enabled = false },
      },
    },
  },
}
