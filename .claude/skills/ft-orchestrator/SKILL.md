---
name: ft-orchestrator
description: >
  EXPLICIT-INVOCATION ONLY. Single-flow orchestrator for the full ft Pipeline B
  chain. Use when the user wants one end-to-end failure triage run from failing
  spec input to classified outcome and routed action (test-fix PR or app-bug
  report). For any partial flow, use the individual ft-* or gf-* skills instead.
---

# ft-orchestrator

EXPLICIT-INVOCATION ONLY.

Coordinate `ft-repro` → `ft-classifier` → `ft-test-fix-runner` or `ft-bug-reporter`
as sequential phases with deterministic artifact handoffs.

## Pipeline schema

On start, read `.claude/skills/ft-orchestrator/pipeline.json`.
This file is the authoritative definition of all phases, artifact contracts,
routing conditions, resume-skip rules, and compaction fields.
Use it as the execution manifest — do not deviate from phase order or artifact
names defined there.

## When this skill fits

Use it for requests like:

- "triage this failing test end-to-end"
- "run the full Pipeline B flow"
- "reproduce, classify, and fix or report this test failure"

Do **not** use it for:

- running a single stage (call the individual ft-* skill instead)
- triaging multiple failing tests at once (run once per spec)
- merging or managing branches

## What you need before starting

- A failing spec path
- `ISSUE_TRACKER` and tracker-specific env vars set (e.g. `FAKE_TRACKER_URL` for fake tracker)
- `GITHUB_TOKEN` set (required if the verdict routes to `ft-test-fix-runner` → PR)

If tracker or GitHub token vars are missing, note which phases may be blocked and ask if you should proceed.

## Workflow

### Phase 0 — Initialize

```bash
run_id=$(bash .claude/skills/ft-orchestrator/scripts/init-run.sh)
```

Confirm the spec path exists. If not provided, stop and report the missing argument — do not ask interactively.

### Phase 1 — Reproduce (`ft-repro`)

Invoke `ft-repro` with the spec path and `run_id`.

- **SUCCESS:** `repro.json` written to `.workflow-artifacts/{run_id}/`
- **FAILED:** stop, report the error, suggest checking if the spec path is correct

### Phase 2 — Classify (`ft-classifier`)

Invoke `ft-classifier` with the `repro.json` from Phase 1.

- **SUCCESS:** `classification.json` written with a verdict and confidence
- **FAILED:** stop and report

### Phase 3 — Route by verdict

| Verdict | Confidence | Action |
|---|---|---|
| `test-bug` | ≥ 0.55 | Phase 3A: Invoke `ft-test-fix-runner` |
| `app-bug` | ≥ 0.60 | Phase 3B: Invoke `ft-bug-reporter` |
| `flaky` | ≥ 0.45 | Report as flaky; suggest retry annotation; no code change |
| `infra` | ≥ 0.65 | Report infrastructure issue; no code change |
| `needs-human` | any | Present signals and stop; human decision required |

## Phase compact protocol

After each phase completes, emit a compact JSON block and drop all full phase
output from active context. This prevents context overflow in long runs.

**Rules:**
1. Immediately after a phase skill finishes, emit a `<!-- PHASE COMPACT -->` block.
2. The block contains only the fields listed below for that phase.
3. All other output from that phase is dropped from active context after the block.
4. Reference only compact block fields when invoking subsequent phases.

**Format:**
```json
<!-- PHASE COMPACT: {phase_label} -->
{
  "phase": "<phase_label>",
  "status": "SUCCESS | FAILED",
  <phase-specific fields>
}
```

**Fields to retain per phase:**

| Phase | Retain |
|---|---|
| ft-repro (1) | `run_id`, `spec`, `error_summary`, `artifacts_paths[]` |
| ft-classifier (2) | `verdict`, `confidence`, `recommended_next_skill` |
| ft-test-fix-runner (3A) | `verdict`, `spec`, `fix_type` |
| ft-bug-reporter (3B) | `id`, `url`, `severity`, `deduped` |
| gf-ship (3A-git) | `verdict`, `pr_url`, `branch_name` |

All other data (full stacks, signals arrays, evidence paths) remains on disk in
artifact files — access by path if needed.

**Phase 3A — Test fix (`ft-test-fix-runner`):**
- **SUCCESS:** `fix.json` written with `verdict: "success"`; proceed to Phase 3A-git
- **FAILED / needs-human:** report what was tried, stop

**Phase 3A-git — Ship the fix via `gf-ship` (only after fix.json verdict = "success"):**

Invoke `gf-ship` with:
- `work-item-id`: `fix-{run_id}`
- `commit-type`: `fix`, `commit-scope`: `test`
- `commit-subject`: `{fix_type} in {spec_basename}` (values from fix.json)
- `files`: the modified spec file path only
- `base`: `${CORE_BRANCH:-master}`

On completion, patch `fix.json` by adding `pr_url` and `branch_name` from
`gf-ship` JSON output. If `gf-ship` fails, report the error and stop — do not retry.

**Phase 3B — Bug report (`ft-bug-reporter`):**
- **SUCCESS:** `bug.json` written, bug created in tracker
- **FAILED:** report error

### Phase 4 — Final summary

Output a phase table:

```
| Phase  | Skill              | Status  | Output                                         |
|--------|--------------------|---------|------------------------------------------------|
| 1      | ft-repro           | SUCCESS | .workflow-artifacts/ft-.../repro.json          |
| 2      | ft-classifier      | SUCCESS | verdict: test-bug, confidence: 0.85            |
| 3A     | ft-test-fix-runner | SUCCESS | fix.json (verdict: success)                    |
| 3A-git | gf-ship            | SUCCESS | PR: https://github.com/.../pull/88             |

Run ID:    ft-20240601-143012
Verdict:   test-bug (0.85)
Action:    Test fix shipped
Result:    https://github.com/org/repo/pull/88
```

## Hard rules

**Autonomous execution — never pause for human input:**
- Do not ask the user to confirm any phase, routing decision, or git operation.
- Do not add "shall I proceed?" or approval gates anywhere in the flow.
- Bug reporting proceeds without confirmation — invoke `ft-bug-reporter` automatically when verdict is `app-bug`.
- All git operations via `gf-ship` proceed without confirmation.
- The only permitted stop conditions are: phase failure, a `needs-human` verdict from `ft-classifier`, or `verdict: "needs-human"` from `ft-test-fix-runner`.
- If env vars are missing for phases that need them, stop and report what is missing — do not ask for them interactively.

**Artifact contracts:**
- All artifacts live in `.workflow-artifacts/{run_id}/` — use consistent `run_id` throughout.
- Always pass `run_id` explicitly to every downstream skill invocation. Never allow a child skill to generate a new run_id.
- Explicit invocation only — for any partial flow, use the individual ft-* or gf-* skills.
- Stop on first phase failure; do not continue to later phases.
- Tracker and git operations always go through the wrapper skills/scripts.
- Return the PR URL or bug URL exactly — do not invent or guess.

**Phase compact:**
- Emit a compact block after every phase. See "Phase compact protocol" section.
- Drop all non-compact phase output from active context immediately after emitting.
