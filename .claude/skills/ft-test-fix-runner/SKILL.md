---
name: ft-test-fix-runner
description: >
  Automated test-side fix execution for Pipeline B after ft-classifier identifies
  a high-confidence test-bug. Use when classification.json recommends test repair
  and a safe git workflow must create a PR. Trigger on requests like "fix
  test-bug and open PR", "run classified test fix flow", or "apply test fix from
  classification".
---

# ft-test-fix-runner

Apply a targeted test-only fix for a classified `test-bug`, verify it passes,
then ship it via a branch-to-PR git workflow.

## When this skill fits

Use it for requests like:

- "fix this test-bug and open a PR"
- "apply the classified test fix"
- "repair the failing test selector"
- "fix the test and ship it"

Do **not** use it for:

- `app-bug` verdicts (use `ft-bug-reporter`)
- low-confidence classifications (< 0.70)
- changing application source code

## What comes before and after

- **Before:** `ft-classifier` produces `classification.json` with `verdict: "test-bug"`
- **After:** a PR is opened on GitHub via `gf-branch → gf-commit → gf-push → gf-pr`

## Inputs

**Required:**
- `classification.json` — must have `verdict: "test-bug"` and `confidence >= 0.70`
- `repro.json` — for spec path, error, locator, and evidence

If missing, check `.workflow-artifacts/` or ask the user to run `ft-repro` + `ft-classifier` first.

## Workflow

### 1. Confirm verdict and confidence

Read `classification.json`. If `verdict != "test-bug"` or `confidence < 0.70`:

```text
Verdict is <verdict> with confidence <confidence>.
The threshold for ft-test-fix-runner is test-bug with confidence >= 0.70.
<Suggest appropriate action based on actual verdict>
```

Stop — do not attempt a fix.

### 2. Understand the failure

Read both JSON files. Identify:

- **Spec path** from `repro.json.spec`
- **Error type** from `repro.json.error` (TimeoutError, locator not found, assertion mismatch)
- **Failing locator** from `repro.json.locator`
- **Signals** from `classification.json.signals`

### 3. Determine fix strategy

Choose exactly one fix strategy based on the signals:

| Signal | Fix strategy |
|---|---|
| `locator not found` / `strict mode violation` | Find new selector; update locator in test |
| `TimeoutError` (test-bug) | Add explicit `waitFor`; tighten navigation wait |
| Assertion mismatch where live app has different value | Verify expected value with `playwright-cli`; update assertion |
| Multiple matching elements | Make the locator more specific |

### 4. Find the correct selector (for locator issues)

Use `playwright-cli` to inspect the live app:

1. Open the page that the failing test targets
2. Take a snapshot to see the current DOM structure
3. Find a stable, accessible locator for the element:
   - Prefer `getByRole()`, `getByLabel()`, `getByTestId()`, `getByText()`
   - Avoid generated class names or position-based selectors
4. Verify the locator resolves to exactly one element

### 5. Apply the fix

Open `repro.json.spec` and make the minimal change needed:

- **Selector fix:** replace the failing locator with the new stable one
- **Wait fix:** replace `page.waitForTimeout(N)` with `await expect(locator).toBeVisible()`
- **Assertion fix:** update the expected value to match the verified live app value

Modify **only the test file** — never touch application source code.

### 6. Verify the fix passes

Run:

```bash
npx playwright test <spec-path> --project=chromium
```

- If **passing** → proceed to step 7
- If **still failing** → do not ship; write `fix.json` with `verdict: "needs-human"` and explain what you tried

### 7. Ship the fix via git workflow

Run the git skills in order:

**Step 7a — Create branch:**
Use `gf-branch` with a work-item-id derived from the spec name or classification:
```bash
bash .claude/skills/git-flow/scripts/create-branch.sh \
  --work-item-id "fix-$(date +%Y%m%d)" \
  --title "fix failing test <spec-basename>"
```

**Step 7b — Commit:**
```bash
bash .claude/skills/git-flow/scripts/create-commit.sh \
  --type fix \
  --scope test \
  --subject "correct failing locator in <spec-basename>" \
  --files <spec-path>
```

**Step 7c — Push:**
```bash
bash .claude/skills/git-flow/scripts/push-branch.sh
```

**Step 7d — PR:**
```bash
bash .claude/skills/git-flow/scripts/create-pr.sh --base main
```

### 8. Write fix.json

Write `.workflow-artifacts/{run_id}/fix.json`:

```json
{
  "verdict": "success",
  "spec": "tests/critical-checkout-validation-fail.spec.ts",
  "fix_type": "locator-update",
  "branch_name": "task/fix-20240601-fix-failing-test",
  "commit_sha": "deadbeef...",
  "pr_url": "https://github.com/org/repo/pull/88",
  "classification_source": "ft-classifier"
}
```

For `verdict: "needs-human"`:
```json
{
  "verdict": "needs-human",
  "spec": "...",
  "attempted_fix": "updated locator from X to Y",
  "result": "test still failing after fix",
  "next_step": "manual investigation required"
}
```

## Hard rules

- Only run when `verdict == "test-bug"` and `confidence >= 0.70`.
- Change **test code only** — never touch application source.
- Always verify the fix passes before shipping.
- Use `gf-*` skills for all git operations — do not run raw git commands.
- Do not force-push or commit on `main`.
- If the fix does not work, emit `needs-human` — do not guess or try random changes.
