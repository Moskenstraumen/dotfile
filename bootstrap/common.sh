#!/usr/bin/env bash
# Helpers shared by bootstrap/local.sh and bootstrap/remote.sh.
# This file is sourced, never executed directly.

: "${DOTFILES_ROOT:?DOTFILES_ROOT must be set before sourcing common.sh}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarn:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

require() {
	local cmd
	for cmd in "$@"; do
		have "$cmd" || die "$cmd is required but not installed"
	done
}

platform_os() { uname -s | tr '[:upper:]' '[:lower:]'; }

platform_arch() {
	case "$(uname -m)" in
		x86_64|amd64) echo x86_64 ;;
		aarch64|arm64) echo aarch64 ;;
		*) uname -m ;;
	esac
}

# Absolute path of $1, which need not exist yet.
abspath() {
	local path="$1" dir base
	if [ -d "$path" ]; then
		(cd "$path" && pwd)
		return
	fi
	dir="$(dirname "$path")"
	base="$(basename "$path")"
	dir="$(cd "$dir" 2>/dev/null && pwd || printf '%s' "$dir")"
	printf '%s/%s\n' "${dir%/}" "$base"
}

# Symlink $1 to $2, backing up anything real already sitting at $2.
link_managed_path() {
	local source="$1" target="$2" backup

	if [ ! -e "$source" ]; then
		warn "skipping $target: $source does not exist"
		return
	fi

	# The repo is checked out at the target path already; nothing to link.
	if [ "$(abspath "$source")" = "$(abspath "$target")" ]; then
		return
	fi

	mkdir -p "$(dirname "$target")"

	if [ -L "$target" ]; then
		ln -sfn "$source" "$target"
		return
	fi

	if [ -e "$target" ]; then
		backup="${target}.backup.$(date +%Y%m%d%H%M%S)"
		mv "$target" "$backup"
		log "backed up $target -> $backup"
	fi

	ln -s "$source" "$target"
	log "linked $target -> $source"
}

# Link every "source|target" entry passed in. Relative sources resolve
# against DOTFILES_ROOT so the repo works from any checkout location.
apply_manifest() {
	local entry source target
	for entry in "$@"; do
		source="${entry%%|*}"
		target="${entry#*|}"
		case "$source" in
			/*) ;;
			*) source="$DOTFILES_ROOT/$source" ;;
		esac
		link_managed_path "$source" "$target"
	done
}

first_semver() { grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -n1; }

# Version of an installed binary, empty if absent or unparseable.
installed_version() {
	local bin="$1"
	have "$bin" || return 0
	"$bin" --version 2>/dev/null | head -n3 | first_semver
}

gh_api() {
	if [ -n "${GITHUB_TOKEN:-}" ]; then
		curl -fsSL -H "Authorization: Bearer $GITHUB_TOKEN" "$1"
	else
		curl -fsSL "$1"
	fi
}

json_field() { sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p"; }

# install_release_binary <owner/repo> <binary> <asset-regex>...
# Installs into INSTALL_DIR, but only when the published release is newer
# than what is already on PATH. Unversioned or unparseable installs are
# always replaced, so "latest" stays true even for odd --version output.
# Extra regexes are fallbacks, tried in order, so callers can prefer a
# static musl build and settle for glibc when a project ships only that.
install_release_binary() {
	local repo="$1" bin="$2"
	shift 2
	local patterns=("$@")
	local json tag latest current url tmp found resolved pattern

	if ! json="$(gh_api "https://api.github.com/repos/$repo/releases/latest")"; then
		warn "GitHub API request for $repo failed; set GITHUB_TOKEN if rate limited"
		return 1
	fi

	tag="$(printf '%s\n' "$json" | json_field tag_name | head -n1)"
	latest="$(printf '%s\n' "$tag" | first_semver)"
	current="$(installed_version "$bin")"

	if [ -n "$current" ] && [ -n "$latest" ] && [ "$current" = "$latest" ]; then
		log "$bin $current is up to date"
		return 0
	fi

	for pattern in "${patterns[@]}"; do
		url="$(printf '%s\n' "$json" | json_field browser_download_url | grep -Ei "$pattern" | head -n1)"
		[ -n "$url" ] && break
	done
	if [ -z "$url" ]; then
		warn "no $repo asset in $tag matched: ${patterns[*]}"
		return 1
	fi

	tmp="$(mktemp -d)" || return 1
	if ! curl -fsSL "$url" -o "$tmp/asset"; then
		warn "download failed: $url"
		rm -rf "$tmp"
		return 1
	fi

	case "$url" in
		*.tar.gz|*.tgz) tar -xzf "$tmp/asset" -C "$tmp" ;;
		*.tar.xz)       tar -xJf "$tmp/asset" -C "$tmp" ;;
		*.zip)          unzip -qo "$tmp/asset" -d "$tmp" ;;
		*)              mv "$tmp/asset" "$tmp/$bin" ;;
	esac

	found="$(find "$tmp" -type f -name "$bin" -print 2>/dev/null | head -n1)"
	if [ -z "$found" ]; then
		warn "no $bin binary inside $url"
		rm -rf "$tmp"
		return 1
	fi

	mkdir -p "$INSTALL_DIR"
	install -m 0755 "$found" "$INSTALL_DIR/$bin"
	rm -rf "$tmp"
	hash -r 2>/dev/null || true
	log "installed $bin ${latest:-$tag}${current:+ (was $current)}"

	resolved="$(command -v "$bin" 2>/dev/null || true)"
	if [ -n "$resolved" ] && [ "$resolved" != "$INSTALL_DIR/$bin" ]; then
		warn "$resolved shadows $INSTALL_DIR/$bin; put $INSTALL_DIR earlier in PATH"
	fi
}

# oh-my-zsh and its plugins are git checkouts on both sides: Homebrew does
# not package them, so the macOS profile needs this just as much as remote.
install_zsh_framework() {
	local custom

	# The oh-my-zsh installer refuses to run without zsh on PATH, so there is
	# nothing to do here on a box that has none.
	if ! have zsh; then
		warn "skipping oh-my-zsh: zsh is not installed"
		return
	fi

	# ZSH must be set explicitly: the installer aborts if it inherits an
	# exported ZSH from the calling shell, which every zshrc here sets.
	# Failure is warned about, not fatal, so the tools below still install.
	if [ ! -d "$HOME/.oh-my-zsh" ]; then
		ZSH="$HOME/.oh-my-zsh" RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c \
			"$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" ||
			warn "oh-my-zsh install failed"
	else
		git -C "$HOME/.oh-my-zsh" pull --ff-only --quiet 2>/dev/null ||
			warn "could not update oh-my-zsh"
	fi

	custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
	sync_git_repo https://github.com/zsh-users/zsh-autosuggestions "$custom/plugins/zsh-autosuggestions"
	sync_git_repo https://github.com/zsh-users/zsh-syntax-highlighting "$custom/plugins/zsh-syntax-highlighting"
}

# nvm is a shell function, not a binary, so it is a git checkout on both
# sides. PROFILE=/dev/null stops its installer appending to the zshrc,
# which is a symlink into this repo.
install_nvm() {
	local tag version="${NODE_VERSION:-22}"
	# Pinned to $HOME, not inherited: honouring an exported NVM_DIR makes this
	# install into whatever nvm the calling shell already had, which is the
	# wrong target whenever HOME has been overridden.
	export NVM_DIR="$HOME/.nvm"

	if ! tag="$(gh_api https://api.github.com/repos/nvm-sh/nvm/releases/latest | json_field tag_name | head -n1)" ||
		[ -z "$tag" ]; then
		warn "could not determine the latest nvm release"
		return 1
	fi

	if [ -s "$NVM_DIR/nvm.sh" ]; then
		if [ -d "$NVM_DIR/.git" ]; then
			git -C "$NVM_DIR" fetch --tags --quiet origin 2>/dev/null &&
				git -C "$NVM_DIR" checkout --quiet "$tag" 2>/dev/null ||
				warn "could not update nvm to $tag"
		fi
	else
		curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/$tag/install.sh" |
			PROFILE=/dev/null bash >/dev/null || {
			warn "nvm install failed"
			return 1
		}
	fi

	# shellcheck source=/dev/null
	. "$NVM_DIR/nvm.sh"

	# Deliberately no --reinstall-packages-from: globals are declared in the
	# Brewfile's npm entries, so a new node starts clean and brew bundle puts
	# back exactly what is meant to be there, not whatever accumulated.
	if nvm install "$version" >/dev/null 2>&1; then
		nvm alias default "$version" >/dev/null 2>&1 || true
		log "node $(node --version 2>/dev/null) (pinned to $version) via nvm $tag"
	else
		warn "could not install node $version"
	fi
}

# Clone $1 into $2, or fast-forward it if it is already there.
sync_git_repo() {
	local url="$1" dest="$2"
	if [ -d "$dest/.git" ]; then
		git -C "$dest" pull --ff-only --quiet 2>/dev/null ||
			warn "could not update $dest"
	elif [ -e "$dest" ]; then
		warn "skipping $dest: exists but is not a git checkout"
	else
		git clone --depth=1 --quiet "$url" "$dest"
		log "cloned $(basename "$dest")"
	fi
}
