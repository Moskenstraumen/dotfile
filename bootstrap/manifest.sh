#!/usr/bin/env bash
# What gets linked where, per environment.
#
# Each entry is "source|target". Relative sources resolve against the repo
# root, so the checkout can live anywhere. Linking something onto itself is
# a no-op, which is what happens locally where the repo is ~/.config.
#
# There is deliberately no shared list: every environment enumerates its own
# files in full, so you can read either array and know exactly what that
# machine gets without cross-referencing the other.
#
# The MANIFEST_PI_* arrays are separate on purpose: both setup profiles call
# bootstrap/pi.sh, which preflights and links these agent directories separately
# from the generic MANIFEST_LOCAL and MANIFEST_REMOTE config.

MANIFEST_LOCAL=(
	"starship.toml|$HOME/.config/starship.toml"
	"zsh/zshrc.local|$HOME/.zshrc"
	"zsh/zshenv.local|$HOME/.zshenv"
	"zsh/alias.common.zsh|$HOME/.config/zsh/alias.common.zsh"
	"zsh/alias.local.zsh|$HOME/.config/zsh/alias.local.zsh"
	"yabai|$HOME/.config/yabai"
	"skhd|$HOME/.config/skhd"
	"sketchybar|$HOME/.config/sketchybar"
	"nvim|$HOME/.config/nvim"
	"karabiner/karabiner.json|$HOME/.config/karabiner/karabiner.json"
)

MANIFEST_REMOTE=(
	"starship.toml|$HOME/.config/starship.toml"
	"zsh/zshrc.remote|$HOME/.zshrc"
	"zsh/zshenv.remote|$HOME/.zshenv"
	"zsh/alias.common.zsh|$HOME/.config/zsh/alias.common.zsh"
	"zsh/alias.remote.zsh|$HOME/.config/zsh/alias.remote.zsh"
	"nvim|$HOME/.config/nvim"
)

# Declarative leaves only; credentials, installed packages and runtime state stay local.
MANIFEST_PI_INTERACTIVE=(
	"pi/agent/models.json|$HOME/.pi/agent/models.json"
	"pi/agent/starline.json|$HOME/.pi/agent/starline.json"
	"pi/agent/subagents.json|$HOME/.pi/agent/subagents.json"
	"pi/agent/extensions/list-models.ts|$HOME/.pi/agent/extensions/list-models.ts"
	"pi/agent/extensions/session-cleanup.ts|$HOME/.pi/agent/extensions/session-cleanup.ts"
	"pi/agent/AGENTS.md|$HOME/.pi/agent/AGENTS.md"
	"pi/agent/settings.json|$HOME/.pi/agent/settings.json"
	"pi/agent/web-search.json|$HOME/.pi/agent/web-search.json"
	"pi/agent/agents/reader.md|$HOME/.pi/agent/agents/reader.md"
	"pi/agent/agents/thinker.md|$HOME/.pi/agent/agents/thinker.md"
	"pi/agent/agents/implementer.md|$HOME/.pi/agent/agents/implementer.md"
	"pi/agent/skills/rex/SKILL.md|$HOME/.pi/agent/skills/rex/SKILL.md"
)

MANIFEST_PI_REX_SUPERAGENT=(
	"pi/agent/models.json|$HOME/.local/share/rex-superagent/pi/agent/models.json"
	"pi/agent/starline.json|$HOME/.local/share/rex-superagent/pi/agent/starline.json"
	"pi/agent/subagents.json|$HOME/.local/share/rex-superagent/pi/agent/subagents.json"
	"pi/agent/extensions/list-models.ts|$HOME/.local/share/rex-superagent/pi/agent/extensions/list-models.ts"
	"pi/agent/extensions/session-cleanup.ts|$HOME/.local/share/rex-superagent/pi/agent/extensions/session-cleanup.ts"
	"rex-superagent/pi/agent/settings.json|$HOME/.local/share/rex-superagent/pi/agent/settings.json"
	"rex-superagent/pi/agent/web-search.json|$HOME/.local/share/rex-superagent/pi/agent/web-search.json"
	"rex-superagent/pi/agent/agents/reader.md|$HOME/.local/share/rex-superagent/pi/agent/agents/reader.md"
	"rex-superagent/pi/agent/agents/thinker.md|$HOME/.local/share/rex-superagent/pi/agent/agents/thinker.md"
	"rex-superagent/pi/agent/agents/implementer.md|$HOME/.local/share/rex-superagent/pi/agent/agents/implementer.md"
	"pi/agent/skills/rex/SKILL.md|$HOME/.local/share/rex-superagent/pi/agent/skills/rex/SKILL.md"
)
