# Hosts and routing

- `mac` (`/Users/moskenstraumen/Documents/Work/step`): full network reachability; local configuration and cross-host file synchronization.
- `ali` (`/mnt/cpfs/xuyucheng-fileset`): training and data.
- `stepmind` (`/data/projects`): deployment and evaluation.
- Run cross-host inspection and operations over `ssh <host>` inside subagents, pairing commands or waits over ~30s with `bg_run` to keep sessions responsive and raw output out of main context.

# Project memory

Read this host's `~/.pi/memory/<project-id>/MEMORY.md` and matching entry files with `read` before assuming host/project paths or conventions:

- `mac`: `Users__moskenstraumen__Documents__Work__step`
- `ali`: `mnt__cpfs__xuyucheng-fileset`
- `stepmind`: `data__projects`

Each Pi session reads its own host's memory, and cross-host tasks read the target host's `~/.pi/memory/<project-id>/MEMORY.md` over `ssh <host>` before assuming remote paths or conventions. Keep `~/.pi/memory/` read-only; `rex-superagent` maintenance owns writes.

# Git worktrees

- Isolate the whole task/session in `~/.local/state/rex-superagent/work/<name>` on branch `agent/<name>`; use a name matching `^[a-z0-9][a-z0-9._-]{0,80}$` to follow the `rex-superagent` layout.
- Base it on `git -C <repo> symbolic-ref --short HEAD`; ask if HEAD is detached, otherwise create it with `git -C <repo> worktree add -b agent/<name> ~/.local/state/rex-superagent/work/<name> <base>` to preserve the checked-out branch's starting point.
- When `.gitmodules` exists, initialize submodules from the main checkout's local gitdirs with `git -c protocol.file.allow=always -c submodule.<submod>.url=<gitdir> submodule update --init <path>` in the worktree, keeping initialization local without network fetches.
- Once a change in the worktree is verified, commit it locally on `agent/<name>` without asking, so the task result exists as a reviewable commit instead of loose working-tree edits.
- Merge `agent/<name>` into its base branch in the main checkout (`git -C <repo> merge agent/<name>`) when the user asks to merge/合入, or asks to use the change outside the worktree (submit/restart experiments, take code snapshots, deploy, evaluate), so such actions always run from the base branch checkout, never from the worktree.
- Before merging, check `git -C <repo> status`; if the main checkout has uncommitted changes touching the same files or the merge conflicts, stop and ask instead of stashing, overwriting, or resolving on the user's behalf.
- When finishing a task without merging, state the branch, commit, and worktree path, and ask whether to merge, so integration is never left implicit.
- After merge or explicit discard, clean up with `git -C <repo> worktree remove --force <dir>`, `git -C <repo> branch -D agent/<name>`, and `git -C <repo> worktree prune` to remove both checkout and references.
- Push only when explicitly asked, preserving the user's control over remotes.

# Tests and docs

- Do not add or modify tests in the repository unless explicitly asked; verify with throwaway scripts outside the repo (session temp dir) and delete them afterwards, so no test file reaches the diff or a commit.
- Do not edit docs (`docs/`, READMEs, `*.md` in the repo) unless explicitly asked; keep docs byte-identical to `master` (or the repo's default branch), and report any pre-existing doc difference against it rather than silently carrying it along.
- Pass both rules verbatim into every `implementer` prompt, since subagents do not see this file's intent otherwise.

# Subagents (`reader`, `thinker`, `implementer`)

- Keep the main session on reasoning, user clarification (`ask_user_question`), reading local `MEMORY.md`, and orchestrating subagents, so exploration, CLI/SSH output, and edits stay out of the main context.
- Use `reader` for local, remote (`ssh <host>`), and CLI provenance-backed evidence, `thinker` for independent second-opinion plans or trade-off analyses without edits, and `implementer` for settled file or target changes and command execution, matching delegation to the work.
- Batch parallel tool calls and filter large outputs with `codemode` inside the executing agent instead of embedding large multi-step scripts into a single `bash` call, keeping tool invocations concise and inspectable.
- A single `implementer` can edit within the task's scope; concurrent `implementer`s in the same directory need non-overlapping file assignments to avoid overwriting each other.
- Make prompts self-contained with relevant memory facts, host paths, and provenance or verification requirements, leaving delegated searches and execution to their assigned agent.
- Inspect actual diffs and verification output after an `implementer` finishes (directly on small targeted ranges or via `reader` for large/remote checks) before reporting completion.
