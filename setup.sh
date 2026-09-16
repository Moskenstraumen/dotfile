#!/usr/bin/env bash
# Entry point for both environments.
#
#   ./setup.sh          pick the profile from the OS
#   ./setup.sh local    macOS workstation (Homebrew, window manager, otty)
#   ./setup.sh remote   no-root box: binaries into ~/.local/bin only
#
# The repo root is derived from this script, so the checkout can live
# anywhere on either side.
set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_ROOT

usage() {
	sed -n '2,9p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

profile="${1:-auto}"
case "$profile" in
	auto)
		if [ "$(uname -s)" = "Darwin" ]; then profile=local; else profile=remote; fi
		;;
	local|remote) ;;
	-h|--help|help) usage; exit 0 ;;
	*) usage >&2; exit 1 ;;
esac

# zsh is what everything here configures, so say it once at the entry point
# rather than in each profile. Not fatal either way: the remote profile cannot
# install zsh without root, and the binaries it fetches are useful regardless.
if command -v zsh >/dev/null 2>&1; then
	DOTFILES_HAVE_ZSH=1
else
	DOTFILES_HAVE_ZSH=0
	printf '\033[1;33mwarn:\033[0m zsh is not installed\n' >&2
	printf '\033[1;33mwarn:\033[0m the linked config will sit unused until it is\n' >&2
fi
export DOTFILES_HAVE_ZSH

exec bash "$DOTFILES_ROOT/bootstrap/$profile.sh"
