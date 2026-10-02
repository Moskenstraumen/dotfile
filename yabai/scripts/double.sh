#!/usr/bin/env bash
source "$HOME/.config/yabai/scripts/utils.sh"

# The external display is the main display; the built-in display is the extension
MAIN=1
BUILTIN=2

ensure_minimum_spaces 5
label_spaces

# Move by label: indexes renumber after every move
for space in work brow paper; do yabai -m space "$space" --display "$MAIN" 2>/dev/null; done
for space in note chat; do yabai -m space "$space" --display "$BUILTIN" 2>/dev/null; done

set_gaps 2
apply_rules
yabai -m display --focus "$MAIN" 2>/dev/null
