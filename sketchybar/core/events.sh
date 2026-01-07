#!/usr/bin/env bash

sketchybar --add event yabai_window_focus
sketchybar --add event yabai_window_created
sketchybar --add event yabai_window_destroyed
sketchybar --add event yabai_window_minimized
sketchybar --add event yabai_window_deminimized

sketchybar --add event system_woke \
  --add item system_woke left \
  --set system_woke \
  drawing=off \
  script="$SBAR_EVENT_DIR/system_woke.sh" \
  --subscribe system_woke system_woke
