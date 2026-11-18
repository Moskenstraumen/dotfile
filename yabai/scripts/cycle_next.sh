#!/usr/bin/env bash

target=$(yabai -m query --spaces --display | jq -r '
  (map(.index)) as $ids |
  (map(."has-focus") | index(true)) as $i |
  if ($ids | length) > 0 and $i != null then
    $ids[(($i + 1) % ($ids | length))]
  else
    empty
  end
')

[ -n "$target" ] && yabai -m space --focus "$target"
