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
assign_space "$SPACE1" $MAIN "term"
assign_space "$SPACE2" $MAIN "brow" --layout stack
assign_space "$SPACE3" $VERT "read"
assign_space "$SPACE4" $VERT "work"
assign_space "$SPACE5" $BUILT "chat"
assign_space "$SPACE6" $BUILT "note"

# 4. FOCUS MAIN DISPLAY (Optional nice touch)
yabai -m display --focus $MAIN 2>/dev/null || true

# 5. DEFINE RULES (Desk Layout)
# Use labels instead of hardcoded indexes since indexes may vary
# Kitty windows by tmux session function
yabai -m rule --add app="^kitty$" title="^project$" space=term
yabai -m rule --add app="^kitty$" title="^agent$" space=work
# Default: any other kitty window goes to term
yabai -m rule --add app="^Google Chrome$" space=brow
yabai -m rule --add app="^Zotero$" space=read
yabai -m rule --add app="^Microsoft Word$" space=read
yabai -m rule --add app="^Feishu$" space=chat
yabai -m rule --add app="^WeChat$" space=chat
yabai -m rule --add app="^Obsidian$" space=note

# 6. APPLY RULES
yabai -m rule --apply

echo "Desk Mode: 6 Spaces Distributed"
