---
name: gt-spec-writer
description: >
  Pipeline A stage that converts tracker test case artifacts into runnable
  Playwright specs and execution status outputs. Use when asked to write a spec
  from tc.json, generate an automated Playwright test from a test case, or run
  first-pass spec execution with structured pass/fail artifacts.
---

# gt-spec-writer

Generate and execute Playwright spec files from `tc.json`, then emit normalized
status artifacts for orchestration.

## Input

- `tc.json`

## Flow

1. Read `tc.json`.
2. Perform mandatory reuse check against existing helpers/page objects.
3. If locator is missing, use `playwright-cli` to inspect UI and recover selectors.
4. Write spec to `playwright/tests/<domain>/<kebab-case>.spec.ts`.
5. Execute Playwright run.
6. Emit `spec.json`.

## Output contract (`spec.json`)

```json
{
  "path": "playwright/tests/domain/example.spec.ts",
  "status": "passing|failing",
  "last_error": null,
  "tc_id": 11111,
  "parent_us_id": 11110
}
```

## Failure routing

If first execution fails with faithful test-case transcription, route to
Pipeline B bug-report leg and preserve artifacts.

## Rules

1. Keep outputs deterministic and file-contract based.
2. Avoid inline locator anti-patterns; prefer page-object usage.
3. Emit JSON-only primary output.
4. Do not perform shipping/PR actions in this stage.
