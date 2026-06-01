unfunction yazi _run_yazi _kitty_user_var 2>/dev/null || true

alias ss="ssh 54.27"
alias sd="ssh 54.48"
alias so="ssh oracle"

alias vi=nvim
alias vim=nvim
alias vz="nvim ~/.zshrc"
alias vr="nvim ./README.md"
alias vt='vi "$(mktemp /tmp/vt.XXXXXX)"'

alias src="source ~/.zshrc"

y() {
  local tmp cwd
  tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
  command yazi "$@" --cwd-file="$tmp"
  IFS= read -r -d '' cwd < "$tmp"
  [ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"
  command rm -f -- "$tmp"
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
