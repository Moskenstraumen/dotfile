#!/usr/bin/env bash
# Map app name to Nerd Font / sketchybar-app-font icon and update workspace items in one batch.

app_icon() {
  case "$1" in
    Safari)                                echo "󰀹" ;;
    Firefox | "Firefox Developer Edition") echo "󰈹" ;;
    "Google Chrome")                       echo "" ;;
    Brave*)                                echo "󰖟" ;;
    "Microsoft Edge")                      echo "󰇩" ;;
    Terminal)                              echo "" ;;
    Rex | iTerm2 | Alacritty | WezTerm)    echo "󰆍" ;;
    kitty)                                 echo "" ;;
    Code | "Visual Studio Code"* | Cursor) echo "󰨞" ;;
    Zed)                                   echo "" ;;
    IntelliJ* | PyCharm* | WebStorm*)      echo "󰬷" ;;
    "Sublime Text")                        echo "󰅳" ;;
    Xcode)                                 echo "󰘧" ;;
    Discord)                               echo "󰙯" ;;
    Slack)                                 echo "󰒱" ;;
    zoom.us | Zoom)                        echo "󰍫" ;;
    "Microsoft Teams")                     echo "󰊻" ;;
    FaceTime)                              echo "󰍐" ;;
    Messages)                              echo "󰍦" ;;
    Mail)                                  echo "󰇮" ;;
    WeChat)                                echo "󰘑" ;;
    Feishu | Lark)                         echo "" ;;
    Spotify)                               echo "󰓇" ;;
    Music)                                 echo "󰎆" ;;
    VLC)                                   echo "󰕼" ;;
    Finder)                                echo "󰀶" ;;
    "System Settings" | "System Preferences") echo "󰒓" ;;
    "Activity Monitor")                    echo "󰈐" ;;
    Preview)                               echo "󰋩" ;;
    Photos)                                echo "󰉏" ;;
    Calendar)                              echo "󰃭" ;;
    Notes | Notion)                        echo "󰎞" ;;
    Obsidian)                              echo "" ;;
    Todoist)                               echo "󰄲" ;;
    Zotero)                                echo "" ;;
    Postman)                               echo "󰳮" ;;
    Docker)                                echo "󰡨" ;;
    "GitHub Desktop")                      echo "󰊤" ;;
    *)                                     echo "󰘔" ;;
  esac
}

app_font() {
  case "$1" in
    "Google Chrome" | Zed | Zotero | Obsidian | Terminal | Feishu | Lark | kitty)
      echo "sketchybar-app-font:Regular:13.0"
      ;;
    *)
      echo "Maple Mono NF CN:Medium:13.0"
      ;;
  esac
}

SPACES="$(yabai -m query --spaces 2>/dev/null)" || exit 0
WINDOWS="$(yabai -m query --windows 2>/dev/null)" || exit 0

MAX_ITEMS=10
batch=()
space_count=0

while IFS=$'\t' read -r sid has_focus top_app; do
  [ -n "$sid" ] || continue
  space_count=$((space_count + 1))
  [ "$sid" -le "$MAX_ITEMS" ] || continue

  highlight="off"
  [ "$has_focus" = "true" ] && highlight="on"

  if [ -n "$top_app" ]; then
    batch+=(
      --set "yabai_space.$sid"
      drawing=on
      "icon.highlight=$highlight"
      background.image.drawing=off
      image.drawing=off
      "label=$(app_icon "$top_app")"
      "label.font=$(app_font "$top_app")"
      label.drawing=on
      label.padding_left=0
      label.padding_right=10
    )
  else
    batch+=(
      --set "yabai_space.$sid"
      drawing=on
      "icon.highlight=$highlight"
      background.image.drawing=off
      image.drawing=off
      label.drawing=off
    )
  fi
done < <(
  jq -nr --argjson spaces "$SPACES" --argjson wins "$WINDOWS" '
    $spaces | to_entries[] |
    (.key + 1) as $sid |
    .value as $s |
    ($s["first-window"] as $w |
      if ($w != null and $w != 0) then
        ($wins | map(select(.id == $w)) | .[0].app // "")
      else
        ""
      end
    ) as $app |
    "\($sid)\t\($s["has-focus"])\t\($app)"
  '
)

for ((sid = space_count + 1; sid <= MAX_ITEMS; sid++)); do
  batch+=(--set "yabai_space.$sid" drawing=off)
done

[ "${#batch[@]}" -gt 0 ] && sketchybar "${batch[@]}"
