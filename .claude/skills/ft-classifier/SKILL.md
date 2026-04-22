---
name: ft-classifier
description: >
  Signal-based classification for Playwright failures in Pipeline B. Use when a
  repro.json result must be classified into test-bug, app-bug, flaky, infra, or
  needs-human, with confidence and recommended next skill. Trigger on requests
  like "classify this Playwright failure", "decide whether this is test or app
  bug", or "produce classification.json from repro artifacts".
---

# ft-classifier

Score evidence signals from `repro.json` and emit a stable `classification.json`
verdict for routing to `ft-test-fix-runner` or `ft-bug-reporter`.

## When this skill fits

Use it for requests like:

- "classify this Playwright failure"
- "is this a test bug or an app bug?"
- "produce classification.json for triage"
- "decide what to do with this failing test"

Do **not** use it for:

- running the test (use `ft-repro` first)
- fixing the test (use `ft-test-fix-runner`)
- filing a bug (use `ft-bug-reporter`)

## What comes before and after

- **Before:** `ft-repro` produces `repro.json`
- **After:** route to `ft-test-fix-runner` (test-bug) or `ft-bug-reporter` (app-bug)

## Inputs

**Required:** `repro.json` from `ft-repro`

If `repro.json` is not present:
1. Check `.workflow-artifacts/` for the most recent `repro.json`
2. If not found, ask the user for the spec path and invoke `ft-repro` first

## Workflow

### 1. Read repro.json

Load `error`, `stack`, `locator`, `expected`, `actual`, and `artifacts` fields.

### 2. Score signals

Apply these rules to the `error` and `stack` strings. Accumulate a score per verdict.

| Pattern in error/stack | Verdict | Weight |
|---|---|---|
| `"strict mode violation"` | test-bug | +0.85 |
| `"locator.locator() resolved to N elements"` | test-bug | +0.80 |
| `"No element found"` / locator not found on first attempt | test-bug | +0.75 |
| `net::ERR_` / `ERR_CONNECTION_REFUSED` / `ERR_ABORTED` | infra | +0.85 |
| `"Element is not attached to the DOM"` | flaky | +0.70 |
| `TimeoutError` + test **passes on retry** (check `repro.json.artifacts` for retry data) | flaky | +0.70 |
| `TimeoutError` + test fails **every run** | app-bug | +0.55 |
| Assertion mismatch (`Expected: / Received:`) | ambiguous — go to step 3 | — |
| Consistent failure 2+ runs with no selector change | app-bug | +0.30 bonus |

The verdict with the highest total score wins.

### 3. App exploration (mandatory for ambiguous cases)

If the verdict after step 2 is ambiguous (assertion mismatch, unclear timeout,
multiple competing signals), or if `app-bug` score is above 0.4 but below 0.75:

**Use `playwright-cli` to explore the live app:**

1. Open the URL that the failing test navigates to (read from `repro.json.spec` to find the `goto` call)
2. Navigate through the test path up to the point of failure
3. Observe: does the element exist? Is the expected value/state present in the live app?
4. Document your observations — e.g. "element IS visible in live app → suggests test selector is wrong (test-bug)" or "element is missing from the live app → app regression (app-bug)"

Feed these observations into your signal weights.

### 4. Set confidence and check thresholds

| Verdict | Minimum confidence to route |
|---|---|
| `test-bug` | 0.55 |
| `app-bug` | 0.60 |
| `flaky` | 0.45 |
| `infra` | 0.65 |

If no verdict meets its threshold, set verdict to `needs-human`.

### 5. Write classification.json

Write to the same `.workflow-artifacts/{run_id}/` folder as `repro.json`:

```json
{
  "verdict": "test-bug",
  "confidence": 0.85,
  "signals": [
    { "name": "strict mode violation", "weight": 0.85 },
    { "name": "playwright-cli confirmed element exists in live app", "weight": 0.20 }
  ],
  "error_summary": "Locator matched multiple elements — selector needs to be more specific",
  "evidence_paths": [
    ".workflow-artifacts/ft-20240601-143012/trace.zip",
    ".workflow-artifacts/ft-20240601-143012/fail.png"
  ],
  "recommended_next_skill": "ft-test-fix-runner"
}
```

### 6. Routing guidance

Tell the user which skill to invoke next:

| Verdict | Action |
|---|---|
| `test-bug` ≥ 0.70 | Invoke `ft-test-fix-runner` |
| `app-bug` ≥ 0.75 | Invoke `ft-bug-reporter` |
| `flaky` ≥ 0.60 | Mark test as flaky; consider adding retry annotation |
| `infra` ≥ 0.80 | Infrastructure issue — check network/server; no code change |
| `needs-human` | Present the signals and ask the user to decide |

## Hard rules

- Emit exactly one verdict.
- Include explicit signal weights so reasoning is auditable.
- Always do app exploration (step 3) for assertion mismatches and ambiguous timeouts.
- If confidence is below threshold, always return `needs-human` — never force a low-confidence verdict.
- JSON-only primary output.
