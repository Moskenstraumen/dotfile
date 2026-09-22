-- Match Ghostty's glass-dark theme (ghostty/themes/glass-dark). The
-- background stays transparent so Ghostty's opacity and blur show through.
return {
  {
    "folke/tokyonight.nvim",
    opts = {
      style = "night",
      transparent = true,
      styles = {
        sidebars = "transparent",
        floats = "transparent",
      },
      on_colors = function(c)
        c.bg = "#40434b"
        c.bg_dark = "#252a35"
        c.fg = "#f7f8ff"
        c.fg_dark = "#e3e6f0"
        c.comment = "#747b8e"
        c.red = "#ff8a8a"
        c.green = "#a8d46f"
        c.yellow = "#e8c778"
        c.blue = "#8db7ff"
        c.magenta = "#d1a3ff"
        c.purple = "#e0c2ff"
        c.cyan = "#7fd6c2"
        c.teal = "#a3e6d8"
        c.orange = "#ffb0a8"
      end,
    },
  },
}
