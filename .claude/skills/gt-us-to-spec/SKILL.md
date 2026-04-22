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

For any partial flow (just planning, just ideation, just one spec), use the
individual `gt-*` skills instead of this orchestrator.

Run full Pipeline A: planner → ideation → per-scenario (test case + spec + refactor).

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

If neither provided, ask before starting.

## Workflow

### Phase 0 — Initialize

```bash
run_id="gt-$(date +%Y%m%d-%H%M%S)"
mkdir -p ".workflow-artifacts/${run_id}"
```

Confirm ISSUE_TRACKER and FAKE_TRACKER_URL (or other tracker vars) are set.

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
```

## Hard rules

- **Explicit invocation only** — for any partial flow use individual `gt-*` skills.
- Generate a `run_id` at start and use it consistently for all artifacts.
- Resume-safe: if stage artifacts already exist for a scenario, skip that stage.
- If a spec fails on first run, route to `ft-bug-reporter` only — do not run full Pipeline B.
- Tracker and git operations go through wrapper skills/scripts only.
- Keep handoff contracts file-based — never pass raw JSON between stages as text.
