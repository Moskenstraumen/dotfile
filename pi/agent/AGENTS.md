# Hosts and routing

- `mac` (`/Users/moskenstraumen/Documents/Work/step`): interactive entry point, orchestration, full network reachability, local configuration, and cross-host synchronization.
- `ali` (`/mnt/cpfs/xuyucheng-fileset`): code, datasets, and PAI DLC training; put generated run artifacts, logs, and staging under `/mnt/cpfs/cache/xuyucheng/runs` and exported HF checkpoints under `/mnt/data/xuyucheng/runs/checkpoints` (CPFS metadata is slow: access known paths directly and list one level at a time).
- `stepmind` (`/data/projects`): model deployment and evaluation.
- Route work initiated on `mac` automatically to the owning host by task responsibility.

# Working style

Apply the clarity principles of ASD-STE100 while following natural, modern Chinese usage. The goal is to help the user understand accurately, not merely to shorten the text.

1. State the conclusion first, then explain the reasons.
2. Prefer common, concrete words. Explain necessary technical terms.
3. Express one main judgment or action per sentence. Split complex reasoning into separate sentences.
4. Use one consistent name for each concept. Avoid redundant synonyms.
5. Make the actor, action, conditions, causal relationships, and exceptions explicit.
6. Preserve key data, constraints, evidence, and uncertainty. Do not sacrifice information for brevity.
7. Match the format to the content: prose for explanations, tables for comparisons, flowcharts for processes, and animations or interactive pages for dynamic mechanisms.
8. Avoid empty summaries, repeated conclusions, excessive heading levels, and unnecessary pleasantries.

# Descriptive names

- Name by purpose or responsibility, without arbitrary numbered labels or invented version suffixes; preserve actual external names and IDs.

# Delegation

- Handle lightweight `mac` tasks directly in the main session; delegate remote work (`ali`, `stepmind`) or context-heavy tasks by opening a Rex pane via `~/.pi/agent/skills/rex-pane/SKILL.md`.
- Run cross-host work natively inside a remote Rex pane on the target host instead of chaining `ssh <host>` commands from `mac`; launch `rex-pane` asynchronously in the background so independent panes run in parallel.
- Give each delegated pane a self-contained prompt stating its exact scope (read-only inspection vs authorized edits), required context, and verification commands; pass `--session-id` only to continue related context.
- Concurrent panes editing in one directory must have non-overlapping file assignments; pass both Change boundaries rules below verbatim whenever delegating code changes.
- Verify actual diffs and verification output before claiming completion, not just delegated summaries.

# Git workflow

- Isolate each task/session in one worktree at `~/.local/state/worktrees/<name>` on branch `agent/<name>`, based on the main checkout's current symbolic branch; ask if HEAD is detached.
- Initialize submodules from the main checkout's existing local gitdirs, without network fetches.
- Automatically commit verified changes locally on `agent/<name>` using single-line Conventional Commit messages, so the result is reviewable.
- Merge into the base branch in the main checkout when asked or before using changes outside the worktree; submissions, snapshots, deployment, and evaluation run from that base checkout.
- Before merging, check main-checkout status; overlapping uncommitted files or conflicts require asking, without unrequested stashing, overwriting, or conflict resolution. If the base branch has advanced cleanly, rebase `agent/<name>` onto it first and merge with `--ff-only` (never leave `Merge branch 'agent/...'` commits).
- If unmerged, state the branch, commit, and worktree path and ask whether to merge.
- After merge or explicit discard, remove the worktree and task branch and prune worktree references.
- Push only when explicitly requested; PRs are user-managed.

# Change boundaries

- Do not add or modify tests in the repository unless explicitly asked; verify with throwaway scripts outside the repo (session temp dir) and delete them afterwards, so no test file reaches the diff or a commit.
- Do not edit docs (`docs/`, READMEs, `*.md` in the repo) unless explicitly asked; keep docs byte-identical to `master` (or the repo's default branch), and report any pre-existing doc difference against it rather than silently carrying it along.

# Research records

- Read record rules, templates, and the category index in `~/.pi/agent/WORKLOG.md` before recording an investigation or experiment.
- Record investigation findings, experiment progress, context, and results in Feishu under `https://wvixbzgc0u7.feishu.cn/wiki/JUDDwn3a1iwiXSkp9LMcL9Ysned` (`Algo`, `Data`, `Eval`, `Infra`) using the category's `实验记录模版` with `--as bot`, and maintain the document link in `~/.pi/agent/WORKLOG.md`.
- Never write experiment reports or report drafts to disk on any local or remote host.
