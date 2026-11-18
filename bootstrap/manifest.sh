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
	"pi/agent/AGENTS.md|$HOME/.gemini/config/AGENTS.md"
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
MANIFEST_PI=(
	"pi/agent/AGENTS.md|$HOME/.pi/agent/AGENTS.md"
	"pi/agent/WORKLOG.md|$HOME/.pi/agent/WORKLOG.md"
	"pi/agent/models.json|$HOME/.pi/agent/models.json"
	"pi/agent/settings.json|$HOME/.pi/agent/settings.json"
	"pi/agent/starline.json|$HOME/.pi/agent/starline.json"
	"pi/agent/web-search.json|$HOME/.pi/agent/web-search.json"
	"pi/agent/extensions/list-models.ts|$HOME/.pi/agent/extensions/list-models.ts"
	"pi/agent/extensions/session-cleanup.ts|$HOME/.pi/agent/extensions/session-cleanup.ts"
	"pi/agent/skills/rex/SKILL.md|$HOME/.pi/agent/skills/rex/SKILL.md"
)

# Orchestrator-only skills linked on the macOS entry point, never on remote workers.
MANIFEST_PI_LOCAL=(
	"pi/agent/skills/rex-pane/SKILL.md|$HOME/.pi/agent/skills/rex-pane/SKILL.md"
	"pi/agent/skills/rex-pane/scripts/rex-pane|$HOME/.pi/agent/skills/rex-pane/scripts/rex-pane"
	"pi/agent/skills/rex-pane/scripts/rex-pane.lua|$HOME/.pi/agent/skills/rex-pane/scripts/rex-pane.lua"
)
