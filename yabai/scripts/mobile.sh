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
yabai -m space "$SPACE1" --label "dev"
yabai -m space "$SPACE2" --label "web"
yabai -m space "$SPACE3" --label "work"
yabai -m space "$SPACE4" --label "notes"

# 4. DEFINE RULES (Mobile Layout)
# Use labels instead of hardcoded indexes
yabai -m rule --add app="^kitty$" space=dev
yabai -m rule --add app="^Google Chrome$" space=web
yabai -m rule --add app="^Microsoft Word$" space=work
yabai -m rule --add app="^Feishu$" space=work
yabai -m rule --add app="^WeChat$" space=work
yabai -m rule --add app="^Obsidian$" space=notes

# 5. APPLY RULES
yabai -m rule --apply

echo "Mobile Mode: 3 Spaces Configured"