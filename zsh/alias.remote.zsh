# Login and compute nodes only.

alias vi='vim'

# Proxy on 7890, forwarded in from the workstation or run on the box itself.
# Like the local one it also sets the SOCKS variables, but it never touches
# no_proxy, so cluster-internal hosts keep bypassing the tunnel.
proxy_on() {
  export http_proxy='http://127.0.0.1:7890'
  export https_proxy='http://127.0.0.1:7890'
  export HTTP_PROXY='http://127.0.0.1:7890'
  export HTTPS_PROXY='http://127.0.0.1:7890'
  export all_proxy='socks5h://127.0.0.1:7890'
  export ALL_PROXY='socks5h://127.0.0.1:7890'
}

# Enable it automatically when the proxy is actually listening. zsh has no
# /dev/tcp, so probe with ztcp instead of depending on nc being installed.
zmodload zsh/net/tcp 2>/dev/null && ztcp 127.0.0.1 7890 2>/dev/null && {
  ztcp -c "$REPLY"
  proxy_on
}
