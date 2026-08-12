#!/usr/bin/env bash
source "$HOME/.config/yabai/scripts/utils.sh"

# 0. CONSTANTS (Display IDs)
# The built-in display is the main display; the external display is the extension
MAIN=1
EXTEND=2

# 1. ENSURE WE HAVE AT LEAST 6 SPACES
ensure_minimum_spaces 6

# 2. GET THE ACTUAL SPACE INDEXES
SPACE1=$(get_space_index 1)
SPACE2=$(get_space_index 2)
SPACE3=$(get_space_index 3)
SPACE4=$(get_space_index 4)
SPACE5=$(get_space_index 5)
SPACE6=$(get_space_index 6)

# 3. ASSIGN SPACES TO DISPLAYS
yabai -m space "$SPACE1" --display "$MAIN" 2>/dev/null || true
yabai -m space "$SPACE2" --display "$MAIN" 2>/dev/null || true
yabai -m space "$SPACE3" --display "$MAIN" 2>/dev/null || true
yabai -m space "$SPACE4" --display "$MAIN" 2>/dev/null || true
yabai -m space "$SPACE5" --display "$EXTEND" 2>/dev/null || true
yabai -m space "$SPACE6" --display "$EXTEND" 2>/dev/null || true

# 4. LABEL SPACES AND SET LAYOUT
yabai -m space "$SPACE1" --label "work" --layout stack
yabai -m space "$SPACE2" --label "brow" --layout stack
yabai -m space "$SPACE3" --label "note" --layout stack
yabai -m space "$SPACE4" --label "chat" --layout stack
yabai -m space "$SPACE5" --label "edit" --layout stack
yabai -m space "$SPACE6" --label "paper" --layout stack

# 5. FOCUS MAIN DISPLAY (Optional nice touch)
yabai -m display --focus "$MAIN" 2>/dev/null || true

# 6. DEFINE RULES
# Use labels instead of hardcoded indexes since indexes may vary
yabai -m rule --add app="^ChatGPT$" space=work
yabai -m rule --add app="^kitty$" title!="^kitty-scratchpad$" space=work
yabai -m rule --add app="^Google Chrome$" space=brow
yabai -m rule --add app="^Code$" space=edit
yabai -m rule --add app="^Zotero$" space=paper
yabai -m rule --add app="^Microsoft Word$" space=note
yabai -m rule --add app="^Obsidian$" space=note
yabai -m rule --add app="^Feishu$" space=chat
yabai -m rule --add app="^WeChat$" space=chat

# 7. APPLY RULES
yabai -m rule --apply
