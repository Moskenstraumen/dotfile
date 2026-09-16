# Login and compute nodes only.

alias vi='vim'

# Proxy forwarded in from the workstation. Unlike the local one this sets no
# SOCKS variables and never touches no_proxy, so cluster-internal hosts keep
# bypassing the tunnel.
proxy_on() {
  export http_proxy='http://127.0.0.1:7890'
  export https_proxy='http://127.0.0.1:7890'
  export HTTP_PROXY='http://127.0.0.1:7890'
  export HTTPS_PROXY='http://127.0.0.1:7890'
}

alias proxy_sg='proxy_on'
