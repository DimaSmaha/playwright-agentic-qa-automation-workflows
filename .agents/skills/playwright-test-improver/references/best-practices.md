# Playwright Best Practices Reference

This is the canonical checklist used during audit analysis. Issues are grouped by category.
Each item includes its default severity and a brief rationale.

---

## 1. Selector Strategy

| Severity | Rule                                                                                       |
| -------- | ------------------------------------------------------------------------------------------ |
| MUST     | Use `getByRole()`, `getByTestId()`, `getByLabel()`, `getByText()` over CSS/XPath selectors |
| MUST     | Never use auto-generated class names (e.g., `.sc-1a2b3c`, `.css-xyz`)                      |
| MUST     | Never use positional selectors like `nth-child()` for non-list elements                    |
| CAN      | Prefer `data-testid` attributes added to the app for stable anchoring                      |
| CAN      | Use `getByRole()` with accessible names for form controls and buttons                      |
| SKIP     | Migrating selectors that work fine and aren't fragile in practice                          |

## 2. Waiting & Timing

| Severity | Rule                                                                            |
| -------- | ------------------------------------------------------------------------------- |
| MUST     | Never use `page.waitForTimeout()` — replace with auto-waiting assertions        |
| MUST     | Never use `page.pause()` in committed tests                                     |
| MUST     | Don't poll with `setTimeout` in test logic — use Playwright's built-in retry    |
| MUST     | Don't use `sleep()` equivalents imported from utilities                         |
| CAN      | Use `page.waitForLoadState('networkidle')` only when no better assertion exists |
| CAN      | Prefer `expect(locator).toBeVisible()` over `waitForSelector`                   |

## 3. Assertions

| Severity | Rule                                                                                                          |
| -------- | ------------------------------------------------------------------------------------------------------------- |
| MUST     | Every test must have at least one `expect()` assertion                                                        |
| MUST     | Use web-first assertions (`expect(locator).toBeVisible()` not `expect(await locator.isVisible()).toBe(true)`) |
| MUST     | Don't assert on implementation details (exact class names, internal state)                                    |
| MUST     | Avoid `expect(x).toBeTruthy()` — assert the specific value                                                    |
| CAN      | Add `{ timeout }` overrides only when justified with a comment                                                |
| CAN      | Use `expect.soft()` for non-blocking assertions in report-style tests                                         |

## 4. Test Structure

| Severity | Rule                                                                       |
| -------- | -------------------------------------------------------------------------- |
| MUST     | No `test.only` committed to main branch without a `// TODO:` comment       |
| MUST     | No `test.skip` without a reason comment or linked issue                    |
| MUST     | Tests must be independent — no shared mutable state between tests          |
| MUST     | Don't use `beforeAll` to set up state that individual tests mutate         |
| CAN      | Group related tests with `test.describe()` blocks                          |
| CAN      | Use `test.describe.configure({ mode: 'parallel' })` for independent suites |
| CAN      | Name tests as behaviors: `'should show error when email is invalid'`       |
| SKIP     | Renaming tests that are clear but don't follow the exact naming convention |

## 5. Fixtures & Page Objects

| Severity | Rule                                                                                  |
| -------- | ------------------------------------------------------------------------------------- |
| MUST     | Don't define fixtures inline in spec files — put them in `playwright/app/fixtures.ts` |
| MUST     | Don't repeat login/setup logic across tests — use a fixture                           |
| CAN      | Wrap repeated selectors + actions in a Page Object class                              |
| CAN      | Page Objects should NOT contain assertions — keep those in tests                      |
| CAN      | Use fixture composition (`test.extend`) rather than inheritance                       |
| SKIP     | Creating Page Objects for one-off interactions used in a single test                  |

## 6. Navigation & Base URL

| Severity | Rule                                                                                    |
| -------- | --------------------------------------------------------------------------------------- |
| MUST     | Use relative paths with `baseURL` from config — never hard-code `http://localhost:3000` |
| MUST     | Don't mix `page.goto('/path')` with absolute URLs in the same suite                     |
| CAN      | Extract common routes to a `routes.ts` constant file                                    |

## 7. Configuration

| Severity | Rule                                                                        |
| -------- | --------------------------------------------------------------------------- |
| MUST     | `playwright.config.ts` must set `baseURL`, `testDir`, and `use.trace`       |
| MUST     | Retries should be configured per environment (`CI: 2, local: 0`)            |
| CAN      | Use projects for multi-browser or multi-role test configurations            |
| CAN      | Set `screenshot: 'only-on-failure'` and `video: 'retain-on-failure'` for CI |
| SKIP     | Overhauling config unless specifically requested                            |

## 8. File & Naming Conventions

| Severity | Rule                                                                    |
| -------- | ----------------------------------------------------------------------- |
| MUST     | Test files must end in `.spec.ts`                                       |
| CAN      | Use `kebab-case` for test filenames (e.g., `user-auth.spec.ts`)         |
| CAN      | Page Object files should use `PascalCase.ts` (e.g., `LoginPage.ts`)     |
| CAN      | Group tests by feature or domain in subdirectories                      |
| SKIP     | Renaming files that are well-organized but use a different naming style |

## 9. Data & State Management

| Severity | Rule                                                                  |
| -------- | --------------------------------------------------------------------- |
| MUST     | Tests must not depend on execution order or shared database state     |
| MUST     | Clean up created test data — use `test.afterEach` or fixture teardown |
| CAN      | Use API calls (via `request` fixture) to set up state rather than UI  |
| CAN      | Use `storageState` to persist authenticated sessions across tests     |
| SKIP     | Full test data factory setup if the project doesn't already have one  |

## 10. Performance & Parallelism

| Severity | Rule                                                                    |
| -------- | ----------------------------------------------------------------------- |
| CAN      | Tests that are slow (>30s) should be investigated for unnecessary waits |
| CAN      | Use `test.describe.configure({ mode: 'parallel' })` where safe          |
| SKIP     | Parallelism changes if the test suite isn't stable yet                  |

---

## Project-Convention Override

If the project has a `CONVENTIONS.md`, `README.md` in the playwright folder, or a linked
`playwright-best-practices` skill, those rules take precedence over the defaults above.
Note any overrides at the top of the audit plan output.
