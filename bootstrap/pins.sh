#!/usr/bin/env bash
# The exceptions to "always latest".
#
# Everything else in this repo deliberately tracks the newest release. These
# are held back on purpose, each with its reason, so the list stays short and
# reviewable rather than quietly accumulating.

# Node major version. The npm globals in the Brewfile live under this line and
# do not follow a major jump on their own.
NODE_VERSION="${NODE_VERSION:-22}"

# Held at their installed version. Both `brew upgrade` and the upgrade pass
# inside `brew bundle` skip pinned packages.
BREW_PINNED_FORMULAE=(
	# Hooks deep into undocumented macOS internals. Every bump can require
	# reinstalling the scripting addition and re-checking SIP, and tiling
	# regressions between releases are common.
	yabai
)

# `brew upgrade` also upgrades casks that declare auto_updates, so anything
# whose update is disruptive belongs here rather than being left to chance.
BREW_PINNED_CASKS=()
