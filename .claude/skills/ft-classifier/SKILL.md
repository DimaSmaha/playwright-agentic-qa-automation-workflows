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

This skill consumes `repro.json`, scores evidence signals, and emits a stable
`classification.json` decision for the next pipeline step.

## Input

- `repro.json` from `ft-repro`

## Verdict space

- `test-bug`
- `app-bug`
- `flaky`
- `infra`
- `needs-human`

## Signal guidance

- locator missing → bias toward `test-bug`
- timeout waiting → `flaky` or `app-bug`
- assertion mismatch → ambiguous
- network error → `infra`
- element detached → `flaky`
- consistent failure across retries → `app-bug`

## Output contract (`classification.json`)

```json
{
  "verdict": "test-bug|app-bug|flaky|infra|needs-human",
  "confidence": 0.0,
  "signals": [{ "name": "...", "weight": 0.0 }],
  "error_summary": "...",
  "evidence_paths": ["trace.zip", "fail.png"],
  "recommended_next_skill": "ft-test-fix-runner|ft-bug-reporter|none"
}
```

## Decision rules

1. Emit exactly one verdict.
2. Include explicit signal weights to make reasoning auditable.
3. If confidence is below project threshold, return `needs-human`.
4. Keep output JSON-only and deterministic.

## Routing

- `test-bug` with threshold met → `ft-test-fix-runner`
- `app-bug` with threshold met → `ft-bug-reporter`
- `flaky` → mark flaky + retry policy
- `infra` or low confidence → stop/escalate
