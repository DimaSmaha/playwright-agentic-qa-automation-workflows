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
gt-story-planner → gt-test-ideation → gt-test-case-generator → gt-spec-writer → gt-refactor-tests
```
Each stage reads the previous stage's artifact from `.workflow-artifacts/` and writes its own. Artifacts: `us.json` → `scenarios.md` → `test-ideas.json` → `tc-N.json` → `spec-N.json` + `.spec.ts`. Passing specs are shipped via `gf-ship`; failing specs route to `ft-bug-reporter` only.

**Pipeline B — Test Failure Triage** (invoked with `/ft-orchestrator`):
```
ft-repro → ft-classifier → [ft-test-fix-runner | ft-bug-reporter]
```
`ft-repro` re-runs the failing spec and collects evidence (trace, video, screenshot) into `repro.json`. `ft-classifier` produces `classification.json` with a verdict (`test-bug`, `app-bug`, `flaky`, `infra`, `needs-human`) and confidence score. Routing: ≥55% test-bug → `ft-test-fix-runner` + PR; ≥60% app-bug → `ft-bug-reporter`; flaky/infra → report only; needs-human → stop.

**Both orchestrators are fully autonomous — they never re-ask the user mid-run.** Missing inputs or env vars cause an immediate stop-and-report, not a prompt.

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

### Issue tracker scripts

All tracker operations go through `.claude/skills/operations-with-issue-tracker/scripts/`:

```bash
# Must run once per session before any other script
ISSUE_TRACKER=fake FAKE_TRACKER_URL=http://localhost:3000 \
  bash .claude/skills/operations-with-issue-tracker/scripts/preflight.sh

# Fetch a work item (--type: Bug | Task | Test Case)
bash .../scripts/get.sh --id 112 --type Task

# Create a work item
bash .../scripts/create.sh --type "Bug" --title "..." --description-file /tmp/desc.md \
  --tag "claude-generated" --dedupe-by title
```

Scripts emit JSON only to stdout. Create returns `{"id":0,...}` on the fake tracker (expected, not an error).

### Tests and pages

Tests target [SauceDemo](https://www.saucedemo.com/). Page Object Model lives in `tests/pages/` with a fixture in `pages.fixture.ts` that wires all pages. Coverage state is tracked in `decomposition/saucedemo.markmap.md`.

### Workflow artifacts

`.workflow-artifacts/` is the shared scratch space for all pipeline runs. It holds JSON handoff files, trace/video/screenshot evidence, and `.tracker-cache.json` (preflight output). This directory is gitignored.
