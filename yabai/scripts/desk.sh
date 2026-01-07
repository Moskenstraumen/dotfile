#!/usr/bin/env bash
source "$HOME/.config/yabai/scripts/utils.sh"

# 0. CONSTANTS (Display IDs)
# Adjust these if your Mac numbers them differently
MAIN=1
VERT=2
BUILT=3

# 1. ENSURE WE HAVE AT LEAST 6 SPACES
ensure_minimum_spaces 6

# 2. GET THE ACTUAL SPACE INDEXES (they might not be 1-6)
SPACE1=$(get_space_index 1)
SPACE2=$(get_space_index 2)
SPACE3=$(get_space_index 3)
SPACE4=$(get_space_index 4)
SPACE5=$(get_space_index 5)
SPACE6=$(get_space_index 6)

echo "Space indexes: $SPACE1, $SPACE2, $SPACE3, $SPACE4, $SPACE5, $SPACE6"

# 3. ASSIGN SPACES TO DISPLAYS AND LABEL THEM
assign_space "$SPACE1" $MAIN "main-dev"
assign_space "$SPACE2" $MAIN "main-work"
assign_space "$SPACE3" $VERT "vert-term"
assign_space "$SPACE4" $VERT "vert-web"
assign_space "$SPACE5" $BUILT "chat"
assign_space "$SPACE6" $BUILT "notes"

# 4. FOCUS MAIN DISPLAY (Optional nice touch)
yabai -m display --focus $MAIN 2>/dev/null || true

# 5. DEFINE RULES (Desk Layout)
# Use labels instead of hardcoded indexes since indexes may vary
yabai -m rule --add app="^Microsoft Word$" space=main-work
yabai -m rule --add app="^kitty$" space=vert-term
yabai -m rule --add app="^Google Chrome$" space=vert-web
yabai -m rule --add app="^Feishu$" space=chat
yabai -m rule --add app="^WeChat$" space=chat
yabai -m rule --add app="^Obsidian$" space=notes

# 6. APPLY RULES
yabai -m rule --apply

echo "Desk Mode: 6 Spaces Distributed"