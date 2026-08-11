#!/usr/bin/env bash

label="kitty-drop"
grid="24:38:2:2:34:20"

window_info=$(
  yabai -m query --windows 2>/dev/null |
    jq -c --arg label "$label" \
      'first(.[] | select(.scratchpad == $label)) // empty'
)

if [[ -n "$window_info" ]]; then
  window_id=$(jq -r '.id' <<<"$window_info")
  is_visible=$(jq -r '."is-visible"' <<<"$window_info")

  yabai -m window --toggle "$label"

  if [[ "$is_visible" == "true" ]]; then
    yabai -m window "$window_id" --grid "$grid"
  fi

  exit 0
fi

open -na kitty --args -T kitty-scratchpad
