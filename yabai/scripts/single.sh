#!/usr/bin/env bash
source "$HOME/.config/yabai/scripts/utils.sh"

# When the external display is disconnected, close VS Code and remove the
# double-display-only edit space before applying the single-display layout.
if [ "${1:-}" = "--display-removed" ]; then
  /usr/bin/osascript \
    -e 'set vscodeApp to "Code"' \
    -e 'if application vscodeApp is running then' \
    -e 'tell application vscodeApp to quit' \
    -e 'end if' \
    >/dev/null 2>&1 || true

  EDIT_SPACE=$(yabai -m query --spaces | jq -r \
    'map(select(.label == "edit"))[0].index // empty')

  if [ -n "$EDIT_SPACE" ]; then
    WORK_SPACE=$(yabai -m query --spaces | jq -r \
      'map(select(.label == "work"))[0].index // empty')

    if [ -z "$WORK_SPACE" ] || [ "$WORK_SPACE" = "$EDIT_SPACE" ]; then
      echo "Could not find a safe destination for windows in edit." >&2
      exit 1
    fi

    yabai -m space --focus "$WORK_SPACE" 2>/dev/null || true

    # Stop if edit cannot be removed so ensure_minimum_spaces does not delete paper.
    if ! yabai -m space --destroy "$EDIT_SPACE" 2>/dev/null; then
      echo "Could not remove edit space; single-display layout was not applied." >&2
      exit 1
    fi
  fi
fi

# 1. ENSURE WE HAVE AT LEAST 5 SPACES
ensure_minimum_spaces 5

# 2. GET THE ACTUAL SPACE INDEXES
SPACE1=$(get_space_index 1)
SPACE2=$(get_space_index 2)
SPACE3=$(get_space_index 3)
SPACE4=$(get_space_index 4)
SPACE5=$(get_space_index 5)

# 3. LABEL THE SPACES (all on built-in display already)
yabai -m space "$SPACE1" --label "work" --layout stack
yabai -m space "$SPACE2" --label "brow" --layout stack
yabai -m space "$SPACE3" --label "paper" --layout stack
yabai -m space "$SPACE4" --label "note" --layout stack
yabai -m space "$SPACE5" --label "chat" --layout stack

# 4. DISABLE GAPPING FOR MOBILE MODE
yabai -m config top_padding 0
yabai -m config bottom_padding 0
yabai -m config left_padding 0
yabai -m config right_padding 0
yabai -m config window_gap 0

# 5. DEFINE RULES (Mobile Layout)
# Use labels instead of hardcoded indexes
yabai -m rule --add app="^ChatGPT$" space=work
# Keep regular kitty windows on work; the scratchpad stays global and floating
yabai -m rule --add app="^kitty$" title!="^kitty-scratchpad$" space=work
yabai -m rule --add app="^Google Chrome$" space=brow
yabai -m rule --add app="^Zotero$" space=paper
yabai -m rule --add app="^Microsoft Word$" space=note
yabai -m rule --add app="^Obsidian$" space=note
yabai -m rule --add app="^Feishu$" space=chat
yabai -m rule --add app="^WeChat$" space=chat

# 6. APPLY RULES
yabai -m rule --apply
