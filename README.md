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
  pins.sh              the exceptions to "always latest", each with its reason
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
| `yabai` `skhd` `sketchybar` `karabiner` `ghostty` | yes | — |
| `herdr/config.toml` | yes | — |
| `herdr/config.remote.toml` | — | yes (linked as `herdr/config.toml`) |

The window manager, status bar and terminal are macOS-only and never reach a
remote box. The alias split matters: both alias files turn the proxy on
automatically when something is listening on 7890 (Clash locally, sing-box or
a forwarded tunnel on a remote), but they probe it differently — `nc` on macOS,
`ztcp` on remotes where `nc` may be missing — and only the local one carries the
workstation's `ssh` shortcuts.

### herdr

herdr splits its configuration in two, and the split decides which file a
setting belongs in:

| lives on the client | lives on the server |
|---|---|
| `[theme]`, `[keys]`, `[ui]`, copy behaviour, `[remote]` | `[terminal]`, `[server]`, worktrees, integrations, custom commands |

Theme and keybindings come from the machine you are sitting at, **even when
viewing an SSH machine**, so `herdr/config.toml` drives the UI on both sides and
the remote file holds only what belongs to the box running the panes.
`herdr/config.remote.toml` is therefore small on purpose: a `default_shell` that
skips the bash hand-off in `~/.profile` for new panes, and a wider headless
terminal so unattended agent output does not wrap at 120 columns.

The prefix is the one shared value that cannot drift: `herdr/config.toml` sets
`prefix = "ctrl+backslash"` and `ghostty/config` hardcodes that byte (`0x1c`) in
every `cmd+…` keybind. Change one and the other stops working.

### Proxies

`no_proxy` is set once per environment in the zshrc — loopback locally, the
cluster ranges on remote — and neither `proxy_on` nor `proxy_off` touches it.
Only the `http(s)_proxy` variables are toggled. Both lists also carry the
company domains `.basemind.com`, `.zyql.com` and `.stepfun-inc.com`: they answer
only direct connections, so routing them through 7890 makes requests to them —
including every model request — time out.

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
| neovim | editor; aliased to `vi` and `vim` |
| tree-sitter | parser CLI; `nvim-treesitter` shells out to it for `generate` and `build` |

It also installs nvm and the latest node LTS. nvm is a shell function rather
than a binary, so it is a git checkout on both sides; its installer is run with
`PROFILE=/dev/null` to stop it appending to the zshrc, which is a symlink into
this repo.

It does **not** install zsh itself — no root, no package manager — and warns
instead of failing when zsh is missing.

Neovim is not a single binary: the release tarball carries its runtime next to
`bin/`, so the remote profile unpacks the whole tree under `~/.local/lib/nvim`
and links `bin/nvim` into `~/.local/bin`. It then runs
`nvim --headless "+Lazy! restore"` to pull plugins at the versions recorded in
`nvim/lazy-lock.json`, so every box runs what the workstation runs. Mason tools
are left to `:Mason`.

Treesitter parsers themselves are neither installed nor pinned here. LazyVim
builds the ones in its `ensure_installed` list on first use, into
`~/.local/share/nvim/site/parser/`, using the C compiler and the `tree-sitter`
binary above. They are per-machine build artifacts, so a box that has seen more
filetypes will have more of them than one that has not: that is expected, and
`:TSInstall <lang>` fills the gap rather than anything in this repo. Because
the CLI is already on `PATH` here, LazyVim skips its own fallback of fetching
`tree-sitter-cli` through mason at runtime.

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
