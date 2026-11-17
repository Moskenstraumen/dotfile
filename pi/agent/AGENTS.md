# Hosts and routing

- `mac` (`/Users/moskenstraumen/Documents/Work/step`): full network reachability; local configuration and cross-host file synchronization.
- `ali` (`/mnt/cpfs/xuyucheng-fileset`): training and data.
- `stepmind` (`/data/projects`): deployment and evaluation.

# Working style

- Respond in the user's language; default to Chinese.
- Give the conclusion, reasons, and necessary action without defensive preambles, imagined objections, repetitive justification, or generic caveats; name concrete evidence gaps when uncertain.
- Analysis and clarification are not authorization to execute or change files.

# Descriptive names

- Name by purpose or responsibility, without arbitrary numbered labels or invented version suffixes; preserve actual external names and IDs.

# Subagents

- Keep the main session on reasoning, user clarification, and orchestration; delegate exploration, CLI/SSH evidence, and execution.
- Use `reader` for provenance-backed evidence, `thinker` for independent analysis without edits, and `implementer` for settled changes and execution.
- Run cross-host work over `ssh <host>` inside subagents; use `bg_run` for commands or waits longer than about 30 seconds.
- Give self-contained, scoped prompts with required context and verification; resume an agent only for related context and leave delegated work to it.
- Parallelize independent work; concurrent implementers in one directory must have non-overlapping file assignments.
- Batch independent tool calls and filter large outputs with `codemode` inside the executing agent.
- Verify actual diffs and verification output after implementation, not just agent summaries.
- Pass both Change boundaries rules below verbatim into every `implementer` prompt.

# Git workflow

- Isolate each task/session in one worktree on `agent/<name>`, based on the main checkout's current symbolic branch; ask if HEAD is detached.
- Initialize submodules from the main checkout's existing local gitdirs, without network fetches.
- Automatically commit verified changes locally on the task branch, so the result is reviewable.
- Merge into the base branch in the main checkout when asked or before using changes outside the worktree; submissions, snapshots, deployment, and evaluation run from that base checkout.
- Before merging, check main-checkout status; overlapping uncommitted files or conflicts require asking, without unrequested stashing, overwriting, or conflict resolution.
- If unmerged, state the branch, commit, and worktree path and ask whether to merge.
- After merge or explicit discard, remove the worktree and task branch and prune worktree references.
- Push only when explicitly requested; PRs are user-managed.

# Change boundaries

- Do not add or modify tests in the repository unless explicitly asked; verify with throwaway scripts outside the repo (session temp dir) and delete them afterwards, so no test file reaches the diff or a commit.
- Do not edit docs (`docs/`, READMEs, `*.md` in the repo) unless explicitly asked; keep docs byte-identical to `master` (or the repo's default branch), and report any pre-existing doc difference against it rather than silently carrying it along.

# Research records

- Read record rules and the category index in `playground/users/xuyucheng/WORKLOG.md` in the active StepTron checkout.
