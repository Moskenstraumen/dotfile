#!/usr/bin/env bash
source "$HOME/.config/yabai/scripts/utils.sh"

# 1. ENSURE WE HAVE AT LEAST 3 SPACES
ensure_minimum_spaces 4

# 2. GET THE ACTUAL SPACE INDEXES
SPACE1=$(get_space_index 1)
SPACE2=$(get_space_index 2)
SPACE3=$(get_space_index 3)
SPACE4=$(get_space_index 4)

echo "Space indexes: $SPACE1, $SPACE2, $SPACE3, $SPACE4"

# 3. LABEL THE SPACES (all on built-in display already)
yabai -m space "$SPACE1" --label "term"
yabai -m space "$SPACE2" --label "brow" --layout stack
yabai -m space "$SPACE3" --label "work" --layout stack
yabai -m space "$SPACE4" --label "chat" --layout stack

# 4. DISABLE GAPPING FOR MOBILE MODE
yabai -m config top_padding 0
yabai -m config bottom_padding 0
yabai -m config left_padding 0
yabai -m config right_padding 0
yabai -m config window_gap 0

# 5. DEFINE RULES (Mobile Layout)
# Use labels instead of hardcoded indexes
# All kitty windows on term space for easy access in single monitor
yabai -m rule --add app="^kitty$" space=term
yabai -m rule --add app="^Google Chrome$" space=brow
yabai -m rule --add app="^Microsoft Word$" space=work
yabai -m rule --add app="^Zotero$" space=work
yabai -m rule --add app="^Feishu$" space=chat
yabai -m rule --add app="^WeChat$" space=chat
yabai -m rule --add app="^Obsidian$" space=chat

# 6. APPLY RULES
yabai -m rule --apply

echo "Mobile Mode: 4 Spaces Configured"
