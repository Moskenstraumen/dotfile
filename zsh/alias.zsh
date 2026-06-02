unfunction yazi _run_yazi _kitty_user_var 2>/dev/null || true
unalias proxy_on proxy_off 2>/dev/null || true

alias ss="ssh 54.27"
alias sd="ssh 54.48"
alias so="ssh oracle"

alias vi=nvim
alias vim=nvim
alias vz="nvim ~/.zshrc"

alias src="source ~/.zshrc"

y() {
  local tmp cwd
  tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
  command yazi "$@" --cwd-file="$tmp"
  IFS= read -r -d '' cwd < "$tmp"
  [ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"
  command rm -f -- "$tmp"
}

retop() {
  local force=0
  if [[ "$1" == "-f" || "$1" == "--force" ]]; then
    force=1
    shift
  fi

  local session="${1:-top}"
  local yazi="${session}:yazi"
  local term="${session}:term"
  local nv="${session}:nv"
  local target target_id current current_id kind self_target self_label self_command self_keys yazi_pane_id
  local -a targets
  local -A kinds keys

  if ! tmux has-session -t "$session" 2>/dev/null; then
    print -u2 "retop: tmux session '$session' not found"
    return 1
  fi

  current_id="$(tmux display-message -p '#{pane_id}' 2>/dev/null)"

  targets=("${yazi}.1" "${term}.1" "${nv}.1" "${nv}.2")

  kinds["${yazi}.1"]="remote"
  kinds["${term}.1"]="remote"
  kinds["${nv}.1"]="remote"
  kinds["${nv}.2"]="remote"

  keys["${yazi}.1"]=$'ss\nslm\ncd SciDisco\ny'
  keys["${term}.1"]=$'ss\nslm'
  keys["${nv}.1"]=$'ss\nslm\nnvtop'
  keys["${nv}.2"]=$'sd\nslm\nnvtop'

  for target in "${targets[@]}"; do
    if ! target_id="$(tmux display-message -p -t "$target" '#{pane_id}' 2>/dev/null)"; then
      print -u2 "retop: tmux pane '$target' not found"
      continue
    fi

    if [[ "$target" == "${yazi}.1" ]]; then
      yazi_pane_id="$target_id"
    fi

    if ! current="$(tmux display-message -p -t "$target_id" '#{pane_current_command}' 2>/dev/null)"; then
      print -u2 "retop: tmux pane '$target' not found"
      continue
    fi

    kind="${kinds["$target"]}"

    if [[ "$target_id" == "$current_id" ]]; then
      self_target="$target_id"
      self_label="$target"
      self_command="$current"
      self_keys="${keys["$target"]}"
      continue
    fi

    if (( ! force )); then
      case "$kind" in
        yazi)
          if [[ "$current" == "yazi" ]]; then
            print "retop: skip $target ($current)"
            continue
          fi
          ;;
        remote)
          if [[ "$current" == "ssh" || "$current" == "mosh" ]]; then
            print "retop: skip $target ($current)"
            continue
          fi
          ;;
      esac

      if [[ -n "$current" && "$current" != "zsh" && "$current" != "bash" && "$current" != "fish" && "$current" != "sh" ]]; then
        print "retop: skip $target (busy: $current; use retop -f to force)"
        continue
      fi
    fi

    if (( force )); then
      tmux respawn-pane -k -t "$target_id"
    else
      tmux send-keys -t "$target_id" C-c C-u
    fi

    while IFS= read -r key; do
      tmux send-keys -t "$target_id" "$key" C-m
    done <<< "${keys["$target"]}"
    print "retop: reconnect $target (${current:-unknown})"
  done

  if [[ -n "$yazi_pane_id" ]]; then
    tmux select-pane -t "$yazi_pane_id"
  fi

  if [[ -n "$self_target" ]]; then
    print "retop: reconnect $self_label (${self_command:-unknown})"
    (
      sleep 0.2
      while IFS= read -r key; do
        tmux send-keys -t "$self_target" "$key" C-m
      done <<< "$self_keys"
    ) >/dev/null 2>&1 &!
  fi
}

alias vk='nvim ~/.config/kitty/kitty.conf'
alias vs="nvim ~/.config/starship.toml"

alias show='kitty +kitten icat'
alias kdiff='kitty +kitten diff'

proxy_on() {
  export http_proxy="http://127.0.0.1:7890"
  export https_proxy="http://127.0.0.1:7890"
  export HTTP_PROXY="http://127.0.0.1:7890"
  export HTTPS_PROXY="http://127.0.0.1:7890"
  export all_proxy="socks5h://127.0.0.1:7890"
  export ALL_PROXY="socks5h://127.0.0.1:7890"
  export no_proxy="localhost,127.0.0.1,::1"
  export NO_PROXY="localhost,127.0.0.1,::1"
}

proxy_off() {
  unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY no_proxy NO_PROXY
}
