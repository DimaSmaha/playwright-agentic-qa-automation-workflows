---
name: ft-repro
description: >
  Deterministic Playwright failure reproduction and signal extraction for Pipeline
  B. Use when a failing test must be re-run in a controlled way to produce
  repro.json plus evidence artifacts (trace, video, screenshot) for downstream
  classification. Trigger on requests like "reproduce this failing test",
  "collect Playwright failure artifacts", or "generate repro.json from a red
  test".
---

# ft-repro

This skill reproduces one failing Playwright test and emits a normalized
`repro.json` contract for the classifier stage.

## Goal

- Re-run a target spec deterministically
- Collect failure artifacts
- Extract structured failure signals
- Output machine-readable JSON only

## Run command

```bash
pnpm exec playwright test <spec> \
  --project=<browser> \
  --reporter=json
```

## Required capture

- stdout/stderr
- `trace.zip`
- failure video
- failure screenshot

## Required extraction fields

- `error`
- `stack`
- `locator`
- `expected`
- `actual`
- `artifacts.trace`
- `artifacts.video`
- `artifacts.screenshot`

## Output contract (`repro.json`)

```json
{
  "error": "...",
  "stack": "...",
  "locator": "...",
  "expected": "...",
  "actual": "...",
  "artifacts": {
    "trace": "trace.zip",
    "video": "video.mp4",
    "screenshot": "fail.png"
  }
}
```

## Rules

1. Reproduce only one failure target per run.
2. Do not return free-form logs as the primary output.
3. Write deterministic paths for artifacts.
4. Keep output idempotent across retries.

## Downstream

Pass `repro.json` to `ft-classifier`.
