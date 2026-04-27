# Playwright Agentic QA Automation Workflows

Playwright test suite for [SauceDemo](https://www.saucedemo.com/) backed by two fully-autonomous Claude Code pipelines: **Pipeline A** generates Playwright specs from user stories and ships them via PR, **Pipeline B** triages failing tests and either fixes them (PR) or files a bug in the tracker.

---

## Quick start

```bash
# Install dependencies
npm install
npx playwright install

# Copy environment variables
cp .env.example .env   # fill in values — see Environment section

# Run tests
npm test               # headless, all browsers
npm run test:headed    # headed Chromium only
npx playwright test --ui  # interactive UI mode

# Generate PDF report after npm test
npm run generate:pdf
```

Reports land in `playwright-report/` (HTML) and `junitreports/` (XML).

---

## Environment

| Var | Purpose |
|---|---|
| `ISSUE_TRACKER` | `fake` \| `github` \| `jira` \| `ado` \| `linear` |
| `FAKE_TRACKER_URL` | `http://localhost:3000` when `ISSUE_TRACKER=fake` |
| `GITHUB_TOKEN` | GitHub API auth (git flow skills, GitHub issues) |
| `REPO_OWNER` / `REPO_NAME` | Artifact links in pipelines |
| `CORE_BRANCH` | Main branch name (`master`) |
| `PR_HOST` | PR platform (`github`) |

Skills source `.env` automatically via `_common.sh`. When using `ISSUE_TRACKER=fake`, start the fake tracker server separately before running any pipeline.

---

## Project structure

```
tests/
  pages/              # Page Object Model (SauceDemo pages)
  fixtures/
    pages.fixture.ts  # Wires all page objects into a single fixture
  *.spec.ts           # Playwright specs (top-level and domain subdirs)

.claude/skills/       # Agentic skills (invocable with /skill-name)
  gt-*/               # Pipeline A generation stages
  ft-*/               # Pipeline B failure triage stages
  gf-*/               # Git flow helpers
  operations-with-issue-tracker/  # Tracker-agnostic wrapper + scripts

.workflow-artifacts/  # Pipeline scratch space — gitignored
  {run_id}/           # One directory per pipeline run
    us.json           # Normalized user story
    scenarios.md      # Planned scenarios + exploratory charters
    test-ideas.json   # Structured ideation units
    tc-N.json         # Test case artifact (one per scenario)
    spec-N.json       # Spec execution result (one per scenario)
    repro.json        # Failure reproduction signals
    classification.json  # Classifier verdict + confidence
    fix.json          # Test fix result
    bug.json          # Bug report artifact

decomposition/        # Coverage tracking and planning
  saucedemo.markmap.md
```

---

## Pipeline A — User Story → Automated Spec

**Invoke:** `/gt-us-to-spec --us-id <id>` or `/gt-us-to-spec --us-text "<title + AC>"`

Converts a tracker user story into runnable, refactored Playwright specs and ships them via PR. Fully autonomous — never pauses for confirmation.

### Stage flow

```
 User Story (ID or text)
        │
        ▼
┌─────────────────┐   us.json        ┌──────────────────┐   test-ideas.json   ┌──────────────────────┐
│ gt-story-planner│ ──────────────►  │ gt-test-ideation │ ──────────────────► │ gt-test-case-generator│
│                 │   scenarios.md   │                  │                     │                      │
└─────────────────┘                  └──────────────────┘                     └──────────┬───────────┘
                                                                                          │ tc-N.json
                                                                                          ▼
                                                                               ┌──────────────────┐
                                                                               │  gt-spec-writer  │
                                                                               └────────┬─────────┘
                                                                                        │
                                                              ┌─────── spec passing ────┤
                                                              │                         │
                                                              │                spec failing
                                                              ▼                         ▼
                                                   ┌──────────────────┐    ┌────────────────────┐
                                                   │ gt-refactor-tests│    │  ft-bug-reporter   │
                                                   └────────┬─────────┘    └────────────────────┘
                                                            │ cleaned spec
                                                            ▼
                                                   ┌────────────────┐
                                                   │    gf-ship     │──► PR on GitHub
                                                   └────────────────┘
```

### Stage-by-stage reference

#### 1. `gt-story-planner`

Fetches or synthesizes the user story, explores the live app with `playwright-cli`, checks for already-covered scenarios, and designs a scenario list with exploratory charters.

```
 --us-id <id>  ──► tracker fetch ──► us.json ──┐
                                                ├──► playwright-cli explore ──► scenarios.md
 --us-text "…" ──► synthesize ──────► us.json ──┘
```

**Inputs:** `--us-id <id>` or `--us-text "<story>"`

**Artifacts out:**

`us.json`
```json
{
  "id": "112",
  "title": "User can log in with valid credentials",
  "description": "As a registered user I want to log in...",
  "ac": [
    "Given valid credentials, user lands on the inventory page",
    "Given invalid password, an error message is shown"
  ],
  "url": "http://localhost:3000/stories/112"
}
```

`scenarios.md`
```markdown
# Test Scenarios: User can log in with valid credentials

## [P1] Auth: Login with valid credentials succeeds
## [P1] Auth: Login with invalid password shows error message "Epic sadface: Username and password do not match any user in this service"
## [P2] Auth: Login with empty username shows validation error
## [P2] Auth: Login form blocks submission when password field is empty
## [P3] Auth: Cancel login flow returns to landing page
## [SKIP] Auth: Logout flow — already covered in tests/example.spec.ts

## Exploratory Charters

### Charter: Login
- **Mission:** Explore login form with Interruption heuristic to discover race conditions on fast submission
- **Heuristics:** Boundary (empty / max-length credentials) | Interruption (network drop mid-submit, page refresh)
- **Personas:**
  - Speedrunner — submits before autofill completes
  - Attacker — tries SQL injection in username field, reuses expired session token
```

---

#### 2. `gt-test-ideation`

Expands each scenario into a structured ideation unit with conditions, ordered steps, verifications, navigations, and page object helper references. Enforces `ideas.length === verifications.length`.

```
 us.json ──────────────┐
                        ├──► [for each non-SKIP scenario] ──► ideation unit ──► test-ideas.json
 scenarios.md ─────────┘                                            │
                                                          (ideas.length must ==
                                                           verifications.length)
```

**Inputs:** `us.json`, `scenarios.md`

**Artifact out:**

`test-ideas.json`
```json
[
  {
    "index": 0,
    "scenario": "[P1] Auth: Login with valid credentials succeeds",
    "conditions": ["User is on the login page", "User has a valid account"],
    "ideas": [
      "User enters valid username 'standard_user'",
      "User enters valid password 'secret_sauce'",
      "User clicks the Login button",
      "User is redirected to the inventory page"
    ],
    "verifications": [
      "Username field shows 'standard_user'",
      "Password field is filled (masked)",
      "Login button click triggers navigation",
      "URL contains '/inventory' and inventory items are visible"
    ],
    "navigations": ["login", "inventory"],
    "ac_trace": ["AC1: User can log in with valid credentials"],
    "reusable_helpers": ["LoginPage.login(username, password)", "InventoryPage.isLoaded()"]
  }
]
```

Also writes `test-ideas.md` as a human-readable version.

---

#### 3. `gt-test-case-generator`

Converts each ideation unit into a tracker test case using deterministic shell scripts. Copies ideas and verifications verbatim — no LLM rewriting. Resume-safe: skips if `tc-N.json` already exists.

```
 test-ideas.json ──► [scenario N] ──► generate-tc.sh ──► tracker create ──► tc-N.json
                                              │                                    │
                                              └──► tc-steps-N.md                  │
                                              └──► tc-steps-N.xml        tc-N.json already exists?
                                                                               └──► skip (resume-safe)
```

**Inputs:** `test-ideas.json`, `scenario_index` (0-based, or `"all"`)

**Artifact out:**

`tc-N.json`
```json
{
  "id": "tc-1234567890",
  "tracker_id": 42,
  "index": 0,
  "scenario": "[P1] Auth: Login with valid credentials succeeds",
  "title": "Login with valid credentials succeeds",
  "ideas": ["User enters valid username 'standard_user'", "..."],
  "verifications": ["Username field shows 'standard_user'", "..."],
  "navigations": ["login", "inventory"],
  "conditions": ["User is on the login page", "User has a valid account"],
  "ac_trace": ["AC1: User can log in with valid credentials"],
  "reusable_helpers": ["LoginPage.login(username, password)"],
  "parent_us_id": "112"
}
```

Also writes `tc-steps-N.md` (human-readable step table) and `tc-steps-N.xml`.

---

#### 4. `gt-spec-writer`

Reads page objects and existing spec files, writes a runnable Playwright spec using the project fixture pattern, executes it, and emits a pass/fail result artifact.

```
 tc-N.json ──► read page objects ──► write .spec.ts ──► npx playwright test
                      │                                          │
                      └── if locators missing: playwright-cli   │
                                                         ┌──────┴──────┐
                                                       pass           fail
                                                         │              │
                                                         ▼              ▼
                                                    spec-N.json    spec-N.json
                                                   (passing)       (failing)
                                                         │              │
                                                         ▼              ▼
                                              gt-refactor-tests   ft-bug-reporter
```

**Inputs:** `tc-N.json`

**Spec output example** (`tests/auth/login-with-valid-credentials-succeeds.spec.ts`):
```typescript
import { test } from "../fixtures/pages.fixture";

test.describe("Login with valid credentials succeeds", () => {

  test.beforeEach(async ({ pages }) => {
    await pages.login.goto();
  });

  test("redirects to inventory on valid login", { tag: ["@tc-42"] }, async ({ pages }) => {
    await pages.login.login("standard_user", "secret_sauce");
    await pages.inventory.assertIsLoaded();
  });

});
```

**Artifact out:**

`spec-N.json` (passing)
```json
{
  "path": "tests/auth/login-with-valid-credentials-succeeds.spec.ts",
  "status": "passing",
  "last_error": null,
  "tc_id": "tc-1234567890",
  "parent_us_id": "112"
}
```

`spec-N.json` (failing — routes to `ft-bug-reporter`)
```json
{
  "path": "tests/auth/login-with-valid-credentials-succeeds.spec.ts",
  "status": "failing",
  "last_error": "TimeoutError: waiting for element 'button[data-test=\"login-button\"]'",
  "tc_id": "tc-1234567890",
  "parent_us_id": "112"
}
```

---

#### 5. `gt-refactor-tests` (Validation Mode)

Audits the newly written spec for anti-patterns, enforces project conventions, and auto-applies all MUST FIX items plus clear-cut CAN FIX items without asking.

**MUST FIX examples:** `page.waitForTimeout()`, missing `await`, hard-coded URLs, tests with no assertions, `test.only` without comment.

**CAN FIX examples (auto-applied in pipeline):** naming conventions, fixture consolidation, locator hygiene with existing page object coverage.

---

#### 6. `gf-ship`

Creates a branch, commits all passing spec files, pushes, and opens a PR to `CORE_BRANCH`.

**Branch format:** `gt-{us_id}/{run_id}`
**Commit format:** `test(specs): add {N} Playwright specs for story {us_id}`

---

### Pipeline A example run

```
/gt-us-to-spec --us-id 112
```

```
✓ Scenarios planned: 5 scenarios (1 skipped as already covered)
✓ Test ideas generated: 5 ideation units
✓ Test cases generated: 5 / 5 scenarios

| # | Scenario                                    | TC ID        | Spec Path                                    | Status  | Notes        |
|---|---------------------------------------------|--------------|----------------------------------------------|---------|--------------|
| 0 | [P1] Auth: Login with valid credentials     | tc-1234567890| tests/auth/login-with-valid-credentials.spec | PASSING |              |
| 1 | [P1] Auth: Login with invalid password      | tc-1234567891| tests/auth/login-invalid-password.spec.ts    | PASSING |              |
| 2 | [P2] Auth: Login with empty username        | tc-1234567892| tests/auth/login-empty-username.spec.ts      | FAILING | Bug reported |
| 3 | [P2] Auth: Login empty password             | tc-1234567893| tests/auth/login-empty-password.spec.ts      | PASSING |              |
| 4 | [SKIP] Auth: Logout flow                   | —            | —                                            | SKIPPED | Already covered |

Run ID: gt-20240601-143012
Total: 5 scenarios | 3 passing | 1 failing (bug reported) | 1 skipped
Ship: PR https://github.com/org/repo/pull/42
```

---

## Pipeline B — Test Failure Triage

**Invoke:** `/ft-orchestrator tests/path/to/failing.spec.ts`

Reproduces a failing spec, classifies the root cause, and either fixes the test (PR) or files a bug in the tracker. Fully autonomous — never pauses for confirmation.

### Stage flow

```
 failing.spec.ts
        │
        ▼
┌───────────────┐  repro.json + trace/png/webm   ┌──────────────────┐  classification.json
│   ft-repro    │ ──────────────────────────────► │  ft-classifier   │ ──────────────┐
└───────────────┘                                 └──────────────────┘               │
                                                                                      │
                                    ┌─────────────────────────────────────────────────┤
                                    │                                                 │
                            verdict: test-bug ≥0.55                         verdict: app-bug ≥0.60
                                    │                                                 │
                                    ▼                                                 ▼
                         ┌─────────────────────┐                         ┌──────────────────────┐
                         │ ft-test-fix-runner  │                         │   ft-bug-reporter    │
                         └──────────┬──────────┘                         └──────────┬───────────┘
                                    │ fix.json (success)                             │ bug.json
                                    ▼                                                ▼
                         ┌─────────────────────┐                          tracker issue + URL
                         │      gf-ship        │──► PR on GitHub
                         └─────────────────────┘

                         verdict: flaky ≥0.45  ──► report only (no code change)
                         verdict: infra ≥0.65  ──► report only (no code change)
                         verdict: needs-human   ──► stop; human decision required
```

### Stage-by-stage reference

#### 1. `ft-repro`

Re-runs the failing spec with the JSON reporter, collects trace/screenshot/video evidence, and extracts failure signals.

```
 failing.spec.ts ──► npx playwright test --reporter=json ──► pw-output.json
                                                                     │
                             ┌───────────────────────────────────────┤
                             │                                       │
                     parse error signals                   copy artifacts
                             │                                       │
                      (error, stack,                     trace.zip / fail.png
                     locator, expected,                      / video.webm
                       actual fields)                            │
                             └───────────────────────────────────┘
                                                │
                                                ▼
                                           repro.json
```

**Inputs:** spec path (e.g. `tests/checkout/critical-checkout-validation-fail.spec.ts`)

**Artifact out:**

`repro.json`
```json
{
  "run_id": "ft-20240601-143012",
  "spec": "tests/checkout/critical-checkout-validation-fail.spec.ts",
  "error": "TimeoutError: Timed out 30000ms waiting for expect(locator).toBeVisible()",
  "stack": "    at /tests/checkout/critical-checkout-validation-fail.spec.ts:42:5\n    ...",
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

---

#### 2. `ft-classifier`

Scores signals from `repro.json` against a weighted rule table. For ambiguous cases, uses `playwright-cli` to inspect the live app and confirm whether the element exists. Emits a single verdict with confidence.

```
 repro.json (error + stack + locator)
        │
        ▼
 score signals ──► highest total wins
        │
        ├─ ambiguous / app-bug 0.40–0.75? ──► playwright-cli live app check ──► adjust weights
        │
        ▼
 apply confidence threshold
        │
        ├─ test-bug ≥ 0.55  ──► classification.json { verdict: "test-bug" }
        ├─ app-bug  ≥ 0.60  ──► classification.json { verdict: "app-bug"  }
        ├─ flaky    ≥ 0.45  ──► classification.json { verdict: "flaky"    }
        ├─ infra    ≥ 0.65  ──► classification.json { verdict: "infra"    }
        └─ below threshold  ──► classification.json { verdict: "needs-human" }
```

**Signal scoring table:**

| Pattern | Verdict | Weight |
|---|---|---|
| `"strict mode violation"` | test-bug | +0.85 |
| `locator resolved to N elements` | test-bug | +0.80 |
| `"No element found"` on first attempt | test-bug | +0.75 |
| `net::ERR_` / `ERR_CONNECTION_REFUSED` | infra | +0.85 |
| `"Element is not attached to the DOM"` | flaky | +0.70 |
| `TimeoutError` + passes on retry | flaky | +0.70 |
| `TimeoutError` + fails every run | app-bug | +0.55 |
| Consistent failure 2+ runs | app-bug | +0.30 bonus |

**Confidence thresholds to route:**

| Verdict | Min confidence | Action |
|---|---|---|
| `test-bug` | 0.55 | Route to `ft-test-fix-runner` |
| `app-bug` | 0.60 | Route to `ft-bug-reporter` |
| `flaky` | 0.45 | Report only; suggest retry annotation |
| `infra` | 0.65 | Report only; check network/server |
| `needs-human` | any (below threshold) | Stop; human decision required |

**Artifact out:**

`classification.json`
```json
{
  "verdict": "test-bug",
  "confidence": 0.85,
  "signals": [
    { "name": "strict mode violation", "weight": 0.85 },
    { "name": "playwright-cli confirmed element exists in live app", "weight": 0.20 }
  ],
  "error_summary": "Locator matched multiple elements — selector needs to be more specific",
  "evidence_paths": [
    ".workflow-artifacts/ft-20240601-143012/trace.zip",
    ".workflow-artifacts/ft-20240601-143012/fail.png"
  ],
  "recommended_next_skill": "ft-test-fix-runner"
}
```

---

#### 3A. `ft-test-fix-runner` (test-bug path)

Applies a targeted, test-only fix based on the classified signal type. Uses `playwright-cli` to find a stable locator or verify the expected value against the live app. Verifies the fix passes before writing the result. Never touches application source code.

```
 classification.json { verdict: "test-bug", confidence ≥ 0.55 }
         │
         ▼
 determine fix strategy ──► playwright-cli (inspect live app / find stable locator)
         │
         ▼
 apply minimal change to .spec.ts (test code only — never app code)
         │
         ▼
 npx playwright test <spec> --project=chromium
         │
         ├─ passes ──► fix.json { verdict: "success" } ──► ft-orchestrator calls gf-ship ──► PR
         │
         └─ still failing ──► fix.json { verdict: "needs-human" } ──► stop
```

**Fix strategies by signal:**

| Signal | Strategy |
|---|---|
| Locator not found / strict mode | Find new selector; update locator |
| `TimeoutError` (test-bug) | Replace `waitForTimeout` with `expect(locator).toBeVisible()` |
| Assertion mismatch | Verify expected value via `playwright-cli`; update assertion |
| Multiple matching elements | Make locator more specific |

**Artifact out:**

`fix.json` (success)
```json
{
  "verdict": "success",
  "spec": "tests/checkout/critical-checkout-validation-fail.spec.ts",
  "fix_type": "locator-update",
  "classification_source": "ft-classifier"
}
```

`fix.json` (needs-human)
```json
{
  "verdict": "needs-human",
  "spec": "tests/checkout/critical-checkout-validation-fail.spec.ts",
  "attempted_fix": "updated locator from page.locator('.btn-finish') to getByRole('button', {name:'Finish'})",
  "result": "test still failing after fix",
  "next_step": "manual investigation required"
}
```

After `fix.json` with `verdict: "success"`, the orchestrator calls `gf-ship` to branch → commit → push → PR.

---

#### 3B. `ft-bug-reporter` (app-bug path)

Verifies the regression is still present in the live app, builds a structured bug description with evidence links, creates the bug in the tracker, and emits `bug.json`.

```
 classification.json { verdict: "app-bug", confidence ≥ 0.60 }
         │
         ├──► playwright-cli: verify regression still present in live app
         │
         ▼
 build bug-desc.md
   ├── error summary (from classification.json)
   ├── stack trace (from repro.json)
   ├── signals + weights (from classification.json)
   └── evidence paths (trace.zip / fail.png / video.webm)
         │
         ▼
 create.sh ──► tracker API (up to 3 retries) ──► bug ID + URL
         │
         ▼
 bug.json { id, url, severity, deduped, evidence_paths }
```

**Severity mapping:**
- `confidence >= 0.70` → `critical`
- `confidence >= 0.60` → `high`

**Artifact out:**

`bug.json`
```json
{
  "id": 0,
  "title": "TimeoutError: Finish button not visible after completing checkout",
  "url": "http://localhost:3000/bugs/create",
  "severity": "high",
  "summary": "App-bug: checkout finish button not appearing after form submission",
  "classification_source": "ft-classifier",
  "evidence_paths": [
    ".workflow-artifacts/ft-20240601-143012/trace.zip",
    ".workflow-artifacts/ft-20240601-143012/fail.png"
  ],
  "deduped": false
}
```

---

### Pipeline B example run

```
/ft-orchestrator tests/checkout/critical-checkout-validation-fail.spec.ts
```

```
| Phase  | Skill              | Status  | Output                                              |
|--------|--------------------|---------|-----------------------------------------------------|
| 1      | ft-repro           | SUCCESS | .workflow-artifacts/ft-20240601-143012/repro.json   |
| 2      | ft-classifier      | SUCCESS | verdict: test-bug, confidence: 0.85                 |
| 3A     | ft-test-fix-runner | SUCCESS | fix.json (verdict: success)                         |
| 3A-git | gf-ship            | SUCCESS | PR: https://github.com/org/repo/pull/88             |

Run ID:    ft-20240601-143012
Verdict:   test-bug (0.85)
Action:    Test fix shipped
Result:    https://github.com/org/repo/pull/88
```

---

## Individual skill usage

Use individual skills when you need a specific stage only — do not invoke the orchestrators for partial flows.

### Pipeline A skills

| Skill | When to use standalone |
|---|---|
| `/gt-story-planner` | Plan scenarios for a story without generating tests |
| `/gt-test-ideation` | Expand existing scenarios into structured steps |
| `/gt-test-case-generator` | Create tracker test cases for one or all scenarios |
| `/gt-spec-writer` | Write a spec from a `tc-N.json` artifact |
| `/gt-refactor-tests` | Audit and improve any Playwright tests (interactive plan → execute flow) |

### Pipeline B skills

| Skill | When to use standalone |
|---|---|
| `/ft-repro` | Re-run one failing spec and collect evidence |
| `/ft-classifier` | Classify failure from an existing `repro.json` |
| `/ft-test-fix-runner` | Apply test fix after a `test-bug` classification |
| `/ft-bug-reporter` | File a bug after an `app-bug` classification |

### Git workflow skills

```
 /gf-branch ──► /gf-commit ──► /gf-push ──► /gf-pr
      └──────────────────────────────────────────────────── /gf-ship (all-in-one)
```

| Skill | Purpose |
|---|---|
| `/gf-branch` | Create feature branch from main |
| `/gf-commit` | Conventional commit from staged changes |
| `/gf-push` | Push current branch to origin |
| `/gf-pr` | Open PR to main on GitHub |
| `/gf-ship` | Full flow: branch → commit → push → PR (explicit invocation only) |

---

## Issue tracker integration

All tracker operations go through `.claude/skills/operations-with-issue-tracker/scripts/`:

```bash
# Run once per session before any pipeline that touches the tracker
ISSUE_TRACKER=fake FAKE_TRACKER_URL=http://localhost:3000 \
  bash .claude/skills/operations-with-issue-tracker/scripts/preflight.sh

# Fetch a work item
bash .claude/skills/operations-with-issue-tracker/scripts/get.sh \
  --id 112 --type Task

# Create a work item
bash .claude/skills/operations-with-issue-tracker/scripts/create.sh \
  --type "Bug" \
  --title "Finish button not visible after checkout" \
  --description-file /tmp/bug-desc.md \
  --tag "claude-generated" \
  --dedupe-by title
```

Scripts emit JSON only to stdout. The fake tracker returns `{"id":0,...}` on create — this is expected and valid.

Supported trackers: `fake` | `github` | `jira` | `ado` | `linear`

---

## Autonomy rules

Both orchestrators (`/gt-us-to-spec`, `/ft-orchestrator`) are fully autonomous:
- They never pause mid-run to ask the user for confirmation or clarification.
- If a required input or env var is missing, the pipeline stops immediately and reports exactly what is absent.
- Non-critical phase failures (individual scenario iterations) are logged and the pipeline continues — only Phase 0/1/2 failures abort everything.

---

## Workflow artifacts

`.workflow-artifacts/` is gitignored. Each pipeline run creates a timestamped subdirectory:

### Pipeline A handoff chain

```
gt-story-planner
  └──► us.json ──────────────────────────────────────────────────────────────────┐
  └──► scenarios.md ──────────────────────────────────────────────────────────┐  │
                                                                              │  │
gt-test-ideation (reads us.json + scenarios.md)                              │  │
  └──► test-ideas.json ────────────────────────────────────────────────────┐ │  │
  └──► test-ideas.md (human review)                                        │ │  │
                                                                           │ │  │
gt-test-case-generator (reads test-ideas.json[N])                          │ │  │
  └──► tc-N.json ──────────────────────────────────────────────────────┐  │ │  │
  └──► tc-steps-N.md / tc-steps-N.xml (human review)                  │  │ │  │
                                                                       │  │ │  │
gt-spec-writer (reads tc-N.json)                                       │  │ │  │
  └──► tests/<domain>/<name>.spec.ts ──────────────────────────────┐  │  │ │  │
  └──► spec-N.json { status: passing|failing }                     │  │  │ │  │
                                                                   │  │  │ │  │
gt-refactor-tests (reads spec file)                                │  │  │ │  │
  └──► cleaned .spec.ts ───────────────────────────────────────────┘  │  │ │  │
                                                                       │  │ │  │
gf-ship (reads all passing spec paths + us.json.id)                   │  │ │  │
  └──► git branch / commit / push / PR on GitHub                       │  │ │  │
                                                                       │  │ │  │
ft-bug-reporter (reads spec-N.json failing + tc-N.json) ───────────────┘  │ │  │
  └──► bug.json + tracker issue                                            │ │  │
                                                                           │ │  │
All downstream skills read from .workflow-artifacts/{run_id}/ ─────────────┘─┘──┘
```

### Pipeline B handoff chain

```
ft-repro (spec path)
  └──► repro.json ──────────────────────────────────────────────────────────────┐
  └──► trace.zip / fail.png / video.webm                                        │
                                                                                 │
ft-classifier (reads repro.json)                                                 │
  └──► classification.json { verdict, confidence, signals } ──────┐             │
                                                                   │             │
ft-test-fix-runner (reads classification.json + repro.json) ◄──── test-bug      │
  └──► .spec.ts (patched)                                          │             │
  └──► fix.json { verdict: success|needs-human } ──────────────┐  │             │
                                                               │  │             │
gf-ship (reads fix.json)                                       │  │             │
  └──► PR on GitHub (ft-orchestrator adds pr_url to fix.json)  │  │             │
                                                               │  │             │
ft-bug-reporter (reads classification.json + repro.json) ◄──── app-bug          │
  └──► bug-desc.md (intermediate)                              │                 │
  └──► bug.json { id, url, severity, deduped } ────────────────┘                 │
                                                                                 │
All artifacts stored in .workflow-artifacts/{run_id}/ ───────────────────────────┘
```

### File reference table

| File | Written by | Read by |
|---|---|---|
| `us.json` | `gt-story-planner` | `gt-test-ideation` |
| `scenarios.md` | `gt-story-planner` | `gt-test-ideation` |
| `test-ideas.json` | `gt-test-ideation` | `gt-test-case-generator` |
| `test-ideas.md` | `gt-test-ideation` | — (human review) |
| `tc-N.json` | `gt-test-case-generator` | `gt-spec-writer` |
| `tc-steps-N.md` | `gt-test-case-generator` | — (human review) |
| `spec-N.json` | `gt-spec-writer` | `gt-us-to-spec` orchestrator |
| `repro.json` | `ft-repro` | `ft-classifier` |
| `classification.json` | `ft-classifier` | `ft-test-fix-runner`, `ft-bug-reporter` |
| `fix.json` | `ft-test-fix-runner` | `ft-orchestrator` (for gf-ship) |
| `bug.json` | `ft-bug-reporter` | — (final artifact) |
| `.tracker-cache.json` | `preflight.sh` | all tracker scripts |
