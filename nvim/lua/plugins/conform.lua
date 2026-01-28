return {
  "stevearc/conform.nvim",
  opts = {
    formatters_by_ft = {
      -- Python formatters
      python = { "black" },

      -- TypeScript/JavaScript formatters
      typescript = { "prettier" },
      javascript = { "prettier" },
      typescriptreact = { "prettier" },
      javascriptreact = { "prettier" },
    },
  },
}
