# Locator Patterns Reference

This file documents the project's conventions for UI selectors and locator naming.
The agent should read this during Phase 3 before writing any UI-based test steps.

---

## Selector Priority Order

Use selectors in this order of preference (most resilient → least resilient):

1. `data-testid` attributes — `[data-testid="submit-btn"]`
2. ARIA roles + accessible name — `getByRole('button', { name: 'Submit' })`
3. ARIA label — `getByLabel('Email address')`
4. Placeholder text — `getByPlaceholder('Enter your email')`
5. Text content — `getByText('Sign in')` (only for static, non-translatable strings)
6. CSS class — avoid; use only if no other option and class is semantically stable

---

## Naming Conventions

Page Object Model locators follow this pattern:

```
<page>.<section>.<element>
```

Examples:

- `loginPage.form.emailInput`
- `checkoutPage.orderSummary.totalAmount`
- `dashboardPage.header.userAvatarBtn`

---

## Common Shared Locators

| Logical Name       | Selector                          | Notes                              |
| ------------------ | --------------------------------- | ---------------------------------- |
| Global nav bar     | `[data-testid="global-nav"]`      | Present on all authenticated pages |
| Primary CTA button | `[data-testid="primary-cta"]`     | Context-specific label             |
| Toast notification | `[role="alert"]`                  | Used for success/error messages    |
| Modal dialog       | `[role="dialog"]`                 | Includes header, body, close       |
| Loading spinner    | `[data-testid="loading-spinner"]` | Check visibility, not presence     |
| Error message      | `[data-testid="field-error"]`     | Per-field validation errors        |

---

## Notes

- Run `pw-cli locators search <component>` to find component-specific locators.
- If a locator is missing, raise it with the dev team — do not use fragile XPath.
- All new locators should be added via PR to the Page Object Model, not ad-hoc in tests.
