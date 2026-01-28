return {
  "sphamba/smear-cursor.nvim",
  opts = {
    -- Cursor color. Defaults to Cursor GUI color
    cursor_color = "#d3cdc3",

    -- Background color. Defaults to Normal GUI background color
    normal_bg = "#1e1e2e",

    -- Smear cursor when switching buffers or windows
    smear_between_buffers = true,

    -- Smear cursor when moving within line or to neighbor lines
    smear_between_neighbor_lines = true,

    -- Set to `true` if your font supports legacy computing symbols (block unicode symbols).
    -- Smears will blend better on all backgrounds.
    legacy_computing_symbols_support = true,
    transparent_bg_fallback_color = "#303030",

    time_interval = 7,
  },
}
