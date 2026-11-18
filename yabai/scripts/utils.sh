#!/usr/bin/env bash

# Ensure at least <count> spaces exist; try to remove extras if macOS allows it.
ensure_minimum_spaces() {
  local target="$1" current attempts=0 max_attempts=5 last_idx windows new_count window
  current=$(yabai -m query --spaces | jq 'length')

  while [ "$current" -lt "$target" ]; do
    yabai -m space --create
    current=$((current + 1))
  done

  while [ "$current" -gt "$target" ] && [ "$attempts" -lt "$max_attempts" ]; do
    attempts=$((attempts + 1))
    last_idx=$(yabai -m query --spaces | jq -r 'max_by(.index) | .index')
    windows=$(yabai -m query --spaces --space "$last_idx" | jq -r '.windows[]')
    for window in $windows; do
      yabai -m window "$window" --space 1 2>/dev/null || true
    done
    yabai -m space --destroy "$last_idx" 2>/dev/null || true
    new_count=$(yabai -m query --spaces | jq 'length')
    [ "$new_count" -lt "$current" ] || break
    current="$new_count"
  done
}

# Assign each label to the first unlabeled space; preserve existing labels.
LABELS=(work brow paper note chat)
label_spaces() {
  local label idx
  for label in "${LABELS[@]}"; do
    if ! yabai -m query --spaces --space "$label" >/dev/null 2>&1; then
      idx=$(yabai -m query --spaces | jq -r 'map(select(.label == "")) | min_by(.index) | .index')
      [ -n "$idx" ] && [ "$idx" != "null" ] && yabai -m space "$idx" --label "$label"
    fi
    yabai -m space "$label" --layout stack
  done
}

set_gaps() {
  local side
  for side in top bottom left right; do
    yabai -m config "${side}_padding" "$1"
  done
  yabai -m config window_gap "$1"
}

apply_rules() {
  yabai -m rule --add label=to-chrome app="^Google Chrome$" space=brow
  yabai -m rule --add label=to-zotero app="^Zotero$" space=paper
  yabai -m rule --add label=to-obsidian app="^Obsidian$" space=note
  yabai -m rule --add label=to-feishu app="^Feishu$" space=chat
  yabai -m rule --add label=to-wechat app="^WeChat$" space=chat
  yabai -m rule --apply
}

sync_display_layout() {
  local count
  count=$(yabai -m query --displays 2>/dev/null | jq 'length' 2>/dev/null || echo 0)
  if [ "$count" -eq 1 ]; then
    bash "$HOME/.config/yabai/scripts/single.sh"
  elif [ "$count" -ge 2 ]; then
    bash "$HOME/.config/yabai/scripts/double.sh"
  fi
  sketchybar --trigger yabai_space_changed 2>/dev/null || true
}
