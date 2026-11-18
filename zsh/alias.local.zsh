# macOS workstation only.

alias ss='ssh stepmind'
alias so='ssh oracle'
alias vi='nvim'
alias vim='nvim'

# Enable proxy automatically when Clash is listening on 7890.
nc -z 127.0.0.1 7890 2>/dev/null && proxy_on
