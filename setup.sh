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

exec bash "$DOTFILES_ROOT/bootstrap/$profile.sh"
