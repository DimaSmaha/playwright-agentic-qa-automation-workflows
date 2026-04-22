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
run_id="ft-$(date +%Y%m%d-%H%M%S)"
mkdir -p ".workflow-artifacts/${run_id}"
```

Confirm the spec path exists. If not provided, ask.

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
| `test-bug` | ≥ 0.70 | Phase 3A: Invoke `ft-test-fix-runner` |
| `app-bug` | ≥ 0.75 | Phase 3B: Invoke `ft-bug-reporter` |
| `flaky` | ≥ 0.60 | Report as flaky; suggest retry annotation; no code change |
| `infra` | ≥ 0.80 | Report infrastructure issue; no code change |
| `needs-human` | any | Present signals and stop; human decision required |

**Phase 3A — Test fix (`ft-test-fix-runner`):**
- **SUCCESS:** `fix.json` written, PR URL available
- **FAILED / needs-human:** report what was tried, stop

**Phase 3B — Bug report (`ft-bug-reporter`):**
- **SUCCESS:** `bug.json` written, bug created in tracker
- **FAILED:** report error

### Phase 4 — Final summary

Output a phase table:

```
| Phase | Skill              | Status  | Output                               |
|-------|--------------------|---------|--------------------------------------|
| 1     | ft-repro           | SUCCESS | .workflow-artifacts/ft-.../repro.json |
| 2     | ft-classifier      | SUCCESS | verdict: test-bug, confidence: 0.85  |
| 3A    | ft-test-fix-runner | SUCCESS | PR: https://github.com/.../pull/88   |

Run ID:    ft-20240601-143012
Verdict:   test-bug (0.85)
Action:    Test fix shipped
Result:    https://github.com/org/repo/pull/88
```

## Hard rules

- **Explicit invocation only** — for any partial flow, use the individual ft-* skills.
- Stop on first phase failure; do not continue to later phases.
- All artifacts live in `.workflow-artifacts/{run_id}/` — use consistent run_id throughout.
- Tracker and git operations always go through the wrapper skills/scripts.
- Return the PR URL or bug URL exactly — do not invent or guess.
