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
	"zsh/zshrc|$HOME/.config/zsh/zshrc"
	"zsh/alias.common.zsh|$HOME/.config/zsh/alias.common.zsh"
	"zsh/alias.local.zsh|$HOME/.config/zsh/alias.local.zsh"
	"yabai|$HOME/.config/yabai"
	"skhd|$HOME/.config/skhd"
	"sketchybar|$HOME/.config/sketchybar"
	"ghostty|$HOME/.config/ghostty"
	"nvim|$HOME/.config/nvim"
	"herdr/config.toml|$HOME/.config/herdr/config.toml"
	"karabiner/karabiner.json|$HOME/.config/karabiner/karabiner.json"
	"$HOME/.config/zsh/zshrc|$HOME/.zshrc"
)

MANIFEST_REMOTE=(
	"starship.toml|$HOME/.config/starship.toml"
	"zsh/zshrc.remote|$HOME/.config/zsh/zshrc"
	"zsh/alias.common.zsh|$HOME/.config/zsh/alias.common.zsh"
	"zsh/alias.remote.zsh|$HOME/.config/zsh/alias.remote.zsh"
	"$HOME/.config/zsh/zshrc|$HOME/.zshrc"
)
