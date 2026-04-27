# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
npm test                        # Run all Playwright tests (headless, 3 browsers)
npm run test:headed             # Run tests in headed Chromium only
npx playwright test <file>      # Run a single spec file
npx playwright test --ui        # Open Playwright UI mode
npm run generate:pdf            # Convert JUnit XML → PDF report (post-test)
```

CI runs `npx playwright test` then `npm run generate:pdf`. Reports land in `playwright-report/` (HTML) and `junitreports/` (XML).

## Environment

Copy `.env` values before running agentic skills. Required vars:

| Var | Purpose |
|---|---|
| `ISSUE_TRACKER` | `fake` \| `github` \| `jira` \| `ado` \| `linear` |
| `FAKE_TRACKER_URL` | `http://localhost:3000` (or ngrok URL) when `ISSUE_TRACKER=fake` |
| `GITHUB_TOKEN` | GitHub API auth (git flow skills, GitHub issues) |
| `REPO_OWNER` / `REPO_NAME` | Artifact links in Pipeline A/B |
| `CORE_BRANCH` | Main branch name (`master`) |
| `PR_HOST` | PR platform (`github`) |

Skills source `.env` automatically via `_common.sh`. The fake tracker server must be running separately before using `ISSUE_TRACKER=fake`.

## Architecture

### Two agentic pipelines

**Pipeline A — User Story → Automated Spec** (invoked with `/gt-us-to-spec`):
```
gt-story-planner → gt-test-ideation → gt-test-case-generator → gt-spec-writer → gt-refactor-tests → gf-ship
```

**Pipeline B — Test Failure Triage** (invoked with `/ft-orchestrator`):
```
ft-repro → ft-classifier → [ft-test-fix-runner | ft-bug-reporter]
```

**Both orchestrators are fully autonomous — they never re-ask the user mid-run.** Missing inputs or env vars cause an immediate stop-and-report, not a prompt.

### Invocation

```bash
# Pipeline A — from tracker story
/gt-us-to-spec --us-id 112

# Pipeline A — from pasted story text
/gt-us-to-spec --us-text "As a user I want to log in..."

# Pipeline B
/ft-orchestrator tests/checkout/critical-checkout-validation-fail.spec.ts
```

### Artifact contracts (Pipeline A)

Each stage reads the previous stage's artifact from `.workflow-artifacts/{run_id}/` and writes its own. All files are JSON unless noted.

**`us.json`** — written by `gt-story-planner`
```json
{
  "id": "112",
  "title": "User can log in with valid credentials",
  "description": "...",
  "ac": ["Given valid credentials, user lands on inventory page", "..."],
  "url": "http://localhost:3000/stories/112"
}
```
When story text is pasted directly: `"id": "manual"`, `"url": null`.

**`scenarios.md`** — written by `gt-story-planner`
```markdown
# Test Scenarios: <story title>

## [P1] Auth: Login with valid credentials succeeds
## [P1] Auth: Login with invalid password shows error "..."
## [P2] Auth: Login with empty username shows validation error
## [SKIP] Auth: Logout flow — already covered in tests/example.spec.ts

## Exploratory Charters
### Charter: Login
- **Mission:** Explore login form with Interruption heuristic ...
- **Heuristics:** Boundary | Interruption | State machine
- **Personas:** Speedrunner | Attacker
```

Format: `## [P{priority}] <Module>: <description>`. SKIP entries include the covering spec path. Every non-SKIP scenario must have at least one negative case.

**`test-ideas.json`** — written by `gt-test-ideation`
```json
[
  {
    "index": 0,
    "scenario": "[P1] Auth: Login with valid credentials succeeds",
    "conditions": ["User is on the login page", "User has a valid account"],
    "ideas": ["User enters valid username 'standard_user'", "User enters valid password", "User clicks Login", "Redirected to inventory"],
    "verifications": ["Username field shows value", "Password field is filled", "Navigation triggered", "URL contains '/inventory'"],
    "navigations": ["login", "inventory"],
    "ac_trace": ["AC1: User can log in with valid credentials"],
    "reusable_helpers": ["LoginPage.login(username, password)", "InventoryPage.isLoaded()"]
  }
]
```
Constraint: `ideas.length === verifications.length` for every unit — hard fail if violated.

**`tc-N.json`** — written by `gt-test-case-generator` (N = scenario index)
```json
{
  "id": "tc-1234567890",
  "tracker_id": 42,
  "index": 0,
  "scenario": "[P1] Auth: Login with valid credentials succeeds",
  "title": "Login with valid credentials succeeds",
  "ideas": ["..."],
  "verifications": ["..."],
  "navigations": ["login", "inventory"],
  "conditions": ["..."],
  "ac_trace": ["..."],
  "reusable_helpers": ["..."],
  "parent_us_id": "112"
}
```
Ideas and verifications are copied verbatim from `test-ideas.json` — no LLM rewriting at this stage.

**`spec-N.json`** — written by `gt-spec-writer`
```json
{
  "path": "tests/auth/login-with-valid-credentials-succeeds.spec.ts",
  "status": "passing",
  "last_error": null,
  "tc_id": "tc-1234567890",
  "parent_us_id": "112"
}
```
`status` is `"passing"` or `"failing"`. Failing specs route to `ft-bug-reporter` (not full Pipeline B).

### Artifact contracts (Pipeline B)

**`repro.json`** — written by `ft-repro`
```json
{
  "run_id": "ft-20240601-143012",
  "spec": "tests/checkout/critical-checkout-validation-fail.spec.ts",
  "error": "TimeoutError: Timed out 30000ms waiting for expect(locator).toBeVisible()",
  "stack": "    at /tests/...:42:5\n    ...",
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

**`classification.json`** — written by `ft-classifier`
```json
{
  "verdict": "test-bug",
  "confidence": 0.85,
  "signals": [
    { "name": "strict mode violation", "weight": 0.85 },
    { "name": "playwright-cli confirmed element exists in live app", "weight": 0.20 }
  ],
  "error_summary": "Locator matched multiple elements — selector needs to be more specific",
  "evidence_paths": [".workflow-artifacts/ft-20240601-143012/trace.zip", "..."],
  "recommended_next_skill": "ft-test-fix-runner"
}
```

Routing thresholds: `test-bug ≥ 0.55` → `ft-test-fix-runner`; `app-bug ≥ 0.60` → `ft-bug-reporter`; `flaky ≥ 0.45` → report; `infra ≥ 0.65` → report; below threshold → `needs-human`.

**`fix.json`** — written by `ft-test-fix-runner`
```json
{
  "verdict": "success",
  "spec": "tests/checkout/critical-checkout-validation-fail.spec.ts",
  "fix_type": "locator-update",
  "classification_source": "ft-classifier"
}
```
`ft-orchestrator` appends `pr_url` and `branch_name` after `gf-ship` completes.

**`bug.json`** — written by `ft-bug-reporter`
```json
{
  "id": 0,
  "title": "TimeoutError: Finish button not visible after completing checkout",
  "url": "http://localhost:3000/bugs/create",
  "severity": "high",
  "summary": "App-bug: checkout finish button not appearing after form submission",
  "classification_source": "ft-classifier",
  "evidence_paths": [".workflow-artifacts/ft-20240601-143012/trace.zip", "..."],
  "deduped": false
}
```

### Phase compact protocol

Both orchestrators emit a `<!-- PHASE COMPACT -->` JSON block after each stage and drop full phase output from active context. This prevents context overflow on long runs.

```json
<!-- PHASE COMPACT: gt-story-planner scenario=0 -->
{
  "phase": "gt-story-planner",
  "scenario_index": 0,
  "status": "SUCCESS",
  "us_id": "112",
  "title": "User can log in with valid credentials",
  "scenario_count": 5
}
```

Fields retained per phase (Pipeline A):

| Phase | Fields retained |
|---|---|
| `gt-story-planner` | `us_id`, `title`, `scenario_count` |
| `gt-test-ideation` | `total_ideas`, `scenario_count` |
| `gt-test-case-generator` | `tc_id`, `scenario_index`, `title`, `deduped` |
| `gt-spec-writer` | `status`, `spec_path`, `tc_id`, `last_error` |
| `gt-refactor-tests` | `fixes_applied`, `spec_path` |

Fields retained per phase (Pipeline B):

| Phase | Fields retained |
|---|---|
| `ft-repro` | `run_id`, `spec`, `error_summary`, `artifacts_paths[]` |
| `ft-classifier` | `verdict`, `confidence`, `recommended_next_skill` |
| `ft-test-fix-runner` | `verdict`, `spec`, `fix_type` |
| `ft-bug-reporter` | `id`, `url`, `severity`, `deduped` |
| `gf-ship` | `verdict`, `pr_url`, `branch_name` |

### Skills system

Skills live in `.claude/skills/` (invocable via `/skill-name`). Each skill has a `SKILL.md` that defines its contract, inputs, outputs, and trigger conditions. Four families:

- **`gt-*`** — Pipeline A generation stages
- **`ft-*`** — Pipeline B failure triage stages
- **`gf-*`** — Git flow: `gf-branch`, `gf-commit`, `gf-push`, `gf-pr`, `gf-ship` (end-to-end)
- **`operations-with-issue-tracker`** — Tracker-agnostic wrapper; all skills call this instead of hitting tracker APIs directly

Additional reference skills in `.agents/skills/`: `playwright-best-practices`, `playwright-test-improver`, `decomposition-coverage`, `decomposition-maintenance`, `userstory-to-testcase`.

**Explicit-invocation-only skills** (never auto-triggered): `gt-us-to-spec`, `ft-orchestrator`, `gf-ship`.

**Hard constraints shared by all skills:**
- Use `npx` (not `pnpm`) for Playwright commands
- Never modify app code in `ft-test-fix-runner`
- `gt-test-case-generator`: verbatim copy of ideas/verifications; `ideas.length === verifications.length`
- `gt-story-planner` and `ft-classifier`: mandatory live app exploration via `playwright-cli` before writing artifacts
- Fake tracker returns `{"id":0,...}` on create — this is expected, not an error
- All tracker and git operations go through wrapper skills/scripts only
- Never prefix bash calls with `cd /path && source .env &&` — working directory and env are already set; doing so bypasses the permission allowlist

### Spec file conventions

All specs import from the project fixture, never from `@playwright/test`:

```typescript
import { test } from "../fixtures/pages.fixture";
// Only add expect when no page object assertion method covers the need:
// import { test, expect } from "../fixtures/pages.fixture";

test.describe("<scenario title>", () => {
  test.beforeEach(async ({ pages }) => {
    await pages.login.goto();
    await pages.login.login("standard_user", "secret_sauce");
  });

  test("<title>", { tag: ["@tc-42"] }, async ({ pages }) => {
    await pages.inventory.addToCart("Sauce Labs Backpack");
    await pages.inventory.assertCartCount("1");
  });
});
```

- Prefer page object assertion methods (`pages.xxx.assertXxx()`) over raw `expect()` in spec bodies
- If a needed interaction or assertion is missing from the page object, add a method there — keep inline locators out of spec files
- Use `data-test` attributes inside page objects when available; fall back to `getByRole()`, `getByLabel()`, `getByText()`
- Every generated test must include `{ tag: ["@tc-<tracker_id>"] }` using `tc.json.tracker_id`

### Issue tracker scripts

All tracker operations go through `.claude/skills/operations-with-issue-tracker/scripts/`:

```bash
# Must run once per session before any other script
ISSUE_TRACKER=fake FAKE_TRACKER_URL=http://localhost:3000 \
  bash .claude/skills/operations-with-issue-tracker/scripts/preflight.sh

# Fetch a work item (--type: Bug | Task | Test Case)
bash .claude/skills/operations-with-issue-tracker/scripts/get.sh --id 112 --type Task

# Create a work item
bash .claude/skills/operations-with-issue-tracker/scripts/create.sh \
  --type "Bug" --title "..." --description-file /tmp/desc.md \
  --tag "claude-generated" --dedupe-by title
```

Scripts emit JSON only to stdout. Create returns `{"id":0,...}` on the fake tracker (expected, not an error).

### Tests and pages

Tests target [SauceDemo](https://www.saucedemo.com/). Page Object Model lives in `tests/pages/` with a fixture in `pages.fixture.ts` that wires all pages. Coverage state is tracked in `decomposition/saucedemo.markmap.md`.

### Workflow artifacts

`.workflow-artifacts/` is the shared scratch space for all pipeline runs. It holds JSON handoff files, trace/video/screenshot evidence, and `.tracker-cache.json` (preflight output). This directory is gitignored.

Artifact handoff chain:
```
us.json → scenarios.md → test-ideas.json → tc-N.json → spec-N.json   (Pipeline A)
repro.json → classification.json → fix.json | bug.json                (Pipeline B)
```
