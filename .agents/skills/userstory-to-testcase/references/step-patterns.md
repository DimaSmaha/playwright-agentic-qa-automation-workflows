# Step Patterns Reference

Canonical phrasing and data conventions for test case steps.
Read this during Phase 4 before writing steps.

---

## Actor Vocabulary

| Actor    | Used when                          |
| -------- | ---------------------------------- |
| `User`   | Human interaction with UI          |
| `System` | Automated/backend response         |
| `API`    | Direct API call (non-UI)           |
| `Admin`  | Back-office / admin portal actions |

---

## Step Verb Glossary

Use these verbs consistently. Do not invent synonyms.

| Action             | Verb            | Example                                             |
| ------------------ | --------------- | --------------------------------------------------- |
| Navigate to URL    | navigates to    | `User navigates to /login`                          |
| Click button/link  | clicks          | `User clicks the "Submit" button`                   |
| Type in field      | enters          | `User enters {email} in the Email field`            |
| Select dropdown    | selects         | `User selects "Monthly" from the Plan dropdown`     |
| Check checkbox     | checks          | `User checks the "Remember me" checkbox`            |
| Upload file        | uploads         | `User uploads {filename} via the Attach file input` |
| Verify visible     | sees / verifies | `User sees the success toast message`               |
| Verify not visible | does not see    | `User does not see the error banner`                |
| System redirects   | redirects       | `System redirects user to /dashboard`               |
| System shows       | displays        | `System displays the order confirmation modal`      |
| System sends       | sends           | `System sends a verification email to {email}`      |
| API returns        | returns         | `API returns HTTP 200 with body matching {schema}`  |

---

## Test Data Conventions

- Wrap all variable data in curly braces: `{email}`, `{password}`, `{orderId}`
- Define every variable in the Test Data table — no inline hardcoding
- Use equivalence classes and boundary values, not arbitrary data

### Standard Test Data Table Format

| Variable         | Value                    | Notes                  |
| ---------------- | ------------------------ | ---------------------- |
| `{email}`        | `test+happy@example.com` | Valid registered user  |
| `{password}`     | `Str0ng!Pass`            | Meets complexity rules |
| `{invalidEmail}` | `notanemail`             | Missing @ and domain   |

### Data Categories

| Category       | Example values                                |
| -------------- | --------------------------------------------- |
| Valid / happy  | Real-looking, within limits                   |
| Invalid format | Wrong type, missing required chars            |
| Boundary low   | Min length, min value                         |
| Boundary high  | Max length, max value                         |
| Empty / null   | `""`, `null`, whitespace only                 |
| Special chars  | `<script>`, `'; DROP TABLE` (SQL), `emoji 🎉` |

---

## Precondition Phrasing

- "User is logged in as `{role}`"
- "User is on the `<page name>` page"
- "`<Feature flag>` is enabled in the environment"
- "A `<record type>` exists with `{id}`"
- "The environment is set to `<locale>`"

---

## Expected Result Phrasing

- Must be **observable** — what can a tester see, measure, or verify?
- Avoid vague language: ~~"works correctly"~~, ~~"behaves as expected"~~
- Include: element visibility, URL change, API response code, DB state, email trigger

Good: `System displays a green toast with text "Profile saved successfully"`
Bad: `Profile is saved`
