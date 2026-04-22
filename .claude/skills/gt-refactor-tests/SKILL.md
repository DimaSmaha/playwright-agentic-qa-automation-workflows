---
name: gt-refactor-tests
description: >
  Use this skill whenever the user wants to audit, improve, refactor, validate, or review Playwright
  tests — including fixing anti-patterns, enforcing project conventions, planning test refactors,
  or verifying newly written tests match best practices. Trigger when the user says things like
  "improve my playwright tests", "audit the pw/ folder", "validate tests against conventions",
  "refactor playwright tests", "check playwright best practices", "review new tests", or
  "plan playwright improvements". Always start in PLAN MODE (analysis + structured plan only,
  no code changes). Execute only when the user explicitly approves the plan.
---

# Playwright Test Improver Skill

A structured, plan-first workflow for auditing and improving Playwright test suites.

Agents using this skill must also use the `playwright-best-practices` skill as a required reference during analysis and validation.

---

## Guiding Philosophy

**Always plan before acting.** This skill operates in two distinct phases:

1. **PLAN MODE** (default) — Analyze, categorize issues, produce an actionable plan with exact diffs. No files are changed.
2. **EXECUTE MODE** — Apply approved changes from the plan, one logical group at a time.

Never mix phases. Never modify files during PLAN MODE. Never skip the plan.

---

## Self-awareness

**If called after `gt-spec-writer`:** audit only the newly written spec file.
Do not scan the full `tests/` directory unless the user asks.

**If called independently:** ask which files to audit, or default to all of `tests/`
if no answer is given.

**Source of truth for page objects:** always check `tests/pages/` first. If a
locator can be expressed through an existing page object method, flag inline
locators as a CAN FIX issue even if they technically work.

---

## Phase 1: PLAN MODE

### Step 1 — Discover the project

Read these locations (if they exist) before touching any test file:

```
tests/
├── pages/           ← page objects (source of truth for locators)
├── fixtures/        ← shared fixtures
├── *.spec.ts        ← spec files
playwright.config.ts
package.json
```

Also read:

- `package.json` — installed versions of `@playwright/test`, testing libs
- The `playwright-best-practices` skill and apply its guidance as mandatory baseline rules
- `.eslintrc` / `eslint.config.*` — linting rules that apply to tests
- Any existing `CONVENTIONS.md` or `README` inside the playwright folder

Use `bash_tool` to list and read files. Prefer reading full files over snippets so patterns are visible.

### Step 2 — Analyze

Scan every file in `playwright/tests/` and `playwright/app/`. For each file, check against the reference list in `references/best-practices.md`.

Build an internal issue list with this structure per issue:

```
FILE: <relative path>
LINE: <line number or range>
ISSUE TYPE: <category>
SEVERITY: MUST | CAN | SKIP
DESCRIPTION: <what is wrong>
FIX: <exact change — before → after, or migration instruction>
```

### Step 3 — Categorize findings into three buckets

#### 🔴 MUST FIX

Issues that cause flakiness, false positives, maintainability collapse, or violate core Playwright contracts. Examples:

- `page.waitForTimeout()` (arbitrary waits)
- `page.pause()` left in
- Hard-coded absolute URLs that bypass base URL config
- Missing `await` on async Playwright calls
- `expect` assertions outside test blocks
- Selectors using implementation-specific internals (e.g., `.class-123abc`)
- Tests with no assertions
- `test.only` or `test.skip` committed without a comment
- Fixtures defined inline instead of in the shared fixture file
- Direct `page.goto()` to full URLs instead of using relative paths + `baseURL`

#### 🟡 CAN FIX

Issues worth fixing for clarity, reuse, and convention alignment, but not blocking. Examples:

- Missing Page Object encapsulation for repeated selectors
- Test descriptions that don't describe behavior (`test('works')`)
- Large test files that can be split by feature
- Repeated setup logic that should be a fixture or `beforeEach`
- Missing `data-testid` attributes on key elements (note: requires app changes)
- Inconsistent naming conventions (`camelCase` vs `kebab-case` for files)
- Missing tags (`@smoke`, `@regression`) if the project uses them

#### ⚪ SKIP

Changes that are subjective, high-risk without clear gain, or out of scope. Examples:

- Stylistic reformatting with no behavioral impact
- Changes requiring large app-side refactors
- Speculative improvements not grounded in actual test failures
- Tests that are unusual but intentional (e.g., custom retry logic for known flaky external deps)

### Step 4 — Output the Plan

Print the plan in this exact format so it's easy to approve section-by-section:

---

````
## 🔍 PLAYWRIGHT TEST AUDIT PLAN

### Summary
- Files scanned: N
- Total issues found: N
- 🔴 MUST FIX: N  |  🟡 CAN FIX: N  |  ⚪ SKIP: N

---

### 🔴 MUST FIX  (N issues)

#### [M1] <Short title>
**File:** `playwright/tests/auth.spec.ts` · **Line:** 42
**Problem:** `page.waitForTimeout(2000)` introduces a 2-second hard wait that causes flakiness.
**Fix:**
\```diff
- await page.waitForTimeout(2000);
+ await expect(page.locator('[data-testid="dashboard"]')).toBeVisible();
\```

#### [M2] ...

---

### 🟡 CAN FIX  (N issues)

#### [C1] <Short title>
**File:** `playwright/tests/checkout.spec.ts` · **Lines:** 10–35
**Problem:** Selector `div.sc-1x9abc > span` is brittle — uses auto-generated CSS class.
**Fix:** Add `data-testid="checkout-total"` to the component, then:
\```diff
- page.locator('div.sc-1x9abc > span')
+ page.getByTestId('checkout-total')
\```
> ⚠️ Requires app-side change in `src/components/Checkout.tsx`

#### [C2] ...

---

### ⚪ SKIP  (N issues — listed for transparency)

- `playwright/tests/legacy.spec.ts` — entire file is deprecated, removal tracked in #123
- `playwright/tests/payments.spec.ts:88` — unusual retry loop is intentional per team decision

---

### Execution Groups (for approval)
When you approve execution, I'll apply changes in these groups:
1. **Group A — Hard waits** (M1, M4, M7)
2. **Group B — Missing awaits** (M2, M3)
3. **Group C — Selector hygiene** (M5, M6, C1, C3)
4. **Group D — Fixture consolidation** (C2, C4)

Say "Execute Group A" (or "Execute all MUST FIX") to proceed.
````

---

## Phase 2: EXECUTE MODE

Only enter this phase after the user explicitly approves (fully or partially).

### Execution rules

1. Apply changes **one group at a time** unless told otherwise.
2. For each change:
   - Show the exact diff before writing
   - Apply using `str_replace` (preferred) or rewrite the file
   - Confirm the change was written successfully
3. After each group, summarize what was done and ask if the user wants to continue to the next group.
4. Never apply SKIP items unless the user explicitly unlocks them.
5. If a CAN FIX item requires an app-side change (e.g., adding `data-testid`), note it as a manual task and skip the test-side change until confirmed.

---

## Validation Mode

Use this after new tests are written or after Execute Mode completes.

Trigger phrases: "validate the tests", "check conventions", "review new tests against best practices"

### Validation workflow

1. Read the files the user specifies (or the full `playwright/tests/` and `playwright/app/` if unspecified).
2. Re-run the analysis from Phase 1, but scope it to checking for regressions and convention alignment.
3. Output a **Validation Report**:

```
## ✅ VALIDATION REPORT

### Files checked: N
### New issues found: N  |  Previously fixed issues: N  |  Clean files: N

#### New issues (if any)
[Same format as MUST/CAN/SKIP above]

#### Convention alignment
- Naming: ✅ / ⚠️ <details>
- Fixture usage: ✅ / ⚠️ <details>
- Selector strategy: ✅ / ⚠️ <details>
- Assertion quality: ✅ / ⚠️ <details>
- Page object coverage: ✅ / ⚠️ <details>
```

---

## Iterative Improvement Loop

This skill is designed to be used repeatedly as tests evolve:

```
Write tests → Validate → Plan improvements → Approve → Execute → Validate again
```

After each execution round, encourage the user to:

- Run the test suite and observe flakiness
- Re-trigger validation after any manual app-side changes
- Update the `playwright-best-practices` reference if new conventions emerge from the review

---

## Reference

Read `references/best-practices.md` for the full checklist used during analysis.

Use the `playwright-best-practices` skill for every run of this skill and merge its rules with the built-in checklist — project-specific conventions always take precedence over generic ones.
