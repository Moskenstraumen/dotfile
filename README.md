# dotfiles

Configuration for the macOS workstation, read in place from `~/.config`, and for
remote hosts, where the repo is cloned anywhere and its files are symlinked
into place.

## Usage

```sh
git clone git@github.com:Moskenstraumen/dotfile.git
cd dotfile
./setup.sh                  # auto: local on macOS, remote everywhere else
bash setup.sh --local       # force the macOS profile (also accepts local)
bash setup.sh --remote      # force the remote profile (also accepts remote)
# bash setup.sh auto        # explicit auto-detection
```

`setup.sh` derives the repo root from its own location, so the checkout can live
wherever is convenient. Both profiles install Pi when missing, link its config,
and install declared Pi packages when the agent's npm tree is absent. Subsequent
runs keep existing package trees; offline Pi package failures warn rather than
aborting the rest of setup.

## Layout

```
setup.sh               profile dispatcher
bootstrap/
  common.sh            linking, version checks, release downloads
  manifest.sh          what gets symlinked where, per profile
  pins.sh              the version exceptions, each with its reason
  local.sh             macOS: Homebrew, config links, window manager services
  remote.sh            no-root: prebuilt binaries into ~/.local/bin
  pi.sh                Pi config linking, first-use packages and host bootstrap config
  Brewfile             the macOS package set
zsh/                   zshenv, zshrc and alias splits
skhd/ yabai/ sketchybar/ karabiner/   macOS window setup
nvim/                  LazyVim config and lazy-lock.json
starship.toml          prompt
pi/
  .gitignore           allowlist for declarative agent config
  agent/               interactive/base Pi config, mirrored into ~/.pi/agent
    AGENTS.md          interactive instructions
    models.json        shared model overrides
    settings.json      interactive settings and packages
    starline.json      shared status-line configuration
    subagents.json     shared subagent configuration
    web-search.json    interactive web access
    agents/            caller-oriented reader, thinker and implementer prompts
    extensions/        shared list-models.ts and session-cleanup.ts
    skills/rex/SKILL.md managed guide stub for the installed Rex CLI
rex-superagent/
  .gitignore                 allows hosts/ and pi/agent/; ignores runtime copies/backups
  bootstrap.json             local materialized host config (0600, git-ignored)
  hosts/
    mac.bootstrap.json       macOS owner and peer host configuration
    ali.bootstrap.json       Ali peer configuration
    stepmind.bootstrap.json  StepMind peer configuration
  pi/
    agent/                   overrides for ~/.local/share/rex-superagent/pi/agent
      settings.json          isolated rex-superagent settings and packages
      web-search.json        eagerly exposed web tools
      agents/                Executor-oriented reader, thinker and implementer prompts
```

`local` files apply to this Mac only, `remote` files to any server. Both
profiles are enumerated in full in `bootstrap/manifest.sh`, where each entry
links one `source|target` pair, so adding a config file means adding a line to
the relevant array.

Secrets template: `zsh/secrets.zsh.example` → `zsh/secrets.zsh`.

## Pi agent config

Both setup profiles run `bootstrap/pi.sh auto` after installing Node/Pi. To
re-link Pi configuration alone without the machine/tool bootstrap:

```sh
bash bootstrap/pi.sh             # auto-detect a configured host, else interactive-only
bash bootstrap/pi.sh interactive # configure ~/.pi/agent only
bash bootstrap/pi.sh mac         # macOS workstation
bash bootstrap/pi.sh ali         # /mnt/cpfs/xuyucheng-fileset
bash bootstrap/pi.sh stepmind    # /data/projects
# Usage: bash bootstrap/pi.sh [auto|interactive|mac|ali|stepmind]
```

Auto-detection selects `mac` on Darwin, then `ali` or `stepmind` when its workspace
exists. Generic machines receive interactive Pi only, with no rex-superagent
bootstrap config; `interactive` selects that mode explicitly. Explicit host names
require a regular host config. An inherited `PI_CODING_AGENT_DIR` is warned about
and unset so a Pi terminal cannot redirect or abort setup.

### Shared config, isolated agent directories

- `pi/agent/` mirrors the interactive runtime `~/.pi/agent`. It holds shared
  `models.json`, `starline.json`, `subagents.json`, and the
  `extensions/list-models.ts` and `extensions/session-cleanup.ts` extensions.
- Interactive `pi/agent/AGENTS.md`, settings, web-search config and `agents/`
  supply instructions, web access and caller-oriented `reader`, `thinker` and
  `implementer` prompts. Web tools activate automatically with deferred exposure;
  settings include the ask-user-question package.
- `rex-superagent/pi/agent/` supplies settings, eagerly exposed web tools and
  Executor-oriented prompts to `~/.local/share/rex-superagent/pi/agent`, alongside
  shared base files from `pi/agent/`. It omits ask-user-question and does not link
  the interactive `AGENTS.md`. Host configs remain in `rex-superagent/hosts/`.
- `pi/agent/skills/rex/SKILL.md` is linked into both roots. Other installed
  interactive skills are symlinked into rex-superagent's real `skills/` directory.

The two agent roots have separate sessions, model stores, state, caches,
installed packages and permission logs. Agent roots and the isolated `pi/`
parent are mode `0700`. `session-cleanup` resolves state and fallback session
paths from the active agent directory, not a hardcoded interactive path.

Standalone `bootstrap/pi.sh` expects Pi on PATH; the setup profiles install it
with npm (also declared in the Mac Brewfile). When an agent's `npm/node_modules`
is absent, bootstrap runs `pi update --extensions --no-approve` in that agent
directory to install its declared packages. Existing package trees are preserved;
failed first-use installs can be retried when online. To update packages later,
run `pi update --extensions --no-approve` with `PI_CODING_AGENT_DIR` set for the
isolated root (unset it for interactive Pi). If credentials are absent, bootstrap
prints a reminder to open Pi and use `/login`, or copy `cliproxyapi.json` locally.

Before relinking an older isolated installation, move its whole runtime directory
from `~/.local/share/rex-superagent/pi` into `pi/agent`, preserving `npm/`, model
stores and sessions without reinstalling. Linked declarative files point into
this checkout, so changes to those files can make `git status` dirty.

### Host bootstrap and machine-local files

`rex-superagent/hosts/{mac,ali,stepmind}.bootstrap.json` are the tracked host
configs. The selected host config is materialized into
`~/.config/rex-superagent/bootstrap.json` as a `0600` regular file, never a symlink:
`rex-superagent` opens it with `O_NOFOLLOW`. That runtime copy is ignored by git.
Each host config points `globalAgentDir` and role extensions at the isolated
rex-superagent Pi root and keeps memory under that host's `~/.pi/memory`.

Before changing anything, the script checks that every manifest source and the
selected host config is a regular file. Existing real files are backed up before
linking. Differing regular files are backed up before atomic materialization;
matching copies are left in place with mode `0600`.

Credentials and permission policies remain machine-local and are not tracked:

- When present, interactive `auth.json` and `cliproxyapi.json` are symlinked into
  the rex-superagent root for API-key access.
- `extensions/pi-permission-system/config.json` is copied from the interactive
  root into the rex-superagent root as an atomic `0600` regular file. The permission
  package rewrites it by rename, so a symlink would be replaced on write. Its
  containing directory stays real so `logs/` remains separate per agent directory.
- Runtime state, installed packages and other credentials are not stored here.

The retired `session-namer.json`, `pi/hosts/mac/mcp.json` and
`pi/hosts/mac/settings-verification.md` are removed from the declarative tree;
`pi-session-namer` is not installed by either profile. Bootstrap also removes
`session-namer.json`, `mcp.json`, `mcp-auth.json` and
`extensions/sanitize-antigravity-prompt.ts` from both agent roots, and removes the
obsolete `~/.agents/skills/rex` installation.

### Permission checks and settings freshness

Both settings profiles declare `npm:@gotgenes/pi-permission-system`.
Enforcement depends on the host's installed package, loaded extension and local
policy. `yoloMode: true` auto-approves `ask`, not `deny`; keep each host's
private-key and protected-root rules local rather than copying the Mac policy
to a server.

Check each host and each agent root separately:

1. Verify manifest links resolve to the checkout and materialized host/policy
   copies match their sources. Matching links alone do not prove cross-host freshness.
2. Check `pi --version`, `pi list` and installed package versions. Unpinned package
   declarations do not guarantee identical installations or the latest release.
3. Verify resource loading and a permission decision, not just `config.json`.
   Test dangerous inputs at the gate only; never execute push, protected-root
   deletion, job stop/delete or private-key reads as probes.
4. After settings or resource changes, use `/reload` or a new session. A fresh
   session does not prove already-running sessions reloaded.

Rex native owners load the permission package separately from
`extensionAllowlist`; absence from that list does not establish that enforcement
is disabled. Verify native-owner resolution and loading directly rather than
substituting a standalone Pi result. Each host needs its own verification evidence.
