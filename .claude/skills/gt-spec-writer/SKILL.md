---
name: gt-spec-writer
description: >
  Pipeline A stage that converts tracker test case artifacts into runnable
  Playwright specs and execution status outputs. Use when asked to write a spec
  from tc.json, generate an automated Playwright test from a test case, or run
  first-pass spec execution with structured pass/fail artifacts.
---

# gt-spec-writer

Generate a runnable Playwright spec from `tc.json`, execute it, and emit
`spec.json` with pass/fail status for orchestration.

## When this skill fits

Use it for requests like:

- "write the Playwright spec for this test case"
- "generate a spec from tc.json"
- "create the automated test from these steps"
- "run the spec and tell me if it passes"

Do **not** use it for:

- classifying or fixing failing tests (use Pipeline B skills)
- refactoring existing tests (use `gt-refactor-tests`)

## What comes before and after

- **Before:** `gt-test-case-generator` produces `tc.json` with full ideation context
- **After (passing):** `gt-refactor-tests` for quality review
- **After (failing on first run):** route to `ft-bug-reporter` with `spec.json`

## Inputs

**Required:** `tc.json` from `gt-test-case-generator`

If missing, check `.workflow-artifacts/` or ask the user to run `gt-test-case-generator` first.

## Workflow

### 1. Read tc.json

Load all fields — especially `ideas`, `verifications`, `navigations`, `conditions`,
and `reusable_helpers`.

### 2. Catalog existing page object methods

Read the project's page objects before writing a single line of spec:

```
tests/pages/login.page.ts
tests/pages/inventory.page.ts
tests/pages/cart.page.ts
tests/pages/checkout.page.ts
tests/fixtures/pages.fixture.ts
```

Map every public method. Prefer these over raw Playwright locator calls.

### 3. Determine spec file location

Derive the domain from `tc.json.navigations[0]` or the test title:

- Login/auth flows → `tests/auth/`
- Inventory → `tests/inventory/`
- Cart → `tests/cart/`
- Checkout → `tests/checkout/`
- Default → `tests/`

File name: `<kebab-case-title>.spec.ts`

Check if the file already exists — if so, update it rather than overwriting.

### 4. Find missing locators with playwright-cli

For any UI element referenced in `tc.json.ideas` or `verifications` that is
**not already covered by an existing page object method**:

1. Use `playwright-cli` to open the relevant page
2. Take a snapshot to inspect the DOM
3. Find a stable accessible locator:
   - Prefer `getByRole()`, `getByLabel()`, `getByTestId()`, `getByText()`
   - Avoid generated class names or positional selectors
4. Verify it resolves to exactly one element

Note new locators to add to the spec or propose adding them to the page object.

### 5. Write the spec file

Use the project's fixture pattern (matching existing tests):

```typescript
import { test, expect } from '@playwright/test';
import { test as pwTest } from '../fixtures/pages.fixture';

pwTest.describe('<scenario title>', () => {

  pwTest.beforeEach(async ({ pages }) => {
    // Set up conditions from tc.json.conditions
  });

  pwTest('<test title>', async ({ pages }) => {
    // Map each idea → action using page object methods
    // Map each verification → expect() assertion (1:1 with ideas)
  });

});
```

**Rules for the spec:**
- Use `pwTest` from the fixture, not raw `test` from Playwright (unless fixture isn't applicable)
- Map `ideas[i]` → action step; `verifications[i]` → `expect()` assertion immediately after
- Use page object methods from `tc.json.reusable_helpers` wherever possible
- Do not add `test.only` without a `// TODO:` comment
- Do not add `page.waitForTimeout()` — use `await expect(locator).toBeVisible()` instead

### 6. Execute the spec

Run:

```bash
npx playwright test <spec-path> --project=chromium
```

Capture the exit code and any error output.

### 7. Write spec.json

Write `.workflow-artifacts/{run_id}/spec-{index}.json`:

**Passing:**
```json
{
  "path": "tests/auth/login-with-valid-credentials-succeeds.spec.ts",
  "status": "passing",
  "last_error": null,
  "tc_id": "tc-1234567890",
  "parent_us_id": "manual"
}
```

**Failing:**
```json
{
  "path": "tests/auth/login-with-valid-credentials-succeeds.spec.ts",
  "status": "failing",
  "last_error": "TimeoutError: waiting for element...",
  "tc_id": "tc-1234567890",
  "parent_us_id": "manual"
}
```

### 8. Report and route

- **Passing:** "Spec is passing. Recommend running `gt-refactor-tests` to audit quality."
- **Failing:** "Spec failed on first run with faithful transcription of the test case. This may indicate an app issue. Pass `spec.json` to `ft-bug-reporter` to file a bug."

Do **not** attempt to fix a failing spec here — that is Pipeline B's job.

## Hard rules

- Always scan page objects before writing the spec — reuse what exists.
- Use `playwright-cli` for any locator not covered by existing page objects.
- Use `npx`, not `pnpm exec`.
- Map ideas to actions and verifications to assertions 1:1.
- Do not create tracker items, commit, or open PRs in this stage.
- If the spec fails on first run after faithful transcription, route to `ft-bug-reporter`.
