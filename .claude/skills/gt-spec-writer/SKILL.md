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

### 2. Catalog existing page object methods and spec patterns

Read the project's page objects **and** at least two existing spec files before writing a single line of spec.

**Page objects to read:**
```
tests/pages/login.page.ts
tests/pages/inventory.page.ts
tests/pages/cart.page.ts
tests/pages/checkout.page.ts
tests/fixtures/pages.fixture.ts
```

**Representative spec files to read (for style reference):**
```
tests/critical-inventory.spec.ts   — minimal describe + beforeEach pattern
tests/critical-cart.spec.ts        — multi-test, chained page object calls
tests/example.spec.ts              — single test without describe block
```

Map every public page object method. Absorb the import style, fixture usage, and assertion patterns from the existing specs before writing.

### 3. Determine spec file location

Derive the domain from `tc.json.navigations[0]` or the test title:

- Login/auth flows → `tests/auth/`
- Inventory → `tests/inventory/`
- Cart → `tests/cart/`
- Checkout → `tests/checkout/`
- Product detail → `tests/product-detail/`
- Any other domain → `tests/<domain>/` (create the directory if it doesn't exist)
- Default (domain unclear) → `tests/`

File name: `<kebab-case-title>.spec.ts`

Check if the file already exists — if so, update it rather than overwriting.

### 4. Find missing locators with playwright-cli (conditional)

After Step 2, compare every UI element referenced in `tc.json.ideas` and `verifications`
against the cataloged page object methods.

- **If all elements are covered** → skip this step entirely. Do not launch playwright-cli.
- **If any element is missing** → run playwright-cli **only for those specific missing elements**:
  1. Use `playwright-cli` to open the relevant page
  2. Take a snapshot to inspect the DOM
  3. Find a stable accessible locator:
     - Prefer `getByRole()`, `getByLabel()`, `getByTestId()`, `getByText()`
     - Avoid generated class names or positional selectors
  4. Verify it resolves to exactly one element

Note new locators to add to the page object (not inline in the spec).

### 5. Write the spec file

Use the project's fixture pattern (matching existing tests):

```typescript
import { test } from "../fixtures/pages.fixture";
// Only add expect if raw assertions are needed and no page object assertion method exists:
// import { test, expect } from "../fixtures/pages.fixture";

test.describe("<scenario title>", () => {

  test.beforeEach(async ({ pages }) => {
    // Set up conditions from tc.json.conditions
    await pages.login.goto();
    await pages.login.login("standard_user", "secret_sauce");
  });

  test("<test title>", { tag: ["@<tc_id>"] }, async ({ pages }) => {
    // Map each idea → action using page object methods
    // Map each verification → pages.xxx.assertXxx() or expect() (1:1 with ideas)
  });

});
```

**Import rules:**
- Always import `test` from `"../fixtures/pages.fixture"` (path relative to spec location) — never from `@playwright/test`
- Import `expect` from the same fixture file if raw assertions are needed — never from `@playwright/test`
- Single import line, no `pwTest` alias — use `test` directly

**Conventions matching existing tests:**
- Prefer page object assertion methods (`pages.inventory.assertCartCount("1")`) over raw `expect()` calls in spec bodies
- Keep the spec body clean — page object methods for all interactions and assertions
- If an interaction or assertion needed by the test case does **not** exist in the page object, **add a method to the page object** (e.g. add `clickFirstProductName()` to `InventoryPage`) rather than writing inline locator code in the spec
- Use `data-test` attributes as locators inside page object methods when available; prefer `getByRole()`, `getByLabel()`, `getByText()` otherwise
- Map `ideas[i]` → action step; `verifications[i]` → assertion immediately after (1:1)
- Do not add `test.only` without a `// TODO:` comment
- Do not add `page.waitForTimeout()` — use `await expect(locator).toBeVisible()` instead
- Always include `{ tag: ["@tc-<tracker_id>"] }` on every generated test, using `tc.json.tracker_id` as the value (e.g. `{ tag: ["@tc-42"] }`). Fall back to `tc.json.id` only if `tracker_id` is absent or `0`.

**After each test is written:** re-read the affected page object file(s) to refresh your view of their public methods before writing the next test. This prevents duplicate additions and ensures any method added during the session is visible.

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

- Always scan page objects **and** existing spec files before writing — match their style exactly.
- Never import `test` or `expect` from `@playwright/test` in spec files — always import from `../fixtures/pages.fixture`.
- Prefer page object methods (`pages.xxx.assertXxx()`) over inline `expect()` calls in spec bodies.
- When a needed action or assertion is missing from a page object, **add a method to the page object** — keep inline locator code out of spec files.
- Only use `playwright-cli` when page object coverage is incomplete; skip it entirely if all needed locators already exist.
- Use `npx`, not `pnpm exec`.
- Map ideas to actions and verifications to assertions 1:1.
- Do not create tracker items, commit, or open PRs in this stage.
- If the spec fails on first run after faithful transcription, route to `ft-bug-reporter`.
