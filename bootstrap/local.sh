#!/usr/bin/env bash
# Bootstrap the macOS workstation.
#
# Unlike the remote profile this assumes Homebrew and admin rights, so tools
# come from brew and the window-manager services get (re)started at the end.
set -euo pipefail

: "${DOTFILES_ROOT:?run this through setup.sh}"
. "$DOTFILES_ROOT/bootstrap/common.sh"
. "$DOTFILES_ROOT/bootstrap/manifest.sh"
. "$DOTFILES_ROOT/bootstrap/pins.sh"

[ "$(platform_os)" = "darwin" ] || die "the local profile only supports macOS"

if ! have brew; then
	die "Homebrew is required: https://brew.sh"
fi

# The Brewfile has npm entries, so node has to exist before bundling.
log "installing nvm and node ${NODE_VERSION}"
install_nvm || warn "continuing without node; npm entries in the Brewfile will be skipped"

# --no-upgrade because brew bundle otherwise upgrades everything it touches,
# before anything has had a chance to be pinned.
log "installing packages from bootstrap/Brewfile"
brew bundle --no-upgrade --file "$DOTFILES_ROOT/bootstrap/Brewfile"

pin_packages() {
	local kind="$1" name
	shift
	for name in "$@"; do
		brew list "--$kind" "$name" >/dev/null 2>&1 || continue
		brew list --pinned 2>/dev/null | grep -qx "$name" && continue
		brew pin "--$kind" "$name" >/dev/null 2>&1 ||
			warn "could not pin $name"
	done
}

# Expanding an empty array is an unbound-variable error under `set -u` in the
# bash 3.2 that ships with macOS, so every use is guarded by a count first.
pinned_all=()
if [ "${#BREW_PINNED_FORMULAE[@]}" -gt 0 ]; then
	pinned_all+=("${BREW_PINNED_FORMULAE[@]}")
fi
if [ "${#BREW_PINNED_CASKS[@]}" -gt 0 ]; then
	pinned_all+=("${BREW_PINNED_CASKS[@]}")
fi

if [ "${#pinned_all[@]}" -gt 0 ]; then
	log "holding back: ${pinned_all[*]}"
	if [ "${#BREW_PINNED_FORMULAE[@]}" -gt 0 ]; then
		pin_packages formula "${BREW_PINNED_FORMULAE[@]}"
	fi
	if [ "${#BREW_PINNED_CASKS[@]}" -gt 0 ]; then
		pin_packages cask "${BREW_PINNED_CASKS[@]}"
	fi
fi

log "upgrading everything else"
brew upgrade

log "syncing zsh framework and plugins"
install_zsh_framework

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
