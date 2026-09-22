# macOS workstation only.

alias ss='ssh stepmind'
alias so='ssh oracle'

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

alias vi='nvim'
alias vim='nvim'
