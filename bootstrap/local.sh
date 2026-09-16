#!/usr/bin/env bash
# Bootstrap the macOS workstation.
#
# Unlike the remote profile this assumes Homebrew and admin rights, so tools
# come from brew and the window-manager services get (re)started at the end.
set -euo pipefail

: "${DOTFILES_ROOT:?run this through setup.sh}"
. "$DOTFILES_ROOT/bootstrap/common.sh"
. "$DOTFILES_ROOT/bootstrap/manifest.sh"

[ "$(platform_os)" = "darwin" ] || die "the local profile only supports macOS"

if ! have brew; then
	die "Homebrew is required: https://brew.sh"
fi

log "installing packages from bootstrap/Brewfile"
brew bundle --file "$DOTFILES_ROOT/bootstrap/Brewfile"

log "upgrading installed packages"
brew upgrade

log "linking configuration"
apply_manifest "${MANIFEST_LOCAL[@]}"

log "restarting window manager services"
for service in yabai skhd sketchybar; do
	if have "$service"; then
		brew services restart "$service" >/dev/null || warn "could not restart $service"
	fi
done

if [ ! -f "$HOME/.config/zsh/secrets.zsh" ]; then
	log "no secrets file yet; copy zsh/secrets.zsh.example to ~/.config/zsh/secrets.zsh"
fi

log "done — restart your shell or run: exec zsh"
log "yabai's scripting addition needs a partially disabled SIP; see the yabai wiki"
