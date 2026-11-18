# Login and compute nodes only.

if (( $+commands[nvim] )); then
  alias vi='nvim'
  alias vim='nvim'
else
  alias vi='vim'
fi

# Probe port 7890 with zsh's built-in ztcp rather than depending on nc.
zmodload zsh/net/tcp 2>/dev/null && ztcp 127.0.0.1 7890 2>/dev/null && {
  ztcp -c "$REPLY"
  proxy_on
}
