#!/usr/bin/env bash
# Map app name to Nerd Font Material Design icon
app_icon() {
  case "$1" in
    # Browsers
    Safari)                          echo "󰀹" ;;
    Firefox | "Firefox Developer Edition") echo "󰈹" ;;
    "Google Chrome")                 echo "󰊯" ;;
    Brave*)                          echo "󰖟" ;;
    "Microsoft Edge")                echo "󰇩" ;;

    # Terminals
    Terminal)                        echo "󰆍" ;;
    iTerm2)                          echo "󰆍" ;;
    Ghostty)                         echo "󰊠" ;;
    kitty)                           echo "󰄛" ;;
    Alacritty)                       echo "󰆍" ;;
    WezTerm)                         echo "󰆍" ;;

    # Editors / IDE
    Code | "Visual Studio Code" | "Visual Studio Code - Insiders") echo "󰨞" ;;
    IntelliJ* | PyCharm* | WebStorm*) echo "󰬷" ;;
    "Sublime Text")                  echo "󰅳" ;;
    Xcode)                           echo "󰘧" ;;

    # Chat / meetings
    Discord)                         echo "󰙯" ;;
    Slack)                           echo "󰒱" ;;
    zoom.us | Zoom)                  echo "󰍫" ;;
    "Microsoft Teams")               echo "󰊻" ;;
    FaceTime)                        echo "󰍐" ;;
    Messages)                        echo "󰍦" ;;
    Mail)                            echo "󰇮" ;;
    WeChat)                          echo "󰘑" ;;
    Feishu)                          echo "󰭹" ;;

    # Music / media
    Spotify)                         echo "󰓇" ;;
    Music)                           echo "󰎆" ;;
    VLC)                             echo "󰕼" ;;

    # Apple / system
    Finder)                          echo "󰀶" ;;
    "System Settings" | "System Preferences") echo "󰒓" ;;
    "Activity Monitor")              echo "󰈐" ;;
    Preview)                         echo "󰋩" ;;
    Photos)                          echo "󰉏" ;;
    Calendar)                        echo "󰃭" ;;
    Notes)                           echo "󰎞" ;;

    # Productivity
    Notion)                          echo "󰎞" ;;
    Obsidian)                        echo "󰇈" ;;
    Todoist)                         echo "󰄲" ;;

    # Research / Reference
    Zotero)                          echo "󱉟" ;;

    # Dev tools
    Postman)                         echo "󰳮" ;;
    Docker)                          echo "󰡨" ;;
    "GitHub Desktop")                echo "󰊤" ;;

    *)                               echo "󰘔" ;;
  esac
}

# Query yabai
SPACES="$(yabai -m query --spaces 2>/dev/null)" || exit 0
WINDOWS="$(yabai -m query --windows 2>/dev/null)" || exit 0

space_count=$(printf '%s\n' "$SPACES" | jq 'length')

MAX_ITEMS=10

for (( i=0; i<space_count; i++ )); do
  sid=$((i + 1))

  has_focus=$(printf '%s\n' "$SPACES" | jq -r ".[$i][\"has-focus\"]")
  first_wid=$(printf '%s\n' "$SPACES" | jq -r ".[$i][\"first-window\"]")

  # Get only the topmost (first) window's app icon for this space
  icon=""
  if [ "$first_wid" != "0" ] && [ "$first_wid" != "null" ]; then
    top_app=$(printf '%s\n' "$WINDOWS" \
      | jq -r --argjson wid "$first_wid" '.[] | select(.id == $wid) | .app' 2>/dev/null)
    if [ -n "$top_app" ]; then
      icon=$(app_icon "$top_app")
    fi
  fi

  # Highlight active space
  args=(drawing=on icon.highlight=off)
  if [ "$has_focus" = "true" ]; then
    args=(drawing=on icon.highlight=on)
  fi

  if [ -n "$icon" ]; then
    sketchybar --set "yabai_space.$sid" \
      "${args[@]}" \
      label="$icon" \
      label.drawing=on \
      label.padding_left=0 \
      label.padding_right=10
  else
    sketchybar --set "yabai_space.$sid" \
      "${args[@]}" \
      label.drawing=off
  fi
done

# Hide items for spaces that no longer exist
for (( sid=space_count+1; sid<=MAX_ITEMS; sid++ )); do
  sketchybar --set "yabai_space.$sid" drawing=off 2>/dev/null
done
