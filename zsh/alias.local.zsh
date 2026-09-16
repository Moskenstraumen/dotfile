# macOS workstation only.

alias ss='ssh stepmind'
alias so='ssh oracle'

alias vi='otty edit'
alias vs='otty edit ~/.config/starship.toml'

# Restore the Otty workspace. The script can't reconnect the tab it runs in, so it
# hands that tab's command back on a __ws_exec__ line for this shell to run.
ws() {
  local line cmd=""
  while IFS= read -r line; do
    if [[ $line == "__ws_exec__ "* ]]; then
      cmd=${line#__ws_exec__ }
    else
      print -r -- "$line"
    fi
  done < <(~/.config/otty/workspace.py)
  [[ -n $cmd ]] && eval "$cmd"
}

# Clash listens on 7890 here.
proxy_on() {
  export http_proxy='http://127.0.0.1:7890'
  export https_proxy='http://127.0.0.1:7890'
  export HTTP_PROXY='http://127.0.0.1:7890'
  export HTTPS_PROXY='http://127.0.0.1:7890'
  export all_proxy='socks5h://127.0.0.1:7890'
  export ALL_PROXY='socks5h://127.0.0.1:7890'
}

# Enable it automatically when Clash is actually up.
nc -z 127.0.0.1 7890 2>/dev/null && proxy_on
