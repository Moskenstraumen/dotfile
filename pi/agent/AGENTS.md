# Hosts and routing

- `mac` (`/Users/moskenstraumen/Documents/Work/step`): full network reachability; local configuration and cross-host file synchronization.
- `ali` (`/mnt/cpfs/xuyucheng-fileset`): training and data.
- `stepmind` (`/data/projects`): deployment and evaluation.
- Launch or drive remote Pi with `rex -S <host> run ...`, or dispatch autonomous tickets with `rex-superagent send`, so work uses the target host's `AGENTS.md`, local memory, and local subagents.
- Use `ssh <host>` for quick one-off commands; run long waits with `bg_run` to keep the session responsive.

# Project memory

Read this host's `~/.pi/memory/<project-id>/MEMORY.md` and matching entry files with `read` before assuming host/project paths or conventions:

- `mac`: `Users__moskenstraumen__Documents__Work__step`
- `ali`: `mnt__cpfs__xuyucheng-fileset`
- `stepmind`: `data__projects`

Local `pi` and remote Pi launched with `rex -S <host> run ...` follow their own host's `AGENTS.md` and read their own host's memory. Keep `~/.pi/memory/` read-only; `rex-superagent` maintenance owns writes.

# Git worktrees

- Isolate the whole task/session in `~/.local/state/rex-superagent/work/<name>` on branch `agent/<name>`; use a name matching `^[a-z0-9][a-z0-9._-]{0,80}$` to follow the `rex-superagent` layout.
- Base it on `git -C <repo> symbolic-ref --short HEAD`; ask if HEAD is detached, otherwise create it with `git -C <repo> worktree add -b agent/<name> ~/.local/state/rex-superagent/work/<name> <base>` to preserve the checked-out branch's starting point.
- When `.gitmodules` exists, initialize submodules from the main checkout's local gitdirs with `git -c protocol.file.allow=always -c submodule.<submod>.url=<gitdir> submodule update --init <path>` in the worktree, keeping initialization local without network fetches.
- After merge or explicit discard, clean up with `git -C <repo> worktree remove --force <dir>`, `git -C <repo> branch -D agent/<name>`, and `git -C <repo> worktree prune` to remove both checkout and references.
- Commit, push, or merge only when explicitly asked, preserving the user's control over integration.

# Subagents (`reader`, `thinker`, `implementer`)

- Use `reader` for provenance-backed evidence, `thinker` for analysis/plans without edits, and `implementer` for settled changes, matching delegation to the work.
- A single `implementer` can edit within the task's scope; concurrent `implementer`s in the same directory need non-overlapping file assignments to avoid overwriting each other.
- Make prompts self-contained and leave delegated searches to their assigned agent, keeping parallel work independent.
- Inspect actual diffs and test output after an `implementer` finishes, verifying outcomes before reporting completion.
