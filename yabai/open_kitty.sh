#!/usr/bin/env bash

label="kitty-drop"
grid="24:38:2:2:34:20"
lock_file="/tmp/yabai-kitty-scratchpad-${UID}.lock"
poll_attempts=40
poll_delay=0.025

# Ignore key-repeat while a cross-display move is still settling.
if ! shlock -f "$lock_file" -p "$$"; then
  exit 0
fi

cleanup() {
  rm -f "$lock_file"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

window_info=$(
  yabai -m query --windows 2>/dev/null |
    jq -c --arg label "$label" \
      'first(.[] | select(.scratchpad == $label)) // empty'
)

if [[ -n "$window_info" ]]; then
  window_id=$(jq -r '.id' <<<"$window_info")
  is_visible=$(jq -r '."is-visible"' <<<"$window_info")

  if [[ "$is_visible" == "true" ]]; then
    if yabai -m window --toggle "$label"; then
      yabai -m window "$window_id" --grid "$grid" 2>/dev/null || true
    fi
  else
    target_display=$(
      yabai -m query --displays 2>/dev/null |
        jq -r 'first(.[] | select(."has-focus")) | .index // empty'
    )
    current_display=$(jq -r '.display // empty' <<<"$window_info")

    if [[ -n "$target_display" && "$current_display" != "$target_display" ]]; then
      yabai -m window "$window_id" --display "$target_display" 2>/dev/null || true

      # A successful --display command can return before macOS finishes the
      # cross-display move. Wait for yabai's window state to catch up before
      # calculating the target display's grid.
      for ((attempt = 0; attempt < poll_attempts; attempt++)); do
        current_display=$(
          yabai -m query --windows --window "$window_id" 2>/dev/null |
            jq -r '.display // empty'
        )
        [[ "$current_display" == "$target_display" ]] && break
        sleep "$poll_delay"
      done
    fi

    # Repeating this while hidden absorbs a late macOS frame update without a
    # visible reposition jump.
    yabai -m window "$window_id" --grid "$grid" 2>/dev/null || true
    sleep 0.05
    yabai -m window "$window_id" --grid "$grid" 2>/dev/null || true

    yabai -m window --toggle "$label"
  fi

  exit 0
fi

open -na kitty --args -T kitty-scratchpad
