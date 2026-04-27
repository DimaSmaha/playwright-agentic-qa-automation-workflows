# Pipeline B Run Report — ft-20260424-123613

## Run Metadata

| Field | Value |
|---|---|
| **Run ID** | `ft-20260424-123613` |
| **Date** | 2026-04-24 |
| **Pipeline** | `ft-orchestrator` (Pipeline B — Test Failure Triage) |
| **Failing spec** | `tests/cart-removal-f.spec.ts` |
| **Test** | `[FTB] critical positive 2: user can remove item from cart` |
| **Triggered by** | Failing test detected — cart badge not updated after Remove button click for `problem_user` |
| **Bug ID** | `BUG-83806` |
| **Severity** | Critical |
| **Outcome** | ✅ app-bug classified (0.90) — bug ticket filed |

---

## Pipeline Stages

| # | Stage | Skill | Input | Output | Status |
|---|---|---|---|---|---|
| 0 | Initialize | — | failing spec path | run directory `ft-20260424-123613/` | ✅ |
| 1 | Reproduce | `ft-repro` | `tests/cart-removal-f.spec.ts` | `repro.json`, `pw-output.json` | ✅ |
| 2 | Classify | `ft-classifier` | `repro.json`, `pw-output.json` + live `playwright-cli` exploration | `classification.json` (verdict: `app-bug`, confidence: 0.90) | ✅ |
| 3 | Report | `ft-bug-reporter` | `classification.json` | `bug.json`, `bug-desc.md` — bug ticket `BUG-83806` filed | ✅ |

---

## Failure Description

The spec `cart-removal-f.spec.ts` tests that a logged-in user can remove an item from the cart on the inventory page. The test:

1. Logged in as `problem_user`
2. Added an item to cart — badge confirmed at `"1"`
3. Called `removeFirstItemFromCart()` — clicks the `Remove` button
4. Asserted `getShoppingCartBadgeLocator()` count equals `0`

The assertion failed: the badge remained at `1` after the click. Playwright retried the `toHaveCount` assertion 9 times (5 000 ms timeout) and the value never changed.

**Error:** `expect(locator).toHaveCount(expected) failed — Expected: 0 — Received: 1 — Timeout: 5000ms`

---

## Repro Findings

Source: `repro.json`

| Field | Value |
|---|---|
| Locator | `locator('[data-test="shopping-cart-badge"]')` |
| Expected | `0` (badge disappears when cart is empty) |
| Actual | `1` (badge unchanged after Remove click) |
| Call site | `tests/cart-removal-f.spec.ts:15` |
| Retries | 9 × element resolved to 1 — value never changed |

Code snippet at failure point:

```typescript
13 |     await pages.inventory.assertCartCount("1");
14 |     await pages.inventory.removeFirstItemFromCart();
>15 |     await expect(pages.inventory.getShoppingCartBadgeLocator()).toHaveCount(0);
    |                                                                 ^
16 |   });
```

---

## Classification

Source: `classification.json`

| Field | Value |
|---|---|
| **Verdict** | `app-bug` |
| **Confidence** | **0.90** |
| **Recommended next skill** | `ft-bug-reporter` |

### Signals

| Signal | Weight |
|---|---|
| `playwright-cli` confirmed: Remove button clicked but cart badge stayed at 1 for `problem_user` | 0.75 |
| Page object `removeFirstItemFromCart()` is correctly implemented — clicks existing Remove button | 0.20 |
| Consistent failure — 9 retries in `toHaveCount`, item never removed | 0.30 |

**Error summary:**

> `problem_user` cannot remove items from the cart on the inventory page — clicking the Remove button has no effect in the application; cart badge remains at 1.

### Live app verification

The `ft-classifier` stage ran a live `playwright-cli` session to rule out a test-code error before filing a bug:

| Step | Result |
|---|---|
| Logged in as `problem_user` / `secret_sauce` | ✅ |
| Added Sauce Labs Backpack to cart — badge shows `"1"` | ✅ |
| Clicked Remove (`[data-test="remove-sauce-labs-backpack"]`) | ✅ click received |
| Cart badge after click | ❌ still `"1"` — item NOT removed |

The Remove button click is received by the app but the cart state is not updated for `problem_user`. This is a known class of `problem_user` defect on SauceDemo where UI interactions are silently swallowed.

---

## Bug Filed

Source: `bug.json`, `bug-desc.md`

| Field | Value |
|---|---|
| **Bug ID** | `BUG-83806` |
| **Title** | `problem_user cannot remove items from cart on inventory page — Remove button has no effect` |
| **Severity** | Critical |
| **Summary** | App-bug: `problem_user` Remove button click on inventory page does not update cart state; badge stays at 1 |
| **Classification source** | `ft-classifier` |
| **Deduplicated** | No (first occurrence) |

### Bug Description

> **Summary**
> `problem_user` cannot remove items from the cart on the inventory page — clicking the Remove button has no effect in the application; cart badge remains at 1

**Failing test:** `tests/cart-removal-f.spec.ts`

**Error:**
```
Error: expect(locator).toHaveCount(expected) failed — Locator: locator('[data-test="shopping-cart-badge"]') — Expected: 0 — Received: 1 — Timeout: 5000ms
```

**Stack trace:**
```
Error: expect(locator).toHaveCount(expected) failed

Locator:  locator('[data-test="shopping-cart-badge"]')
Expected: 0
Received: 1
Timeout:  5000ms

    at C:\qa\work\playwright-agentic-qa-automation-workflows\tests\cart-removal-f.spec.ts:15:65
```

**Classification signals:**
- `playwright-cli` confirmed: Remove button clicked but cart badge stayed at 1 for `problem_user` (weight: 0.75)
- Page object `removeFirstItemFromCart()` is correctly implemented — clicks existing Remove button (weight: 0.20)
- Consistent failure — 9 retries in `toHaveCount`, item never removed (weight: 0.30)

**Evidence:**
- Screenshot: null
- Trace: null
- Video: null

**Live app verification:**
Verified via `playwright-cli` during classification phase:
1. Logged in as `problem_user` / `secret_sauce`
2. Added Sauce Labs Backpack to cart — cart badge showed `"1"` ✓
3. Clicked the Remove button (`[data-test="remove-sauce-labs-backpack"]`)
4. Cart badge remained at `"1"` — item was NOT removed from the cart

The bug is confirmed present in the live app. The Remove button click is received but the application does not update the cart state for `problem_user`.

---

## Artifact Inventory

Artifacts are stored in `ft-20260424-123613/` (project root, gitignored scratch space).

| Artifact | File | Produced by |
|---|---|---|
| Playwright JSON output | `pw-output.json` | `ft-repro` |
| Reproduction result | `repro.json` | `ft-repro` |
| Classification result | `classification.json` | `ft-classifier` |
| Bug description (Markdown) | `bug-desc.md` | `ft-bug-reporter` |
| Bug ticket result | `bug.json` | `ft-bug-reporter` |

No trace, video, or screenshot artifacts were captured in this run (fields are `null` in `repro.json`).

---

## Notable Observations

1. **App-bug routing vs test-fix routing** — Unlike run `ft-20260424-124755` (which classified as `test-bug` and routed to `ft-test-fix-runner`), this run classified as `app-bug` and routed to `ft-bug-reporter`. No code was changed; the output is a ticket, not a PR.

2. **Live exploration was decisive** — The highest-weight signal (0.75) came from the `playwright-cli` live verification step, not from static analysis of the stack trace alone. Without the live session the error pattern (`toHaveCount` assertion failure) could have looked like a test assertion misconfiguration.

3. **`problem_user` is a known problematic fixture** — SauceDemo exposes several user types with intentional defects. `problem_user` is documented to have broken UI interactions. This bug is an expected find for any test exercising cart mutation with that user; future pipeline runs on the same user type should check for deduplication against `BUG-83806` before filing.

4. **Page object is correct** — `removeFirstItemFromCart()` correctly locates and clicks the visible Remove button. The signal weight of 0.20 confirms the implementation was reviewed and found sound, which further raised confidence that the defect is in the app layer.
