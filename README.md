# Playwright Agentic QA Automation Workflows

Playwright test suite for [SauceDemo](https://www.saucedemo.com/) backed by two agentic Claude Code pipelines: one that generates tests from user stories and one that triages failing tests.

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
```

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

## Project structure

```
tests/
  pages/          # Page Object Model (SauceDemo pages)
  pages.fixture.ts
  *.spec.ts       # Playwright specs

.claude/skills/   # Agentic skills (invocable with /skill-name)
.workflow-artifacts/  # Pipeline scratch space — gitignored
decomposition/    # Coverage tracking and planning
```

## Agentic pipelines

### Pipeline A — User Story → Automated Spec (`/gt-us-to-spec`)

Converts a tracker user story into runnable, refactored Playwright specs and ships them via PR.

```
gt-story-planner → gt-test-ideation → gt-test-case-generator → gt-spec-writer → gt-refactor-tests → gf-ship
```

| Stage | Artifact out |
|---|---|
| `gt-story-planner` | `us.json`, `scenarios.md` |
| `gt-test-ideation` | `test-ideas.json` |
| `gt-test-case-generator` | `tc-N.json` (one per scenario) |
| `gt-spec-writer` | `spec-N.json` + `.spec.ts` |
| `gt-refactor-tests` | Cleaned spec (in-place) |

Failing specs are routed to `ft-bug-reporter` instead of being shipped. Passing specs are bundled into a single PR via `gf-ship`.

**Invoke:** `/gt-us-to-spec --us-id <id>` or `/gt-us-to-spec --us-text "<story>"`

---

### Pipeline B — Test Failure Triage (`/ft-orchestrator`)

Reproduces a failing spec, classifies the root cause, and either fixes the test (PR) or files a bug in the tracker.

```
ft-repro → ft-classifier → ft-test-fix-runner (test-bug) | ft-bug-reporter (app-bug)
```

| Stage | Artifact out |
|---|---|
| `ft-repro` | `repro.json` + trace/screenshot/video |
| `ft-classifier` | `classification.json` (verdict + confidence) |
| `ft-test-fix-runner` | `fix.json` |
| `ft-bug-reporter` | `bug.json` + tracker issue |

**Routing thresholds:**

| Verdict | Min confidence | Action |
|---|---|---|
| `test-bug` | 0.55 | Fix test → PR via `gf-ship` |
| `app-bug` | 0.60 | File bug in tracker |
| `flaky` | 0.45 | Report only |
| `infra` | 0.65 | Report only |
| `needs-human` | any | Stop; human decision required |

**Invoke:** `/ft-orchestrator tests/path/to/failing.spec.ts`

---

### Git workflow skills (`gf-*`)

| Skill | Purpose |
|---|---|
| `/gf-branch` | Create feature branch from main |
| `/gf-commit` | Conventional commit from staged changes |
| `/gf-push` | Push current branch to origin |
| `/gf-pr` | Open PR to main on GitHub |
| `/gf-ship` | Full flow: branch → commit → push → PR (explicit invocation only) |

---

### Issue tracker operations (`/operations-with-issue-tracker`)

Unified wrapper for GitHub Issues, Jira, ADO, Linear, and the built-in fake tracker. Run `preflight.sh` once per session before any pipeline that touches the tracker.

## Autonomy rules

Both orchestrators (`gt-us-to-spec`, `ft-orchestrator`) run fully autonomously — they never pause mid-run to ask the user for confirmation or clarification. If a required input or env var is missing, the pipeline stops immediately and reports what is absent.

## Reports

After `npm test`, generate a PDF report:

```bash
npm run generate:pdf
```

HTML report: `playwright-report/`  
JUnit XML: `junitreports/`
