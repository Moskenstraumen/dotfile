#!/usr/bin/env bash

# 1. ENSURE MINIMUM NUMBER OF SPACES
# Usage: ensure_minimum_spaces <count>
# Creates spaces if needed to have at least <count> spaces total
# Note: We don't force destroy extra spaces as macOS may prevent this
ensure_minimum_spaces() {
  local target=$1
  local current=$(yabai -m query --spaces | jq 'length')

  echo "Current spaces: $current, Minimum needed: $target"

  # Create spaces if we need more
  while [ "$current" -lt "$target" ]; do
    yabai -m space --create
    current=$((current + 1))
    echo "Created space, now have $current"
  done

  # If we have extras, try to destroy them (but don't force it)
  if [ "$current" -gt "$target" ]; then
    echo "Note: You have $current spaces. Will use the first $target for desk layout."
    echo "Attempting to remove extra spaces (macOS may prevent this)..."

    local max_attempts=5
    local attempts=0

    while [ "$current" -gt "$target" ] && [ "$attempts" -lt "$max_attempts" ]; do
      attempts=$((attempts + 1))
      local last_idx=$(yabai -m query --spaces | jq -r 'max_by(.index) | .index')

      # Move windows away from this space
      local windows=$(yabai -m query --spaces --space "$last_idx" | jq -r '.windows[]')
      if [ -n "$windows" ]; then
        for window in $windows; do
          yabai -m window "$window" --space 1 2>/dev/null || true
        done
      fi

      # Try to destroy
      yabai -m space --destroy "$last_idx" 2>/dev/null || true
      local new_count=$(yabai -m query --spaces | jq 'length')

      if [ "$new_count" -lt "$current" ]; then
        echo "  Removed space $last_idx"
        current=$new_count
      else
        # macOS won't let us destroy this space, give up
        break
      fi
    done

    if [ "$current" -gt "$target" ]; then
      echo "  Could not remove all extra spaces (macOS display requirements)"
      echo "  This is normal - extra spaces will be left unlabeled"
    fi
  fi
}

# 2. GET SPACE INDEX BY POSITION
# Usage: get_space_index <position>
# Returns the index of the Nth space (1-based position in sorted list)
get_space_index() {
  local position=$1
  yabai -m query --spaces | jq -r "sort_by(.index) | .[$(($position - 1))] | .index"
}

# 3. LABEL SPACES
# Gives each label to the first unlabeled space; labels that already exist
# stay where they are, so windows are not shuffled when a display changes
LABELS=(work brow paper note chat)
label_spaces() {
  local label idx
  for label in "${LABELS[@]}"; do
    if ! yabai -m query --spaces --space "$label" >/dev/null 2>&1; then
      idx=$(yabai -m query --spaces | jq -r 'map(select(.label == "")) | min_by(.index) | .index')
      yabai -m space "$idx" --label "$label"
    fi
    yabai -m space "$label" --layout stack
  done
}

# 4. SET PADDING AND GAP
# Usage: set_gaps <px>
set_gaps() {
  local side
  for side in top bottom left right; do
    yabai -m config "${side}_padding" "$1"
  done
  yabai -m config window_gap "$1"
}

# 5. SEND APPS TO THEIR SPACES
# Rules resolve labels to indexes when added, so rerun this after spaces move;
# a rule label replaces the previous rule instead of piling up a new one
apply_rules() {
  yabai -m rule --add label=to-chatgpt app="^ChatGPT$" space=work
  yabai -m rule --add label=to-ghostty app="^Ghostty$" space=work
  yabai -m rule --add label=to-chrome app="^Google Chrome$" space=brow
  yabai -m rule --add label=to-zotero app="^Zotero$" space=paper
  yabai -m rule --add label=to-obsidian app="^Obsidian$" space=note
  yabai -m rule --add label=to-feishu app="^Feishu$" space=chat
  yabai -m rule --add label=to-wechat app="^WeChat$" space=chat
  yabai -m rule --apply
}
