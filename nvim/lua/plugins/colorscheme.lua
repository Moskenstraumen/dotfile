return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    opts = {
      flavour = "mocha", -- latte, frappe, macchiato, mocha
      transparent_background = true,
      term_colors = true,
      styles = {
        comments = { "italic" },
        keywords = { "bold", "italic" },
        sidebars = "transparent",
        floats = "transparent",
      },
      color_overrides = {},
      custom_highlights = function(colors)
        return {
          LspInlayHint = {
            bg = "NONE",
            fg = colors.overlay0,
          },
          Statement = { fg = colors.mauve, italic = true, bold = true },
          Type = { fg = colors.blue, bold = true },
          ["@tag.attribute.tsx"] = { italic = true, fg = colors.green },
          ["@keyword.import.tsx"] = { bold = true, italic = true, fg = colors.red },
          ["@keyword.import.typescript"] = { bold = true, italic = true, fg = colors.red },
          ["@keyword.export.tsx"] = { bold = true, italic = true, fg = colors.red },
          ["@keyword.export.typescript"] = { bold = true, italic = true, fg = colors.red },

          ["@keyword.import.python"] = { bold = true, italic = true, fg = colors.red },
          ["@keyword.export.python"] = { bold = true, italic = true, fg = colors.red },

          ["@keyword.import.rust"] = { bold = true, fg = colors.red },
          ["@lsp.type.rust"] = { italic = true, fg = colors.red },
          ["@lsp.type.namespace.rust"] = { fg = colors.red },

          RainbowDelimiterRed = { fg = "#FF5D62" },
          RainbowDelimiterYellow = { fg = "#E6C384" },
          RainbowDelimiterBlue = { fg = "#7FB4CA" },
          RainbowDelimiterOrange = { fg = "#FFA066" },
          RainbowDelimiterGreen = { fg = "#98BB6C" },
          RainbowDelimiterViolet = { fg = "#D27E99" },
          RainbowDelimiterCyan = { fg = "#7AA89F" },
        }
      end,
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin",
    },
  },
}
