unalias proxy_on proxy_off 2>/dev/null || true

alias ss="ssh stepmind"
alias so="ssh oracle"

alias vi=nvim
alias vim=nvim
alias vz="nvim ~/.zshrc"

alias src="source ~/.zshrc"

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
