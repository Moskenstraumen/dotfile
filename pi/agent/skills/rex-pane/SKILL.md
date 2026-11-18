---
name: rex-pane
description: >-
  Delegate remote work (ali, stepmind) or isolated heavy local work by opening
  an interactive Pi terminal tab in Rex and waiting on OSC 7501 completion
  events. Works identically from both Antigravity (agy) and Pi.
---

# rex-pane

Run delegated tasks inside a Rex terminal tab on `ali`, `stepmind`, or `mac`
using [scripts/rex-pane](./scripts/rex-pane) and [scripts/rex-pane.lua](./scripts/rex-pane.lua).
The Lua script runs locally on `mac` against `rex -S <host>`, opens an unfocused
tab running interactive `pi` (`PI_PROGRAM_STATUS=1`), waits on native `OSC 7501`
status events (`working -> done | blocked | error`) without screen-polling, and
extracts the complete Markdown reply from the remote Pi session JSONL.

## Launch a delegated pane

Always launch asynchronously so the main session stays responsive and multiple
independent panes can run in parallel:

- **From Antigravity (`agy`)**: call `run_command` with `WaitMsBeforeAsync: 500`
  (reactive wakeup notifies you automatically when the pane finishes).
- **From Pi**: call `bg_run` (not blocking `bash`).

Pass the prompt over stdin with a single-quoted heredoc (`<<'EOF'`) so quotes,
newlines, `$VARS`, and code blocks require no escaping:

```bash
~/.pi/agent/skills/rex-pane/scripts/rex-pane \
  --host ali \
  --cwd /mnt/cpfs/xuyucheng-fileset/projects/steptron \
  --name rl-status <<'EOF'
Read-only check: inspect current git branch, HEAD commit, and status.
EOF
```

## Options

- `--host <ali|stepmind|mac>`: target Rex host (defaults to `ali`).
- `--cwd <abs-path>`: working directory on the target host (defaults to host workspace root).
- `--name <label>`: tab title in Rex so the user can identify live panes.
- `--session-id <uuid>`: resume an earlier pane's Pi conversation with full context (printed in the `[rex-pane]` result header).
- `--model <provider/id>` / `--thinking <low|medium|high|xhigh>`: optional model or reasoning override (e.g. `--model modelproxy/gpt-6-astra --thinking high` for deep root-cause analysis).
- `--keep-open`: leave the Rex tab open after `done` (tabs already stay open automatically on `blocked`, `error`, `exited`, or `timeout`).
- `--close-window <window_id>`: close a previously kept-open window on `--host`.

## Delegation rules

- Give a self-contained prompt with exact paths, scope (read-only inspection vs authorized code changes in an `agent/<name>` worktree), and verification commands.
- When delegating code edits, include both `Change boundaries` rules from `AGENTS.md` verbatim.
- Concurrent panes in the same repository must have non-overlapping file assignments.
- If a pane returns `state=blocked`, report the prompt message and `window_id` to the user rather than retrying blindly.
