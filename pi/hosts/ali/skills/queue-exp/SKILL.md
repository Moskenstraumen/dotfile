---
name: queue-exp
description: >-
  Run explicitly authorized DLC experiment queues using sealed code and real
  train-job-ID runtime identity; watch progress, report results and retry CPU
  HF archival. Schema-2 histories are read-only until operator migration.
---

# /queue-exp

Resolve the user's experiment, algorithm and native `key=value` overrides before
submission. A ledger/request is a record, not fresh authorization. Never stop or
delete cloud jobs, delete native/staging weights, migrate artifacts, or replace
an existing ledger without explicit current-task approval.

## Implementation and identity

Durable implementation is resolved from the StepTron checkout at
`/mnt/cpfs/xuyucheng-fileset/projects/steptron`: `playground/users/xuyucheng/rl/dlc/`
when present, otherwise `playground/users/xuyucheng/opd/dlc/`.
The named scripts in `scripts/` are thin adapters to that runtime.
The active deployment source is `playground/users/xuyucheng/opd/exp/`.
Historical RL recipes exist only in their sealed archives; do not reconstruct them.

Identity is `exp_name`, `run_name`, `train_job_id`. New protocol has no additional
run identifier/counter or pre-ID runtime directory. `run.py:RunPaths` owns paths:

- Runtime: `/mnt/cpfs/cache/xuyucheng/runs/.runtime/<exp>/<run_name>_<train_job_id>/`.
- Native/TB: cache `checkpoints/` and `tensorboard/`, same exp and run suffix.
- Runtime contents: `code.tar.gz`, `run.json`, `requests/`, `venv/`,
  `train/<id>`, `infer/<id>`, `router/<id>`, optional `harbor/<id>`, `hot/`, `hf-export/`.
- HF products: `/mnt/data/xuyucheng/runs/checkpoints/<exp>/<run_name>_<train_job_id>/itN_hf[_fp8]`.
- No symlink-based identity/alias is created.

Submission seals code to an ordinary temporary file first, renders a thin
stdlib TRAIN bootstrap and SDK-dry-runs/sends TRAIN first. The acknowledged real
ID determines canonical runtime; the controller publishes code/manifest there,
then SDK-dry-runs/sends infer/router (and Harbor only if a supported renderer
explicitly provides it). Services inherit `TRAIN_JOB_ID`; their `DLC_JOB_ID`
only identifies their own role. Current OPD renderer has infer/router, no Harbor
recipe. The controller records receipts immediately and atomically marks
`run.json` submission `complete` or `failed` with roles and snapshot SHA.
No extra probe jobs or cloud state calls are made during group submission.

TRAIN derives identity from its own DLC environment/hostname. Before extracting
code or reaching torchrun it waits for complete manifest, code and snapshot- /
train-ID-bound paired readiness. Partial/ambiguous submission pauses; bootstrap
fails closed, no service/job is automatically stopped. Image-native sanity runs
**after actual endpoints resolve**, not on the mocked submit-host config.

## Ledger and commands

`QUEUE_EXP_STATE` explicitly chooses a ledger; otherwise the skill's existing
`state/` is used. New writes require schema 3. Run rows are keyed by the actual
train ID. Schema-2 state (including all historical records) is readable through
`legacy.py` but mutators refuse it **before creating locks/logs/PIDs**. Migration
belongs to the main/operator; `init` never replaces existing ledgers.

From this skill's `scripts/` (commands below create jobs only where stated):

```bash
# Fresh directory, after user approval. init/add do not submit.
QUEUE_EXP_STATE=<fresh-dir> python3 queue_state.py init <queue> --request "<user request>"
QUEUE_EXP_STATE=<fresh-dir> python3 queue_state.py add --exp <exp> --algo mopd <key=value ...>
QUEUE_EXP_STATE=<fresh-dir> python3 queue_state.py show
QUEUE_EXP_STATE=<fresh-dir> python3 queue_exp.py submit

# Reads; legacy schema is supported.
python3 queue_exp.py status
python3 queue_state.py entry <N-or-train-ID>
python3 queue_exp.py hf-cell <train-ID>

# Explicit local watcher management, not cloud job stops.
python3 queue_exp.py stop
python3 queue_exp.py heal
```

The OPD adapter requires an explicit state directory:
`QUEUE_EXP_STATE=<dir> python3 playground/users/xuyucheng/opd/dlc/queue_exp.py <command>`.
The `submit.sh` wrappers are removed. From this skill's `scripts/`, use
`QUEUE_EXP_STATE=<dir> python3 queue_exp.py submit` for authorized submission.

Processes may load optional `QUEUE_EXP_ENV` (`/root/.env`) without overriding the
caller's environment. Real secret values never enter persisted requests; use
environment placeholders at supported serving boundaries.

## Observation, retries and archival

The detached watcher keeps one progress card patched in place, polls the whole
role group, and pauses while train/services have mismatched lifecycles. It
stops no jobs. Only a whole terminal group with successful train qualifies for
CPU archival; archival failure pauses advancement and retains sources/staging.
Successful archival allows an already-authorized running queue to advance.

- CPU Python: `QUEUE_EXP_HF_PYTHON`, otherwise **canonical runtime**
  `venv/bin/python`. No migration-directory/project-global Python fallback.
- TRAIN rank0 can build a lightweight CPU venv with copies and system site
  packages from the native image, without pip or heavy dependency installation.
  The archive host must have compatible interpreter/image site paths; verify
  imports before relying on auto-archive. Required exporter imports include
  torch, Optimus, transformers, safetensors, numpy, loguru, megfile, and native
  StepTron checkpoint/config dependencies. See shared runtime `README.md`.
- `hf-export/` is directly under runtime, without a repeated train ID.
- Use the existing OPD/native CPU low-memory BF16/FP8 exporters, one CPU thread,
  2 GiB output shards. Do not downgrade to an older iteration when the newest
  actor checkpoint fails completeness preflight; pause for inspection.
- Stage on POSIX cache, publish to OSSFS separately. Ready/index markers last,
  `transfer_complete.json` only after copied sizes verify. No payload SHA checks.
- Preserve native and staging automatically; unknown nonempty output remains
  a manual inspection/cleanup decision.

```bash
# Explicit archive-only retry, current successful terminal train only.
python3 queue_exp.py convert <train-ID>
# No training resubmission or queue advancement is implied by convert.

# Explicit new training submission only after previous whole group is terminal.
python3 queue_exp.py retry --result "<diagnosis>"
# Reuses the sealed source but obtains a new real train ID and new runtime.
python3 queue_exp.py new-snapshot [N]  # temporary seal selection only; no submit
python3 queue_state.py set N overrides="<native key=value ...>"
```

Ambiguous sends require operator resolution, never automatic repetition:
`queue_state.py set N submission=resolved` records that manual decision.

## Handoff and reports

A bare train ID means report the recorded run, not submit. Read `queue_state.py
entry` and `queue.md`; inspect job/traceback via
`job_brief.py --traceback <train-id> <service-ids...>` as needed. For failed
training record diagnosis/next decision with `queue_state.py set N note=...`;
leave it paused.

The watcher hands off from `QUEUE_EXP_WORKSPACE` (workspace root by default):
`pi -p "/skill:queue-exp <train-job-id>"` with `QUEUE_EXP_HANDOFF` and state env.

Resolve the long-lived task setting from the user's queue context/config, not
from one method, variant, or run/job ID. Use the existing `lark-doc` and
`lark-wiki` skills with `--as bot` for all document/wiki reads and writes.
Keep bot identity on permission failures; never fall back to user identity.
Read the record rules, writing style, and category index in
`~/.pi/agent/WORKLOG.md`.
Then read the relevant category's online template with the exact title
`实验记录模版`.
Search candidate setting documents across the appropriate existing sections
and inspect their contents before creating anything; prefer the existing
setting document and create one only when none exists. Reuse it across dates
and queues. Treat `q.report` only as a hint/cache: validate that its document
represents this same long-lived setting before choosing it. Historical
per-queue reports are not automatically migrated or modified.

If the setting is ambiguous or multiple candidate documents remain, stop and
ask through the handoff/owner channel; leave the digest absent rather than
speculating or creating a duplicate.

Locate the dated experiment entry by purpose and real run/job identifiers.
Variants addressing the same research question share that dated entry;
repeated handoffs update the same dated block rather than adding another.
Keep the latest dates first and use Motivation, Recipe, Conclusion, and
Training dynamics from the online template. Record actual completion/failure,
usable iteration ranges, curves, and evaluation status; identify unavailable
metrics or evaluations as unavailable, without claiming success from them.
Keep next submission within the user's existing authorization; a report or
suggested recipe is not new submission authorization.

Figure and metric helpers remain available:

```bash
python3 report_metrics.py <tb-dir> --algo <algo>
python3 report_metrics.py <tb-dir> --tb-url <job-id>[,...] --algo <algo>
python3 report_figures.py <out-dir> <run>=<tb-dir>... --algo <algo>
python3 queue_exp.py hf-cell <job-id>
```

Publish directly to Feishu with `lark-doc`/`lark-wiki` using `--as bot`,
patching only the target entry and any directly affected summary, never
replacing the whole document and never saving an experiment report or draft
Markdown file to host disk (remove any transient `/tmp` API payload immediately).
Fetch the published content with `--as bot` and verify the entry's identifiers,
results, figures, and chosen document URL before claiming success. On failed or
unresolved publication, leave the digest absent and report the failure or
decision needed through the handoff/owner channel.

Only after verified publication, the existing report cache may record the
chosen URL:

```bash
python3 queue_state.py report --doc <url>
```

This cache is not a cross-queue registry. After verified publication, write
`state/reports/<train-ID>.dm.md` in English, exactly seven lines:

```text
<EXP_NAME>/<RUN_NAME>
status: <finished | failed at iter k: cause; iters 0..k-1 usable | stopped>
conclusion: <what changed and what the curves show, complete sentences>
next: <next authorized submission ID | queue paused: decision needed>
job: {{JOB_LINK}}
tb: {{TB_LINK}}
report: <doc url>
```

The watcher fills link placeholders and sends the digest. Only its transcript,
digest and figures are removed after successful delivery; ledger, requests,
source archives and training/HF artifacts stay. Failed handoff keeps watcher
eligible for explicit `heal`; do not substitute historical HF_OK logs for
verified product records.
