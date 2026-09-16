# Aliases and functions that hold on every machine.
# Anything environment-specific belongs in alias.local.zsh or alias.remote.zsh.

unalias proxy_on proxy_off proxy_sg ws 2>/dev/null || true

alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

alias src='source ~/.zshrc'

# no_proxy is set once per environment in the zshrc and deliberately left
# alone here. Clearing it on a cluster would send internal traffic through
# a proxy that is not listening.
proxy_off() {
  unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY
}
