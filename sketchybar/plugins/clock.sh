#!/bin/sh

# Same as the macOS menu bar: Thu Sep 24 14:39:22
label=$(LC_ALL=C date '+%a %b %e %H:%M:%S' | tr -s ' ')

sketchybar --set "$NAME" label="$label"
