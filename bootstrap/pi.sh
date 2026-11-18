#!/usr/bin/env bash
# Link Pi configuration and install declared packages on first use;
# credentials and permission rules stay local.
set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
export DOTFILES_ROOT

# shellcheck source=bootstrap/common.sh
. "$DOTFILES_ROOT/bootstrap/common.sh"
# shellcheck source=bootstrap/manifest.sh
. "$DOTFILES_ROOT/bootstrap/manifest.sh"

if [ "${PI_CODING_AGENT_DIR+x}" = x ]; then
	warn 'ignoring inherited PI_CODING_AGENT_DIR; bootstrap uses ~/.pi/agent'
	unset PI_CODING_AGENT_DIR
fi

usage() {
	printf '%s\n' \
		'Usage: bash bootstrap/pi.sh' \
		'Links Pi configuration into ~/.pi/agent and installs declared packages if absent.'
}

if [ "$#" -gt 1 ]; then
	usage >&2
	exit 1
fi
case "${1:-auto}" in
	auto|interactive|mac|ali|stepmind) ;;
	-h|--help|help) usage; exit 0 ;;
	*) usage >&2; die "unexpected argument: $1" ;;
esac

PI_ROOT="$HOME/.pi/agent"

preflight_manifest() {
	local entry source
	for entry in "$@"; do
		source="$DOTFILES_ROOT/${entry%%|*}"
		if [ ! -f "$source" ] || [ -L "$source" ]; then
			die "$source: not a regular file in the checkout; nothing was linked"
		fi
	done
}

preflight_manifest ${MANIFEST_PI[@]+"${MANIFEST_PI[@]}"}

backup_path() {
	local base="$1.backup.$(date +%Y%m%d%H%M%S)" candidate suffix=0
	candidate="$base"
	while [ -e "$candidate" ] || [ -L "$candidate" ]; do
		suffix=$((suffix + 1))
		candidate="$base.$suffix"
	done
	printf '%s\n' "$candidate"
}

ensure_real_directory() {
	local dir="$1" backup
	if [ -L "$dir" ] || { [ -e "$dir" ] && [ ! -d "$dir" ]; }; then
		backup="$(backup_path "$dir")"
		mv "$dir" "$backup"
		log "backed up $dir -> $backup"
	fi
	mkdir -p "$dir"
}

ensure_real_directory "$PI_ROOT"
chmod 700 "$PI_ROOT"
ensure_real_directory "$PI_ROOT/skills/rex"
ensure_real_directory "$PI_ROOT/skills/rex-pane/scripts"

log "linking Pi config into $PI_ROOT"
apply_manifest ${MANIFEST_PI[@]+"${MANIFEST_PI[@]}"}

if have pi && [ ! -d "$PI_ROOT/npm/node_modules" ]; then
	log "installing declared Pi packages in $PI_ROOT"
	pi update --extensions --no-approve ||
		warn "could not install Pi packages in $PI_ROOT; retry when online"
elif ! have pi; then
	warn 'pi CLI is unavailable; run setup.sh to install it'
fi

if [ ! -f "$PI_ROOT/auth.json" ]; then
	log "no Pi credentials yet; open pi and use /login, or add gateway keys to $PI_ROOT/auth.json"
fi

for retired in \
	session-namer.json \
	mcp.json \
	mcp-auth.json \
	cliproxyapi.json \
	cliproxyapi-models.json \
	subagents.json \
	agents/reader.md \
	agents/thinker.md \
	agents/implementer.md \
	extensions/sanitize-antigravity-prompt.ts
do
	if [ -e "$PI_ROOT/$retired" ] || [ -L "$PI_ROOT/$retired" ]; then
		rm -f "$PI_ROOT/$retired"
	fi
done
rmdir "$PI_ROOT/agents" 2>/dev/null || true

for retired_dir in \
	"$HOME/.config/rex-superagent" \
	"$HOME/.local/share/rex-superagent" \
	"$HOME/.agents/skills/rex"
do
	if [ -e "$retired_dir" ] || [ -L "$retired_dir" ]; then
		rm -rf "$retired_dir"
	fi
done
rmdir "$HOME/.agents/skills" "$HOME/.agents" 2>/dev/null || true
