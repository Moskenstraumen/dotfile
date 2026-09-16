# dotfiles

Configuration for two kinds of machine:

- **local** — the macOS workstation, where this repo is checked out at `~/.config`
  and most files are read in place.
- **remote** — login nodes, VPSes and containers, usually without root, where the
  repo is cloned anywhere and the files it needs are symlinked into `~/.config`.

## Usage

```sh
git clone git@github.com:Moskenstraumen/dotfile.git
cd dotfile
./setup.sh            # picks local on macOS, remote everywhere else
./setup.sh remote     # or force a profile
```

`setup.sh` derives the repo root from its own location, so the checkout can live
wherever is convenient on either side. Both profiles are idempotent — re-run them
to pick up new tool releases and newly added config files.

## Layout

```
setup.sh               profile dispatcher
bootstrap/
  common.sh            linking, version checks, GitHub release downloads
  manifest.sh          what gets symlinked where, per profile
  local.sh             macOS: Homebrew, config links, window manager services
  remote.sh            no-root: prebuilt binaries into ~/.local/bin
  Brewfile             the macOS package set
```

### Adding a config

Put the files in the repo, then add a `"source|target"` line to the right array
in `bootstrap/manifest.sh`. There is no shared list: `MANIFEST_LOCAL` and
`MANIFEST_REMOTE` each enumerate their environment in full, so a file that
belongs on both is listed twice. Reading either array tells you exactly what
that machine gets.

## What goes where

| | local | remote |
|---|---|---|
| `starship.toml` | yes | yes |
| `zsh/zshrc` | yes | — |
| `zsh/zshrc.remote` | — | yes (linked as `zsh/zshrc`) |
| `zsh/alias.common.zsh` | yes | yes |
| `zsh/alias.local.zsh` | yes | — |
| `zsh/alias.remote.zsh` | — | yes |
| `yabai` `skhd` `sketchybar` `karabiner` `otty` | yes | — |

The window manager, status bar and terminal are macOS-only and never reach a
remote box. The alias split matters: `alias.local.zsh` turns the proxy on
automatically when Clash is listening on 7890, which must not happen on a
cluster node.

### Proxies

`no_proxy` is set once per environment in the zshrc — loopback locally, the
cluster ranges on remote — and neither `proxy_on` nor `proxy_off` touches it.
Only the `http(s)_proxy` variables are toggled.

## Tools

The remote profile installs oh-my-zsh plus the autosuggestions and
syntax-highlighting plugins, and these prebuilt release binaries into
`~/.local/bin`:

| | |
|---|---|
| starship | prompt |
| ripgrep (`rg`) | content search |
| fd | filename search |
| lazygit | git TUI |
| zoxide | frecency jumps; takes over `cd` |
| fzf | fuzzy filter, Ctrl-R and Ctrl-T bindings |

It also installs nvm and the latest node LTS. nvm is a shell function rather
than a binary, so it is a git checkout on both sides; its installer is run with
`PROFILE=/dev/null` to stop it appending to the zshrc, which is a symlink into
this repo.

It does **not** install zsh itself — no root, no package manager — and warns
instead of failing when zsh is missing. There is no editor either; `vi` is
aliased to whatever system vim is present.

Static musl builds are preferred because remote glibc is often older than
release binaries expect. Each install compares the
published version against what is on `PATH` and reinstalls when it is behind, so
re-running the script actually updates rather than skipping.

Unauthenticated GitHub API calls are limited to 60/hour per IP, which a shared
login node may already have spent. Export `GITHUB_TOKEN` if downloads start
failing.

The local profile installs nvm first, because the Brewfile has `npm` entries
that need node on `PATH`, then everything else through `brew bundle` from
`bootstrap/Brewfile`; refresh it with `brew bundle dump --force --file
bootstrap/Brewfile`.

## Login shell

`chsh` needs zsh listed in `/etc/shells` and is refused outright on most
LDAP-managed cluster accounts, so the remote profile appends a guarded
hand-off to `~/.bash_profile` (or `~/.bash_login`, or `~/.profile` — whichever
bash would actually read) instead:

```sh
case $- in
	*i*)
		if [ -z "${ZSH_VERSION:-}" ] && [ -t 1 ] && command -v zsh >/dev/null 2>&1; then
			export SHELL="$(command -v zsh)"
			exec zsh -l
		fi
		;;
esac
```

The `$-` and `-t 1` guards mean it only fires for a real interactive login, so
`scp`, `rsync` and `ssh host cmd` keep working. It is fenced with markers and
only appended once.

## Pinned versions

Everything tracks the newest release except what is listed in
`bootstrap/pins.sh`, which records each exception and why. Today that is node
(held at a major version, since the Brewfile's `npm` globals do not follow a
major jump) and yabai (hooks into undocumented macOS internals; a bump can mean
reinstalling the scripting addition and re-checking SIP).

`brew bundle` upgrades by default, so the local profile runs it with
`--no-upgrade`, applies the pins, and only then runs `brew upgrade` — which
skips pinned packages. Casks can be pinned too, which matters because
`brew upgrade` also touches casks that declare `auto_updates`.

## Secrets

Never committed. Copy `zsh/secrets.zsh.example` to `~/.config/zsh/secrets.zsh`
and fill it in; both zshrcs source it when present, and it is gitignored.
