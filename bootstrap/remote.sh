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

HAVE_ZSH="${DOTFILES_HAVE_ZSH:-0}"

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

# neovim and tree-sitter have their own spellings too.
case "$arch" in
	aarch64) nvim_arch="arm64";  ts_arch="arm64" ;;
	x86_64)  nvim_arch="x86_64"; ts_arch="x64" ;;
	*)       nvim_arch="$arch";  ts_arch="$arch" ;;
esac
case "$os" in
	darwin) release_os="macos" ;;
	*)      release_os="$os" ;;
esac

# Neovim is not a single binary: the release tarball carries its runtime
# next to bin/, so unpack the whole tree under ~/.local/lib and link it in.
install_nvim() {
	local json tag latest current url tmp dest="$HOME/.local/lib/nvim"

	if ! json="$(gh_api "https://api.github.com/repos/neovim/neovim/releases/latest")"; then
		warn "GitHub API request for neovim/neovim failed; set GITHUB_TOKEN if rate limited"
		return 1
	fi

	tag="$(printf '%s\n' "$json" | json_field tag_name | head -n1)"
	latest="$(printf '%s\n' "$tag" | first_semver)"
	current="$(installed_version nvim)"
	if [ -n "$current" ] && [ "$current" = "$latest" ]; then
		log "nvim $current is up to date"
		return 0
	fi

	url="$(printf '%s\n' "$json" | json_field browser_download_url |
		grep -E "nvim-${release_os}-${nvim_arch}\\.tar\\.gz$" | head -n1)"
	if [ -z "$url" ]; then
		warn "no neovim asset in $tag for ${release_os}-${nvim_arch}"
		return 1
	fi

	tmp="$(mktemp -d)" || return 1
	if ! curl -fsSL "$url" | tar -xz -C "$tmp" --strip-components=1; then
		warn "download failed: $url"
		rm -rf "$tmp"
		return 1
	fi

	rm -rf "$dest"
	mv "$tmp" "$dest"
	ln -sfn "$dest/bin/nvim" "$INSTALL_DIR/nvim"
	hash -r 2>/dev/null || true
	log "installed nvim ${latest:-$tag}${current:+ (was $current)}"
}

mkdir -p "$INSTALL_DIR" "$HOME/.local/share" "$HOME/.local/lib"
export PATH="$INSTALL_DIR:$PATH"

# "No root" is what this profile is built for, but it is not a given either
# way: a DSW/devbox container often runs as root, and a cluster login node
# never does. Try the package manager, then fall back to a static build that
# needs no privileges at all. Has to run before install_zsh_framework, which
# skips oh-my-zsh when zsh is missing, and after PATH picks up INSTALL_DIR,
# which is where the static build lands.
if [ "$HAVE_ZSH" -eq 0 ]; then
	log "installing zsh"
	if install_system_zsh; then
		zsh_source="the system package manager"
	elif install_static_zsh; then
		zsh_source="a static build in $HOME/.local"
	else
		zsh_source=""
	fi

	hash -r
	if [ -n "$zsh_source" ] && have zsh; then
		HAVE_ZSH=1
		log "zsh $(zsh -c 'print -r -- $ZSH_VERSION' 2>/dev/null) via $zsh_source"
	else
		warn "could not install zsh"
		warn "the linked config will sit unused until zsh is available"
	fi
fi

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

install_nvim || failed+=(neovim)

# LazyVim builds treesitter parsers with this, plus whatever cc is around.
install_release_binary tree-sitter/tree-sitter tree-sitter \
	"/tree-sitter-${release_os}-${ts_arch}\\.gz$" || failed+=(tree-sitter)

log "installing nvm and node ${NODE_VERSION}"
install_nvm || failed+=(nvm)

# Pull plugins at the versions pinned in nvim/lazy-lock.json, so every box
# runs exactly what the workstation does. Mason tools are left to :Mason.
if have nvim; then
	log "restoring neovim plugins from lazy-lock.json"
	nvim --headless "+Lazy! restore" +qa >/dev/null 2>&1 || failed+=(nvim-plugins)
fi

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

	# PATH comes first: everything this profile installs lands in ~/.local/bin,
	# including zsh itself when it had to be a static build, and a bash login
	# shell has no reason to be looking there yet.
	block="$marker
case \":\$PATH:\" in
	*\":\$HOME/.local/bin:\"*) ;;
	*) PATH=\"\$HOME/.local/bin:\$PATH\"; export PATH ;;
esac

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
