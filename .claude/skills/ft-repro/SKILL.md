---
name: ft-repro
description: >
  Deterministic Playwright failure reproduction and signal extraction for Pipeline
  B. Use when a failing test must be re-run in a controlled way to produce
  repro.json plus evidence artifacts (trace, video, screenshot) for downstream
  classification. Trigger on requests like "reproduce this failing test",
  "collect Playwright failure artifacts", or "generate repro.json from a red test".
---

# ft-repro

Re-run one failing Playwright spec, collect all failure artifacts, and emit a
normalized `repro.json` for the classifier stage.

## When this skill fits

Use it for requests like:

- "reproduce this failing test"
- "collect failure artifacts from this spec"
- "get repro.json for Pipeline B"
- "run this test and capture what went wrong"

Do **not** use it for:

- classifying why a test failed (use `ft-classifier`)
- fixing a test (use `ft-test-fix-runner`)
- running the full test suite

## What comes before and after

- **Before:** a failing test spec path (from CI output, from the user, or from `.last-run.json`)
- **After:** `ft-classifier` reads `repro.json`

## Inputs

**Required:** spec path relative to the project root (e.g. `tests/critical-checkout-validation-fail.spec.ts`)

If the spec path is not provided, check `.workflow-artifacts/` for a recent run or ask:

```text
Which spec file failed? Please provide the relative path (e.g. tests/my-test.spec.ts)
```

## Workflow

### 1. Validate the spec exists

Check that the file exists:

```bash
test -f <spec-path>
```

If missing, stop and tell the user.

### 2. Generate a run_id

```bash
run_id="ft-$(date +%Y%m%d-%H%M%S)"
mkdir -p ".workflow-artifacts/${run_id}"
```

### 3. Run the failing test

```bash
npx playwright test <spec-path> \
  --project=chromium \
  --reporter=json \
  2>&1 | tee ".workflow-artifacts/${run_id}/pw-output.json"
```

Use `npm` / `npx`, **not** `pnpm`. Run with `--project=chromium` for reproducibility.

The test is expected to fail — a non-zero exit code is normal here.

### 4. Extract failure signals from the JSON reporter output

Parse `.workflow-artifacts/{run_id}/pw-output.json`. Navigate:

```
suites[] → specs[] → tests[] → results[] → errors[]
```

Extract from the first error in the first failed result:

| Field | Where to find it |
|---|---|
| `error` | `errors[0].message` (first line only) |
| `stack` | `errors[0].stack` |
| `locator` | Regex-extract from error message: `locator\('(.+?)'\)` or `getBy\w+\(.*?\)` |
| `expected` | Regex-extract: `Expected: (.+)` |
| `actual` | Regex-extract: `Received: (.+)` |

If the test crashed before producing JSON (e.g. `Cannot find module`), capture
raw stderr instead and set `error` to the first non-empty line.

### 5. Locate evidence artifacts

After the test run, Playwright writes artifacts to `test-results/`. Look for:

```bash
find test-results/ -name "trace.zip" | head -1
find test-results/ -name "*.png"     | head -1
find test-results/ -name "*.webm"    | head -1
```

Copy found artifacts into `.workflow-artifacts/{run_id}/`:

```bash
cp <trace>      ".workflow-artifacts/${run_id}/trace.zip"
cp <screenshot> ".workflow-artifacts/${run_id}/fail.png"
cp <video>      ".workflow-artifacts/${run_id}/video.webm"
```

Set the corresponding field to `null` if an artifact is not found.

### 6. Write repro.json

Write `.workflow-artifacts/{run_id}/repro.json`:

```json
{
  "run_id": "ft-20240601-143012",
  "spec": "tests/critical-checkout-validation-fail.spec.ts",
  "error": "TimeoutError: Timed out 30000ms waiting for expect(locator).toBeVisible()",
  "stack": "...",
  "locator": "page.getByRole('button', { name: 'Finish' })",
  "expected": "visible",
  "actual": "hidden",
  "artifacts": {
    "trace": ".workflow-artifacts/ft-20240601-143012/trace.zip",
    "screenshot": ".workflow-artifacts/ft-20240601-143012/fail.png",
    "video": ".workflow-artifacts/ft-20240601-143012/video.webm"
  }
}
```

### 7. Output

Print the path to `repro.json` and a one-line summary of the error.
Tell the user: "Pass this to `ft-classifier` for triage."

## Hard rules

- Reproduce **one spec per run** only.
- Use `npx` not `pnpm exec`.
- Write deterministic artifact paths inside `.workflow-artifacts/{run_id}/`.
- Do not emit free-form logs as primary output — JSON contract only.
- A non-zero exit from Playwright is expected when the test is failing; do not treat it as a script error.
