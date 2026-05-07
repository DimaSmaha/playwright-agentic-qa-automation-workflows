---
name: flow-1b-gt-tc-to-spec
description: >
  EXPLICIT-INVOCATION ONLY. Sub-orchestrator for Pipeline A-2 (Test Cases → Playwright Specs).
  Use when the caller explicitly requests spec generation from existing tracker test cases.
  Fetches TCs linked to a user story (from a prior flow-1a-gt-us-to-tc run or directly from the tracker),
  then runs per-TC spec writing, refactor, and ship. For the full end-to-end flow, use flow-1-gt-us-to-spec.
---

# flow-1b-gt-tc-to-spec

EXPLICIT-INVOCATION ONLY.

> **NEVER re-ask the user for any input, confirmation, or clarification during execution.**
> All decisions are resolved from artifacts and env vars. Stop-and-report is the only permitted response to missing inputs.

Run Pipeline A-2: fetch TCs → per-TC (spec + refactor) → ship.

## Pipeline schema

On start, read `.claude/skills/flow-1b-gt-tc-to-spec/pipeline.json`.
This file is the authoritative definition of all phases, loop structure,
artifact contracts, resume-skip conditions, and compaction fields.
Use it as the execution manifest throughout.

## When this skill fits

Use it for requests like:

- "generate specs from the test cases for story 112"
- "run the second half of Pipeline A — spec writing only"
- "write Playwright specs from an existing flow-1a-gt-us-to-tc run"
- "tc-to-spec for run gtc-20240601-143012"

Do **not** use it for:

- generating test cases from a user story (use `flow-1a-gt-us-to-tc`)
- full end-to-end pipeline (use `flow-1-gt-us-to-spec`)
- writing one spec (use `gt-spec-writer`)

## Inputs

One of:

- `--run-id <gtc-run-id>` — reuse `us.json` and `tc-*.json` from an existing `flow-1a-gt-us-to-tc` run
- `--us-id <id>` — fetch the user story from the tracker, then query for linked test cases

If neither is provided, stop immediately and report: "flow-1b-gt-tc-to-spec requires --run-id or --us-id. Invoke with one of these inputs."

## Workflow

### Phase 0 — Initialize

```bash
run_id="gts-$(date +%Y%m%d-%H%M%S)"
mkdir -p ".workflow-artifacts/${run_id}"
```

Confirm ISSUE_TRACKER and FAKE_TRACKER_URL (or other tracker vars) are set. If missing, stop and report exactly which vars are absent — do not ask interactively.

### Phase 1 — Fetch Test Cases

**Mode A — `--run-id <gtc-run-id>` (artifact reuse):**

1. Verify `.workflow-artifacts/<gtc-run-id>/us.json` exists. If not, stop and report.
2. Copy `us.json` and all `tc-*.json` files from `.workflow-artifacts/<gtc-run-id>/` into `.workflow-artifacts/<gts-run-id>/`.
3. Count copied `tc-*.json` files — this is `tc_count`.

Show checkpoint: `✓ Loaded N test cases from run <gtc-run-id>`

**Mode B — `--us-id <id>` (tracker fetch):**

1. Run preflight:
   ```bash
   bash .claude/skills/operations-with-issue-tracker/scripts/preflight.sh
   ```
2. Fetch the user story and write `us.json`:
   ```bash
   bash .claude/skills/operations-with-issue-tracker/scripts/get.sh \
     --id <us_id> --type Task
   ```
3. Query tracker for linked test cases:
   ```bash
   bash .claude/skills/operations-with-issue-tracker/scripts/query.sh \
     --filter "parent_us_id:<us_id>" --type "Test Case"
   ```
4. For each returned TC, fetch full details:
   ```bash
   bash .claude/skills/operations-with-issue-tracker/scripts/get.sh \
     --id <tc_tracker_id> --type "Test Case"
   ```
5. Reconstruct `tc-{index}.json` for each TC from the tracker response. Map available fields:
   - `tracker_id` ← tracker record ID
   - `title`, `scenario`, `parent_us_id` ← from tracker fields
   - `ideas`, `verifications`, `navigations`, `conditions`, `ac_trace`, `reusable_helpers` ← from tracker step data if available; otherwise leave as empty arrays and emit a warning per TC
   - `id` ← generate as `tc-{timestamp}` if not stored
6. Write each `tc-{index}.json` to `.workflow-artifacts/<gts-run-id>/`.

If zero TCs are returned, stop and report: "No test cases found linked to story {us_id} in the tracker."

Show checkpoint: `✓ Fetched N test cases for story {us_id}`

## Phase compact protocol

After each phase (and each per-TC iteration) completes, emit a compact
JSON block and drop all full phase output from active context. This is mandatory
— long pipelines with many TC iterations will overflow context without it.

**Rules:**
1. After a phase skill finishes, immediately emit a `<!-- PHASE COMPACT -->` block.
2. The block contains only the fields listed below for that phase.
3. All other output from that phase is dropped from active context after the block.
4. For the per-TC loop, emit one compact block per phase per iteration.
5. Use only compact block fields when referencing past phases or building the summary.

**Format:**
```json
<!-- PHASE COMPACT: {phase_label} tc={index} -->
{
  "phase": "<phase_label>",
  "tc_index": <N>,
  "status": "SUCCESS | FAILED | SKIPPED",
  <phase-specific fields>
}
```

**Fields to retain per phase:**

| Phase | Retain |
|---|---|
| Fetch Test Cases (1) | `us_id`, `title`, `tc_count` |
| gt-spec-writer (2b) | `status`, `spec_path`, `tc_id`, `last_error` |
| gt-refactor-tests (2c) | `fixes_applied`, `spec_path` |

### Phase 2 — Per-TC Spec Loop

For each `tc-{index}.json` in the artifact directory:

#### Phase 2b — Spec (`gt-spec-writer`)

Invoke with `tc-{index}.json`.

- Resume: if `spec-{index}.json` already exists, skip and continue
- **SUCCESS, passing:** continue to Phase 2c
- **SUCCESS, failing:** route to `ft-bug-reporter` only (not full Pipeline B); record as `[BUG_REPORTED]` in summary

#### Phase 2b-bug — Bug report (`ft-bug-reporter`) — failing specs only

Invoke with `spec-{index}.json` and `tc-{index}.json`.

#### Phase 2c — Refactor (`gt-refactor-tests`) — passing specs only

Invoke in pipeline mode on the new spec file.

Record outcome in the per-TC status.

### Phase 3 — Final summary

Output a table:

```
| # | TC ID           | Scenario                                    | Spec Path                    | Status   | Notes         |
|---|-----------------|---------------------------------------------|------------------------------|----------|---------------|
| 0 | tc-1234567890   | [P1] Auth: Login with valid credentials     | tests/auth/login-valid.spec.ts | PASSING  |               |
| 1 | tc-1234567891   | [P1] Auth: Login with invalid password      | tests/auth/login-invalid.spec.ts | PASSING |               |
| 2 | tc-1234567892   | [P2] Auth: Login with empty username        | tests/auth/login-empty.spec.ts | FAILING  | Bug reported  |

Run ID: gts-20240601-143012
Total: 3 TCs | 2 passing | 1 failing (bug reported)
Ship: PR https://github.com/org/repo/pull/42  (or "skipped — no passing specs")
```

### Phase 4 — Ship (`gf-ship`)

**Precondition:** at least one `spec-{index}.json` exists with `status: "passing"`.

Collect all passing spec file paths. Derive `us_id` from `us.json.id`. Count passing specs as `passing_count`.

If `us.json.id` is `"manual"`, use `run_id` as fallback: `work-item-id = gts-{run_id}`.

**If no passing specs exist**, emit:
```
WARNING: No passing specs in this run. gf-ship skipped.
Run ID: {run_id}
```
and stop — do not invoke `gf-ship`.

**Otherwise** invoke `gf-ship` with:
- `work-item-id`: `gts-{us_id}`
- `commit-type`: `test`, `commit-scope`: `specs`
- `commit-subject`: `add {passing_count} Playwright specs for story {us_id}`
- `files`: all passing spec file paths (space-separated)
- `base`: `${CORE_BRANCH:-master}`

- **SUCCESS:** include `pr_url` and `branch_name` in the Phase 3 summary footer.
- **FAILED:** report error and stop.

## Hard rules

**Bash execution — fully agentic, zero prompts:**
- Run all bash commands directly: `bash .claude/skills/...` — never prefix with `cd /path &&` or `source .env &&`; the working directory and env are already set.
- Do not chain env-var exports before bash calls; the scripts source `.env` via `_common.sh` automatically.
- Never use compound `cd && source && bash` forms — they bypass the permission allowlist and trigger prompts.

**Autonomous execution — never pause for human input:**
- Do not ask the user to confirm any phase, TC skip, or git operation.
- Do not add "shall I proceed?" or approval gates anywhere in the flow.
- `gt-refactor-tests` in pipeline mode: apply all **MUST FIX** items automatically; apply clear-cut **CAN FIX** items without asking; skip subjective or high-risk CAN FIX items; never apply SKIP items.
- Bug reporting for a failing spec proceeds without confirmation.
- `gf-ship` at Phase 4 proceeds without confirmation when the precondition is met.
- If a non-critical phase fails (any Phase 2b/2c/2b-bug iteration), log the failure for that TC and continue — do not abort the entire pipeline.
- Phases 0, 1, and 4 use `on_failure: stop` — a failure there aborts everything.

**Artifact contracts:**
- Generate a `run_id` at start with prefix `gts` and use it consistently for all artifacts.
- Explicit invocation only — for any partial flow use individual `gt-*` skills.
- Resume-safe: if `spec-{index}.json` already exists for a TC, skip that TC's spec phase.
- If a spec fails on first run, route to `ft-bug-reporter` only — do not run full Pipeline B.
- Tracker and git operations go through wrapper skills/scripts only.
- Keep handoff contracts file-based — never pass raw JSON between stages as text.

**Phase compact:**
- Emit a compact block after every phase and after every per-TC iteration.
- Drop all non-compact phase output from active context immediately after emitting.
- Omitting compaction on long runs causes context overflow — this rule is non-negotiable.
