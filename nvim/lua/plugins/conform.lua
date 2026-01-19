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

    -- Format on save configuration
    format_on_save = {
      -- These options will be passed to conform.format()
      timeout_ms = 500,
      lsp_format = "fallback",
    },
  },
}
