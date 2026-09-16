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

require curl git tar

# zsh is not installable without root, so its absence is a warning rather
# than a failure: the binaries below are still worth having.
if have zsh; then
	HAVE_ZSH=1
else
	HAVE_ZSH=0
	warn "zsh is not installed and this profile cannot install it without root"
	warn "the linked config will sit unused until zsh is available"
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

# lazygit names assets by os and arch rather than by target triple.
case "$arch" in
	aarch64) lazygit_arch="arm64" ;;
	*)       lazygit_arch="$arch" ;;
esac

mkdir -p "$INSTALL_DIR" "$HOME/.local/share" "$HOME/.local/lib"
export PATH="$INSTALL_DIR:$PATH"

log "linking configuration"
apply_manifest "${MANIFEST_REMOTE[@]}"

log "syncing zsh plugins"
if [ ! -d "$HOME/.oh-my-zsh" ]; then
	RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c \
		"$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
	git -C "$HOME/.oh-my-zsh" pull --ff-only --quiet 2>/dev/null ||
		warn "could not update oh-my-zsh"
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
sync_git_repo https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
sync_git_repo https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

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
