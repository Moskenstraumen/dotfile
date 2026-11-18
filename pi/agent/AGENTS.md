# Hosts and routing

- `mac` (`/Users/moskenstraumen/Documents/Work/step`): interactive entry point, orchestration, full network reachability, local configuration, and cross-host synchronization.
- `ali` (`/mnt/cpfs/xuyucheng-fileset`): code, datasets, and PAI DLC training; put run artifacts, logs, and staging under `/mnt/cpfs/cache/xuyucheng/runs` and exported HF checkpoints under `/mnt/data/xuyucheng/runs/checkpoints` (CPFS metadata is slow: access known paths directly and list one level at a time).
- `stepmind` (`/data/projects`): model deployment and evaluation.

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
9. Do not preserve backward compatibility unless explicitly asked; prefer clean refactoring over incremental patching.

# Descriptive names

- Name by purpose or responsibility, without arbitrary numbered labels or invented version suffixes; preserve actual external names and IDs.

# Delegation

- From the `mac` main session only, handle lightweight local tasks directly and route remote work (`ali`, `stepmind`) by task responsibility or heavy local work to native target-host Rex panes via `~/.pi/agent/skills/rex-pane/SKILL.md` instead of `ssh <host>` chains.
- Launch `rex-pane` asynchronously in the background so independent panes run in parallel; never nest `rex-pane` on a remote host or inside a delegated pane (`REX_PANE_CHILD=1`).
- Give each pane a self-contained prompt (read-only vs edit scope, context, verification) and pass `--session-id` only to continue related context; concurrent editors in one directory need non-overlapping files and all Change boundaries rules verbatim.
- Verify actual diffs and verification output before claiming completion, not just delegated summaries.

# Git workflow

- Isolate each task/session in one worktree at `~/.local/state/worktrees/<name>` on branch `agent/<name>` from the main checkout's symbolic branch (ask if HEAD is detached), and initialize submodules from the main checkout's local gitdirs without network fetches.
- Commit verified changes locally on `agent/<name>` with scoped single-line Conventional Commit messages; push only when explicitly requested (PRs are user-managed).
- Merge into the main checkout's base branch when asked or before using changes outside the worktree (submissions, snapshots, deployment, evaluation).
- Before merging, check main-checkout status and ask on overlapping uncommitted files or conflicts (no unrequested stash, overwrite, or conflict resolution); rebase onto an advanced base branch first and merge with `--ff-only` (never leave merge commits).
- If unmerged, state the branch, commit, and worktree path and ask whether to merge; after merge or explicit discard, remove the worktree and task branch and prune worktree references.

# Change boundaries

- Do not add or modify repository tests unless explicitly asked; run verification from outside the repo so no test file enters the diff or a commit.
- Do not edit docs (`docs/`, READMEs, `*.md` in the repo) unless explicitly asked; keep docs byte-identical to `master` (or the repo's default branch) and report any pre-existing doc diff rather than carrying it along.
- Write temporary scripts, scratch files, and verification artifacts outside the repository and delete them immediately after use.

# Research records

- Follow `~/.pi/agent/WORKLOG.md` to record investigations and experiments in Feishu (`https://wvixbzgc0u7.feishu.cn/wiki/JUDDwn3a1iwiXSkp9LMcL9Ysned`: `Algo`, `Data`, `Eval`, `Infra`) using each category's `实验记录模版` with `--as bot`, and maintain the document link in `~/.pi/agent/WORKLOG.md`.
- Never write experiment reports or report drafts to disk on any local or remote host.
