# dotfiles

Shared workstation and remote-server configuration. On macOS the repository
lives directly at `~/.config`; on remote Linux boxes it can be cloned anywhere
and symlinked into place.

## Usage

```sh
git clone git@github.com:Moskenstraumen/dotfile.git
cd dotfile
./setup.sh                  # auto: local on macOS, remote everywhere else
bash setup.sh --local       # force macOS workstation profile
bash setup.sh --remote      # force no-root remote profile
bash bootstrap/pi.sh        # re-link Pi config only
```

Both profiles install Node (via `nvm`) and Pi when missing, link shell/editor/agent
configuration, and install declared Pi packages on first use. Credentials,
permission rules, installed packages, and host-specific skills stay local to
each machine.

## Layout

```text
setup.sh               profile dispatcher
bootstrap/
  common.sh            shared helpers, linking, GitHub release installer
  manifest.sh          per-profile symlink manifests (MANIFEST_LOCAL / REMOTE / PI)
  pins.sh              explicit version holds (Node major, yabai)
  local.sh             macOS: Homebrew bundle, config links, window manager services
  remote.sh            Linux no-root: static/release binaries into ~/.local/bin
  pi.sh                Pi config linking and first-use package bootstrap
  Brewfile             macOS packages, casks, and global npm CLIs
zsh/                   zshenv, zshrc, and common/local/remote aliases
nvim/                  LazyVim config and lazy-lock.json
starship.toml          shell prompt
yabai/ skhd/ sketchybar/ karabiner/   macOS window management and status bar
pi/
  .gitignore           explicit allowlist for declarative agent config
  agent/
    AGENTS.md          global instructions (linked to ~/.pi/agent and ~/.gemini/config)
    WORKLOG.md         Feishu research category index and recording rules
    models.json        gateway cache/thinking overrides atop list-models.ts
    settings.json      default provider/model, tools, and declared npm packages
    starline.json      status-line layout
    web-search.json    deferred web search settings
    extensions/
      list-models.ts   live gateway model discovery and session affinity
      session-cleanup.ts  30-day session retention sweep
    skills/
      rex/             managed Rex CLI guide stub
      rex-pane/        cross-host interactive Pi delegation via Rex OSC 7501
```

## Agent Workflow (`agy` and `pi`)

- `pi/agent/AGENTS.md` is linked into both `~/.pi/agent/AGENTS.md` and
  `~/.gemini/config/AGENTS.md`, and `~/.gemini/config/skills.json` points at
  `~/.pi/agent/skills`, so Antigravity (`agy`) and Pi share the exact same
  global rules, `WORKLOG.md`, Feishu skills, and `rex-pane` delegation workflow.
- Remote work (`ali`, `stepmind`) runs inside interactive Pi tabs opened on the
  target host's Rex server via `pi/agent/skills/rex-pane/scripts/rex-pane`,
  using Pi's native `OSC 7501` status events rather than SSH wrapper chains.
