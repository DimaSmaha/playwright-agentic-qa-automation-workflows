---
name: gt-us-to-spec
description: >
  EXPLICIT-INVOCATION ONLY. Orchestrator for Pipeline A (User Story → Automated
  Test). Use only when the caller explicitly requests a full end-to-end flow from
  user story to Playwright spec artifacts. For any partial flow, invoke the
  individual gt-* skills directly instead.
---

# gt-us-to-spec

EXPLICIT-INVOCATION ONLY.

> **NEVER re-ask the user for any input, confirmation, or clarification during execution.**
> All decisions are resolved from artifacts and env vars. Stop-and-report is the only permitted response to missing inputs.

For any partial flow (just planning, just ideation, just one spec), use the
individual `gt-*` skills instead of this orchestrator.

Run full Pipeline A: planner → ideation → per-scenario (test case + spec + refactor) → ship.

## Pipeline schema

On start, read `.claude/skills/gt-us-to-spec/pipeline.json`.
This file is the authoritative definition of all phases, loop structure,
artifact contracts, resume-skip conditions, and compaction fields.
Use it as the execution manifest throughout.

## When this skill fits

Use it for requests like:

- "run the full pipeline from this user story to Playwright specs"
- "end-to-end: user story to automated tests"
- "generate everything from story 112"

Do **not** use it for:

- generating scenarios only (use `gt-story-planner`)
- writing one spec (use `gt-spec-writer`)
- creating one test case (use `gt-test-case-generator`)

## Inputs

Either:
- `--us-id <id>` — fetch from tracker
- `--us-text "<title + description>"` — paste directly

If neither provided, stop immediately and report: "gt-us-to-spec requires --us-id or --us-text. Invoke with one of these inputs."

## Workflow

### Phase 0 — Initialize

```bash
run_id="$(bash .claude/skills/gt-us-to-spec/scripts/init.sh)"
```

Confirm ISSUE_TRACKER and FAKE_TRACKER_URL (or other tracker vars) are set. If missing, stop and report exactly which vars are absent — do not ask interactively.

### Phase 1 — Plan (`gt-story-planner`)

Invoke `gt-story-planner` with the user story input.

- **SUCCESS:** `us.json` and `scenarios.md` written
- **FAILED:** stop and report

Show checkpoint: `✓ Scenarios planned: N scenarios (M skipped as already covered)`

### Phase 2 — Ideation (`gt-test-ideation`)

Invoke `gt-test-ideation` with `us.json` and `scenarios.md`.

- **SUCCESS:** `test-ideas.json` written
- **FAILED:** stop and report

Show checkpoint: `✓ Test ideas generated: N ideation units`

## Phase compact protocol

After each phase (and each per-scenario iteration) completes, emit a compact
JSON block and drop all full phase output from active context. This is mandatory
— long pipelines with many scenario iterations will overflow context without it.

**Rules:**
1. After a phase skill finishes, immediately emit a `<!-- PHASE COMPACT -->` block.
2. The block contains only the fields listed below for that phase.
3. All other output from that phase is dropped from active context after the block.
4. For the per-scenario loop, emit one compact block per phase per iteration.
5. Use only compact block fields when referencing past phases or building the summary.

**Format:**
```json
<!-- PHASE COMPACT: {phase_label} scenario={index} -->
{
  "phase": "<phase_label>",
  "scenario_index": <N>,
  "status": "SUCCESS | FAILED | SKIPPED",
  <phase-specific fields>
}
```

**Fields to retain per phase:**

| Phase | Retain |
|---|---|
| gt-story-planner (1) | `us_id`, `title`, `scenario_count` |
| gt-test-ideation (2) | `total_ideas`, `scenario_count` |
| gt-test-case-generator (3a) | `tc_id`, `scenario_index`, `title`, `deduped` |
| gt-spec-writer (3b) | `status`, `spec_path`, `tc_id`, `last_error` |
| gt-refactor-tests (3c) | `fixes_applied`, `spec_path` |

All other data (ideation arrays, tracker API responses, full error stacks)
remains in artifact files on disk — access by path if needed. Omitting
compaction on long runs causes context overflow — this rule is non-negotiable.

### Phase 3 — Per-scenario loop

For each non-SKIP scenario in `scenarios.md`:

#### Phase 3a — Test case (`gt-test-case-generator`)

Invoke with `test-ideas.json` and the current `scenario_index`.

- Resume: if `tc-{index}.json` already exists, skip and continue
- **SUCCESS:** `tc-{index}.json` written

#### Phase 3b — Spec (`gt-spec-writer`)

Invoke with `tc-{index}.json`.

- Resume: if `spec-{index}.json` already exists, skip and continue
- **SUCCESS, passing:** continue to 3c
- **SUCCESS, failing:** route to `ft-bug-reporter` only (not full Pipeline B); record as `[BUG_REPORTED]` in summary

#### Phase 3c — Refactor (`gt-refactor-tests`) — passing specs only

Invoke in Validation Mode on the new spec file.

Record outcome in the per-scenario status.

### Phase 4 — Final summary

Output a table:

```
| # | Scenario                                    | TC ID           | Spec Path                    | Status   | Notes         |
|---|---------------------------------------------|-----------------|------------------------------|----------|---------------|
| 0 | [P1] Auth: Login with valid credentials     | tc-1234567890   | tests/auth/login-valid.spec.ts | PASSING  |               |
| 1 | [P1] Auth: Login with invalid password      | tc-1234567891   | tests/auth/login-invalid.spec.ts | PASSING |               |
| 2 | [P2] Auth: Login with empty username        | tc-1234567892   | tests/auth/login-empty.spec.ts | FAILING  | Bug reported  |
| 3 | [SKIP] Auth: Logout flow                    | —               | —                            | SKIPPED  | Already covered |

Run ID: gt-20240601-143012
Total: 4 scenarios | 2 passing | 1 failing (bug reported) | 1 skipped
Ship: PR https://github.com/org/repo/pull/42  (or "skipped — no passing specs")
```

### Phase 5 — Ship (`gf-ship`)

**Precondition:** at least one `spec-{index}.json` exists with `status: "passing"`.

Collect all passing spec file paths. Derive `us_id` from `us.json.id`. Count passing specs as `passing_count`.

If `us.json.id` is `"manual"`, use `run_id` as fallback: `work-item-id = gt-{run_id}`.

**If no passing specs exist**, emit:
```
WARNING: No passing specs in this run. gf-ship skipped.
Run ID: {run_id}
```
and stop — do not invoke `gf-ship`.

**Otherwise** invoke `gf-ship` with:
- `work-item-id`: `gt-{us_id}`
- `commit-type`: `test`, `commit-scope`: `specs`
- `commit-subject`: `add {passing_count} Playwright specs for story {us_id}`
- `files`: all passing spec file paths (space-separated)
- `base`: `${CORE_BRANCH:-master}`

- **SUCCESS:** include `pr_url` and `branch_name` in the Phase 4 summary footer.
- **FAILED:** report error and stop.

## Hard rules

**Autonomous execution — never pause for human input:**
- Do not ask the user to confirm any phase, scenario skip, or git operation.
- Do not add "shall I proceed?" or approval gates anywhere in the flow.
- `gt-refactor-tests` in pipeline mode: apply all **MUST FIX** items automatically; apply clear-cut **CAN FIX** items (naming, fixture consolidation, locator hygiene with existing page object coverage) without asking; skip subjective or high-risk CAN FIX items; never apply SKIP items.
- Bug reporting for a failing spec proceeds without confirmation.
- `gf-ship` at Phase 5 proceeds without confirmation when the precondition is met.
- If a non-critical phase fails (any Phase 3a/3b/3c/3b-bug iteration), log the failure in the scenario row and continue to the next scenario — do not abort the entire pipeline.
- Phases 0, 1, 2, and 5 use `on_failure: stop` — a failure there aborts everything.

**Artifact contracts:**
- Generate a `run_id` at start and use it consistently for all artifacts.
- Explicit invocation only — for any partial flow use individual `gt-*` skills.
- Resume-safe: if stage artifacts already exist for a scenario, skip that stage.
- If a spec fails on first run, route to `ft-bug-reporter` only — do not run full Pipeline B.
- Tracker and git operations go through wrapper skills/scripts only.
- Keep handoff contracts file-based — never pass raw JSON between stages as text.

**Phase compact:**
- Emit a compact block after every phase and after every per-scenario iteration.
- Drop all non-compact phase output from active context immediately after emitting.
- See "Phase compact protocol" section. Omitting compaction on long runs causes context overflow — this rule is non-negotiable.
