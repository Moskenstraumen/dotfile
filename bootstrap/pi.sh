#!/usr/bin/env bash
# Link interactive Pi and, on configured hosts, isolated rex-superagent Pi.
# Install declared packages on first use; credentials and permission rules stay local.
set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
export DOTFILES_ROOT

# shellcheck source=bootstrap/common.sh
. "$DOTFILES_ROOT/bootstrap/common.sh"
# shellcheck source=bootstrap/manifest.sh
. "$DOTFILES_ROOT/bootstrap/manifest.sh"

if [ "${PI_CODING_AGENT_DIR+x}" = x ]; then
	warn 'ignoring inherited PI_CODING_AGENT_DIR; bootstrap uses its fixed agent directories'
	unset PI_CODING_AGENT_DIR
fi

usage() {
	printf '%s\n' \
		'Usage: bash bootstrap/pi.sh [auto|interactive|mac|ali|stepmind]' \
		'  auto (default): detect a configured host, otherwise interactive-only' \
		'  interactive: configure ~/.pi/agent only' \
		'Links Pi configuration and installs declared packages if their npm tree is absent.'
}

[ "$#" -le 1 ] || { usage >&2; exit 1; }
requested_host="${1:-auto}"
host="$requested_host"
case "$host" in
	auto)
		if [ "$(uname -s)" = Darwin ]; then
			host=mac
		elif [ -d /mnt/cpfs/xuyucheng-fileset ]; then
			host=ali
		elif [ -d /data/projects ]; then
			host=stepmind
		else
			host=generic
		fi
		;;
	interactive|mac|ali|stepmind) ;;
	-h|--help|help) usage; exit 0 ;;
	*) usage >&2; die "unknown host: $host (expected auto, interactive, mac, ali, or stepmind)" ;;
esac

PI_ROOT="$HOME/.pi/agent"
REX_SUPERAGENT_PI_ROOT="$HOME/.local/share/rex-superagent/pi/agent"
REX_SUPERAGENT_CONFIG_ROOT="$HOME/.config/rex-superagent"
HOST_CONFIG=""
case "$host" in
	mac|ali|stepmind) HOST_CONFIG="$DOTFILES_ROOT/rex-superagent/hosts/$host.bootstrap.json" ;;
esac

preflight_manifest() {
	local entry source
	for entry in "$@"; do
		source="$DOTFILES_ROOT/${entry%%|*}"
		if [ ! -f "$source" ] || [ -L "$source" ]; then
			die "$source: not a regular file in the checkout; nothing was linked"
		fi
	done
}

# The + guards are needed for empty arrays under macOS bash 3.2 with nounset.
preflight_manifest ${MANIFEST_PI_INTERACTIVE[@]+"${MANIFEST_PI_INTERACTIVE[@]}"}
if [ -n "$HOST_CONFIG" ]; then
	if [ ! -f "$HOST_CONFIG" ] || [ -L "$HOST_CONFIG" ]; then
		if [ "$requested_host" = auto ] && [ ! -e "$HOST_CONFIG" ] && [ ! -L "$HOST_CONFIG" ]; then
			warn "$HOST_CONFIG is absent; configuring interactive Pi only"
			host=generic
			HOST_CONFIG=""
		else
			die "$HOST_CONFIG: not a regular file in the checkout; nothing was linked"
		fi
	else
		preflight_manifest ${MANIFEST_PI_REX_SUPERAGENT[@]+"${MANIFEST_PI_REX_SUPERAGENT[@]}"}
	fi
fi

# Give each backup a unique name, including repeated runs in the same second.
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

materialize_tmp=""
trap 'if [ -n "$materialize_tmp" ]; then rm -f "$materialize_tmp"; fi' EXIT

# Atomic writers replace symlinks, and bootstrap.json is opened with O_NOFOLLOW.
materialize_regular_file() {
	local source="$1" target="$2" backup
	if [ -f "$target" ] && [ ! -L "$target" ] && cmp -s "$source" "$target"; then
		chmod 600 "$target"
		return
	fi
	if [ -e "$target" ] && [ ! -L "$target" ] && [ ! -f "$target" ]; then
		die "$target: not a regular file; refusing to replace it"
	fi
	materialize_tmp="$(mktemp "$(dirname "$target")/.$(basename "$target").XXXXXX")"
	cp "$source" "$materialize_tmp"
	chmod 600 "$materialize_tmp"
	if [ -f "$target" ] && [ ! -L "$target" ]; then
		backup="$(backup_path "$target")"
		cp -p "$target" "$backup"
		log "backed up $target -> $backup"
	fi
	if [ -L "$target" ]; then
		rm -f "$target"
	fi
	mv -f "$materialize_tmp" "$target"
	materialize_tmp=""
	log "materialized $target"
}

install_declared_packages() {
	local root="$1"
	if ! have pi; then
		warn 'pi CLI is unavailable; run setup.sh to install it'
		return 0
	fi
	[ ! -d "$root/npm/node_modules" ] || return 0
	log "installing declared Pi packages in $root"
	if [ "$root" = "$PI_ROOT" ]; then
		(unset PI_CODING_AGENT_DIR; pi update --extensions --no-approve) ||
			warn "could not install Pi packages in $root; retry when online"
	else
		PI_CODING_AGENT_DIR="$root" pi update --extensions --no-approve ||
			warn "could not install Pi packages in $root; retry when online"
	fi
}

ensure_real_directory "$PI_ROOT"
chmod 700 "$PI_ROOT"
ensure_real_directory "$PI_ROOT/skills/rex"
log "linking interactive Pi config into $PI_ROOT"
apply_manifest ${MANIFEST_PI_INTERACTIVE[@]+"${MANIFEST_PI_INTERACTIVE[@]}"}
install_declared_packages "$PI_ROOT"
if [ ! -f "$PI_ROOT/auth.json" ] && [ ! -f "$PI_ROOT/cliproxyapi.json" ]; then
	log "no Pi credentials yet; open pi and use /login, or copy cliproxyapi.json to $PI_ROOT/"
fi

agent_roots=("$PI_ROOT")
if [ -n "$HOST_CONFIG" ]; then
	for root in "$HOME/.local/share/rex-superagent/pi" "$REX_SUPERAGENT_PI_ROOT" "$REX_SUPERAGENT_CONFIG_ROOT"; do
		ensure_real_directory "$root"
		chmod 700 "$root"
	done
	agent_roots+=("$REX_SUPERAGENT_PI_ROOT")

	# Keep permission logs and the skill container local to each agentDir.
	ensure_real_directory "$REX_SUPERAGENT_PI_ROOT/extensions/pi-permission-system"
	ensure_real_directory "$REX_SUPERAGENT_PI_ROOT/skills"
	ensure_real_directory "$REX_SUPERAGENT_PI_ROOT/skills/rex"
	log "linking $host rex-superagent Pi config into $REX_SUPERAGENT_PI_ROOT"
	apply_manifest ${MANIFEST_PI_REX_SUPERAGENT[@]+"${MANIFEST_PI_REX_SUPERAGENT[@]}"}

	for credential in auth.json cliproxyapi.json; do
		if [ -f "$PI_ROOT/$credential" ]; then
			link_managed_path "$PI_ROOT/$credential" "$REX_SUPERAGENT_PI_ROOT/$credential"
		fi
	done
	permission_config="extensions/pi-permission-system/config.json"
	if [ -f "$PI_ROOT/$permission_config" ]; then
		materialize_regular_file "$PI_ROOT/$permission_config" "$REX_SUPERAGENT_PI_ROOT/$permission_config"
	fi

	# Seed the initial model catalog without sharing subsequent mutable snapshots.
	if [ -s "$PI_ROOT/models-store.json" ] && {
		[ ! -e "$REX_SUPERAGENT_PI_ROOT/models-store.json" ] ||
		[ "$(wc -c < "$REX_SUPERAGENT_PI_ROOT/models-store.json")" -lt 16 ]
	}; then
		materialize_regular_file "$PI_ROOT/models-store.json" "$REX_SUPERAGENT_PI_ROOT/models-store.json"
	fi

	for skill_link in "$REX_SUPERAGENT_PI_ROOT"/skills/*; do
		if [ -L "$skill_link" ] && [ ! -e "$skill_link" ]; then
			rm -f "$skill_link"
		fi
	done
	for skill_dir in "$PI_ROOT"/skills/*; do
		[ -d "$skill_dir" ] || continue
		skill="$(basename "$skill_dir")"
		[ "$skill" = rex ] && continue
		link_managed_path "$skill_dir" "$REX_SUPERAGENT_PI_ROOT/skills/$skill"
	done

	# bootstrap.json must be a 0600 regular file: rex-superagent uses O_NOFOLLOW.
	materialize_regular_file "$HOST_CONFIG" "$REX_SUPERAGENT_CONFIG_ROOT/bootstrap.json"
	install_declared_packages "$REX_SUPERAGENT_PI_ROOT"
else
	log "configured interactive $PI_ROOT only; no rex-superagent host config matched ($host)"
fi

for root in "${agent_roots[@]}"; do
	for retired in session-namer.json mcp.json mcp-auth.json extensions/sanitize-antigravity-prompt.ts; do
		if [ -e "$root/$retired" ] || [ -L "$root/$retired" ]; then
			rm -f "$root/$retired"
		fi
	done
done
if [ -e "$HOME/.agents/skills/rex" ] || [ -L "$HOME/.agents/skills/rex" ]; then
	rm -rf "$HOME/.agents/skills/rex"
fi
rmdir "$HOME/.agents/skills" "$HOME/.agents" 2>/dev/null || true
