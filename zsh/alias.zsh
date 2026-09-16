unalias proxy_on proxy_off ws 2>/dev/null || true

alias ss="ssh stepmind"
alias so="ssh oracle"

alias vi="otty edit"

alias src="source ~/.zshrc"

alias vs="otty edit ~/.config/starship.toml"

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

# Auto-enable the proxy when Clash is actually listening on 7890
nc -z 127.0.0.1 7890 2>/dev/null && proxy_on
