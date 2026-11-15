# dotfiles

Configuration for the macOS workstation, read in place from `~/.config`, and for
remote hosts, where the repo is cloned anywhere and its files are symlinked
into place.

## Usage

```sh
git clone git@github.com:Moskenstraumen/dotfile.git
cd dotfile
./setup.sh            # local on macOS, remote everywhere else
./setup.sh remote     # force a profile
```

`setup.sh` derives the repo root from its own location, so the checkout can live
wherever is convenient. Both profiles are idempotent.

## Layout

```
setup.sh               profile dispatcher
bootstrap/
  common.sh            linking, version checks, release downloads
  manifest.sh          what gets symlinked where, per profile
  pins.sh              the version exceptions, each with its reason
  local.sh             macOS: Homebrew, config links, window manager services
  remote.sh            no-root: prebuilt binaries into ~/.local/bin
  Brewfile             the macOS package set
zsh/                   zshenv, zshrc and alias splits
skhd/ yabai/ sketchybar/ karabiner/   macOS window setup
nvim/                  LazyVim config and lazy-lock.json
starship.toml          prompt
```

`local` files apply to this Mac only, `remote` files to any server. Both
profiles are enumerated in full in `bootstrap/manifest.sh`, where each entry
links one `source|target` pair, so adding a config file means adding a line to
the relevant array.

Secrets template: `zsh/secrets.zsh.example` → `zsh/secrets.zsh`.
