# Aliases and functions that hold on every machine.
# Anything environment-specific belongs in alias.local.zsh or alias.remote.zsh.

unalias proxy_on proxy_off 2>/dev/null || true

alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

alias src='source ~/.zshrc; curl -s ipinfo.io'

# Force HTTP/1.1 in Go so a half-open proxied H2 connection cannot stall agy.
alias agy='GODEBUG=http2client=0 agy'

# Local proxy on 7890 (Clash on macOS, or a forwarded/local tunnel on remotes).
# no_proxy is set once per environment in zshenv and deliberately left alone
# here, so cluster-internal hosts always bypass the tunnel.
proxy_on() {
  export http_proxy='http://127.0.0.1:7890'
  export https_proxy='http://127.0.0.1:7890'
  export HTTP_PROXY='http://127.0.0.1:7890'
  export HTTPS_PROXY='http://127.0.0.1:7890'
  export all_proxy='socks5h://127.0.0.1:7890'
  export ALL_PROXY='socks5h://127.0.0.1:7890'
}

proxy_off() {
  unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY
}
