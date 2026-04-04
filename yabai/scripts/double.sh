#!/usr/bin/env bash
source "$HOME/.config/yabai/scripts/utils.sh"

# 0. CONSTANTS (Display IDs)
# Adjust these if your Mac numbers them differently
MAIN=1
BUILT=2

# 1. ENSURE WE HAVE AT LEAST 4 SPACES
ensure_minimum_spaces 4

# 2. GET THE ACTUAL SPACE INDEXES (they might not be 1-6)
SPACE1=$(get_space_index 1)
SPACE2=$(get_space_index 2)
SPACE3=$(get_space_index 3)
SPACE4=$(get_space_index 4)

# 3. ASSIGN SPACES TO DISPLAYS
yabai -m space "$SPACE1" --display $MAIN 2>/dev/null || true
yabai -m space "$SPACE2" --display $MAIN 2>/dev/null || true
yabai -m space "$SPACE3" --display $BUILT 2>/dev/null || true
yabai -m space "$SPACE4" --display $BUILT 2>/dev/null || true

# 4. LABEL SPACES AND SET LAYOUT
yabai -m space "$SPACE1" --label "term" --layout stack
yabai -m space "$SPACE2" --label "brow" --layout stack
yabai -m space "$SPACE3" --label "work"
yabai -m space "$SPACE4" --label "chat" --layout stack

# 5. FOCUS MAIN DISPLAY (Optional nice touch)
yabai -m display --focus $MAIN 2>/dev/null || true

# 6. DEFINE RULES
# Use labels instead of hardcoded indexes since indexes may vary
# Kitty windows by tmux session function
yabai -m rule --add app="^kitty$" title="^project$" space=term
yabai -m rule --add app="^kitty$" title="^agent$" space=term
# Default: any other kitty window goes to term
yabai -m rule --add app="^Google Chrome$" space=brow
yabai -m rule --add app="^Zotero$" space=brow
yabai -m rule --add app="^Microsoft Word$" space=brow
yabai -m rule --add app="^Feishu$" space=chat
yabai -m rule --add app="^WeChat$" space=chat
yabai -m rule --add app="^Obsidian$" space=chat

# 7. APPLY RULES
yabai -m rule --apply
