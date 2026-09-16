#!/usr/bin/env bash
# Bootstrap a remote box (login node, VPS, container) with no root access.
#
# Everything lands under $HOME/.local, and every tool is fetched as a
# prebuilt release binary rather than compiled, so this stays usable on a
# shared node with no toolchain and a strict time budget.
set -euo pipefail

: "${DOTFILES_ROOT:?run this through setup.sh}"
. "$DOTFILES_ROOT/bootstrap/common.sh"
. "$DOTFILES_ROOT/bootstrap/manifest.sh"
. "$DOTFILES_ROOT/bootstrap/pins.sh"

require curl git tar

# setup.sh has already checked and warned; this profile only needs the answer,
# to decide whether writing the login hand-off below is worth anything.
HAVE_ZSH="${DOTFILES_HAVE_ZSH:-0}"
if [ "$HAVE_ZSH" -eq 0 ]; then
	warn "this profile cannot install zsh without root"
fi

os="$(platform_os)"
arch="$(platform_arch)"

# Prefer statically linked musl builds: remote glibc is often older than the
# release binaries expect. Fall back to gnu where musl is not published.
case "$os" in
	linux)
		triple_first="${arch}-unknown-linux-musl"
		triple_then="${arch}-unknown-linux-gnu"
		;;
	darwin)
		triple_first="${arch}-apple-darwin"
		triple_then="${arch}-apple-darwin"
		;;
	*) die "unsupported OS for the remote profile: $os" ;;
esac

# lazygit and fzf name assets by os and arch rather than by target triple,
# and disagree with each other about what to call x86_64.
case "$arch" in
	aarch64) lazygit_arch="arm64";  go_arch="arm64" ;;
	x86_64)  lazygit_arch="x86_64"; go_arch="amd64" ;;
	*)       lazygit_arch="$arch";  go_arch="$arch" ;;
esac

mkdir -p "$INSTALL_DIR" "$HOME/.local/share" "$HOME/.local/lib"
export PATH="$INSTALL_DIR:$PATH"

log "linking configuration"
apply_manifest "${MANIFEST_REMOTE[@]}"

log "syncing zsh framework and plugins"
install_zsh_framework

log "installing tools into $INSTALL_DIR"
failed=()

install_release_binary starship/starship starship \
	"starship-${triple_first}\\.tar\\.gz$" \
	"starship-${triple_then}\\.tar\\.gz$" || failed+=(starship)

install_release_binary BurntSushi/ripgrep rg \
	"ripgrep-[^/]+-${triple_first}\\.tar\\.gz$" \
	"ripgrep-[^/]+-${triple_then}\\.tar\\.gz$" || failed+=(ripgrep)

install_release_binary sharkdp/fd fd \
	"fd-[^/]+-${triple_first}\\.tar\\.gz$" \
	"fd-[^/]+-${triple_then}\\.tar\\.gz$" || failed+=(fd)

install_release_binary jesseduffield/lazygit lazygit \
	"lazygit_[^/]+_${os}_${lazygit_arch}\\.tar\\.gz$" || failed+=(lazygit)

install_release_binary ajeetdsouza/zoxide zoxide \
	"zoxide-[^/]+-${triple_first}\\.tar\\.gz$" \
	"zoxide-[^/]+-${triple_then}\\.tar\\.gz$" || failed+=(zoxide)

install_release_binary junegunn/fzf fzf \
	"fzf-[^/]+-${os}_${go_arch}\\.tar\\.gz$" || failed+=(fzf)

log "installing nvm and node ${NODE_VERSION}"
install_nvm || failed+=(nvm)

if [ "${#failed[@]}" -gt 0 ]; then
	warn "could not install: ${failed[*]}"
	warn "re-run after setting GITHUB_TOKEN if this was an API rate limit"
fi

# chsh needs zsh listed in /etc/shells and is refused outright on most
# LDAP-managed cluster accounts, so hand off from the bash startup file
# instead. The guard skips non-interactive shells, which is what keeps
# scp, rsync and `ssh host cmd` working.
prefer_zsh_at_login() {
	local target marker block

	if [ -f "$HOME/.bash_profile" ]; then
		target="$HOME/.bash_profile"
	elif [ -f "$HOME/.bash_login" ]; then
		target="$HOME/.bash_login"
	else
		target="$HOME/.profile"
	fi

	marker="# >>> dotfiles: prefer zsh >>>"
	if [ -f "$target" ] && grep -Fq "$marker" "$target"; then
		log "login shell already hands off to zsh via $(basename "$target")"
		return
	fi

	block="$marker
case \$- in
	*i*)
		if [ -z \"\${ZSH_VERSION:-}\" ] && [ -t 1 ] && command -v zsh >/dev/null 2>&1; then
			export SHELL=\"\$(command -v zsh)\"
			exec zsh -l
		fi
		;;
esac
# <<< dotfiles: prefer zsh <<<"

	printf '\n%s\n' "$block" >> "$target"
	log "added a zsh hand-off to $(basename "$target")"
}

if [ "$HAVE_ZSH" -eq 1 ]; then
	prefer_zsh_at_login
fi

if [ ! -f "$HOME/.config/zsh/secrets.zsh" ]; then
	log "no secrets file yet; copy zsh/secrets.zsh.example to ~/.config/zsh/secrets.zsh"
fi

log "done — restart your shell or run: exec zsh"
