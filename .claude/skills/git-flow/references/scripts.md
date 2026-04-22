# Script Reference — git-flow

Full flag reference, exit codes, error shapes, and examples for all five scripts.

---

## create-branch.sh

### Flags

| Flag             | Required | Description                                     |
| ---------------- | -------- | ----------------------------------------------- |
| `--work-item-id` | ✅       | Numeric tracker ID (e.g. `1111`)                |
| `--title`        | ❌       | Work item title (used in branch slug)           |
| `--base`         | ❌       | Base branch (default: `$CORE_BRANCH` or `main`) |

### Branch naming

```
task/<work-item-id>[-<slugified-title>]
```

Truncated to 60 characters. Slugification: lowercase, non-alphanumeric → `-`, leading/trailing `-` stripped.

### Error shapes

```json
{ "error": "branch already exists", "branch": "task/1111-...", "location": "local" }
{ "error": "branch already exists", "branch": "task/1111-...", "location": "origin" }
{ "error": "not a git repository",  "branch": "", "location": "" }
{ "error": "could not fetch origin/main", "branch": "", "location": "" }
{ "error": "base branch cannot be fast-forwarded — merge or rebase first", ... }
```

### Success shape

```json
{
  "branch": "task/1111-filter-order-number",
  "base": "main",
  "base_sha": "abc123...",
  "work_item_id": 1111
}
```

---

## create-commit.sh

### Flags

| Flag        | Required | Description                                                                |
| ----------- | -------- | -------------------------------------------------------------------------- |
| `--type`    | ✅       | `feat` `fix` `chore` `docs` `test` `refactor` `ci` `perf` `style` `revert` |
| `--subject` | ✅       | Imperative short description                                               |
| `--scope`   | ❌       | Conventional commit scope                                                  |
| `--body`    | ❌       | Extended description (use `\n` for newlines)                               |
| `--files`   | ❌       | Space-separated paths to `git add` before scan                             |

### Secret blocklist

Files matching any of these patterns are rejected:

| Pattern                   | Rationale             |
| ------------------------- | --------------------- |
| `.env` / `.env.*`         | Environment secrets   |
| `*.key`                   | Private keys          |
| `*.pem`                   | Certificates / keys   |
| `*.pfx` / `*.p12`         | PKCS keystores        |
| `id_rsa` / `id_ed25519`   | SSH private keys      |
| `playwright/.auth/*.json` | Saved auth state      |
| `secrets.*`               | Generic secrets files |

### Commit message format

```
<type>(<scope>): <subject>

[optional body]
```

Examples:

- `fix(orders): scope date filter`
- `feat: add order number search`
- `chore(ci): update deploy workflow`

### Error shapes

```json
{ "error": "refusing to commit secrets", "paths": [".env.local", "playwright/.auth/admin.json"] }
{ "error": "nothing staged to commit", "paths": [] }
{ "error": "refusing to commit directly on main", "paths": [] }
{ "error": "invalid type: foo (use one of: feat fix ...)", "paths": [] }
```

### Success shape

```json
{
  "sha": "deadbeef...",
  "branch": "task/1111-filter-order-number",
  "message": "fix(orders): scope date filter",
  "files_committed": 3
}
```

---

## push-branch.sh

### Flags

| Flag       | Required | Description                     |
| ---------- | -------- | ------------------------------- |
| `--remote` | ❌       | Remote name (default: `origin`) |

### Safety rules

- Refuses to push `main` or `master`
- Never adds `--force` or `--force-with-lease`
- Sets upstream (`-u`) if not already set

### Error shapes

```json
{ "error": "refusing to push directly to main", "branch": "main", "stderr": "" }
{ "error": "push failed", "branch": "task/1111-...", "stderr": "remote: Permission denied..." }
```

### Success shape

```json
{
  "branch": "task/1111-filter-order-number",
  "remote": "origin",
  "set_upstream": true,
  "pushed_sha": "deadbeef..."
}
```

---

## create-pr.sh

### Flags

| Flag             | Required | Description                                        |
| ---------------- | -------- | -------------------------------------------------- |
| `--work-item-id` | ❌       | Tracker ID; auto-builds title if `--title` omitted |
| `--title`        | ❌       | Explicit PR title (overrides auto-build)           |
| `--base`         | ❌       | Target branch (default: `$CORE_BRANCH` or `main`)  |
| `--draft`        | ❌       | Opens as draft PR / WIP MR                         |

### Title resolution priority

1. Explicit `--title`
2. `[{id}] {WORK_ITEM_TITLE}` (if both env + flag set)
3. First commit on branch vs base
4. Branch name

### PR body resolution priority

1. `$PR_TEMPLATE_PATH`
2. `.github/pull_request_template.md`
3. `.gitlab/merge_request_templates/Default.md`
4. `docs/pull_request_template.md`
5. `pull_request_template.md`
6. Built-in fallback with commit log

### Deduplication

Checks for an open PR/MR on the same source branch. If found, returns the existing one with `"deduped": true` — no duplicate created.

### Error shapes

```json
{ "error": "PR_HOST not set (github|gitlab|ado)" }
{ "error": "REPO_OWNER not set" }
{ "error": "GitHub API request failed" }
```

### Success shape

```json
{
  "id": 1234,
  "url": "https://github.com/acme/repo/pull/1234",
  "title": "[1111] fix(orders): scope date filter",
  "linked_work_item_id": 1111,
  "deduped": false
}
```

---

## ship.sh (orchestrator)

### Flags

Combines all flags from the four scripts above:

| Flag               | Maps to                                     |
| ------------------ | ------------------------------------------- |
| `--work-item-id`   | gf-branch, gf-pr                            |
| `--title`          | gf-branch (work item title for branch slug) |
| `--commit-type`    | gf-commit `--type`                          |
| `--commit-scope`   | gf-commit `--scope`                         |
| `--commit-subject` | gf-commit `--subject`                       |
| `--base`           | all scripts                                 |
| `--pr-title`       | gf-pr `--title` (overrides auto-build)      |
| `--draft`          | gf-pr `--draft`                             |
| `--files`          | gf-commit `--files`                         |

### Phase table (stderr)

```
Phase    Status   Detail
----------------------------------------
BRANCH   SUCCESS  task/1111-filter-order-number
COMMIT   SUCCESS  fix(orders): scope date filter
PUSH     SUCCESS  origin/task/1111-filter-order-number
PR       SUCCESS  https://github.com/acme/repo/pull/88
----------------------------------------
```

On failure, the failed phase shows `FAILED` and subsequent phases do not run.

### Final JSON (stdout)

**Success:**

```json
{
  "run_id": "gfs-20240601-143012",
  "verdict": "success",
  "pr_url": "https://github.com/acme/repo/pull/88",
  "branch_name": "task/1111-filter-order-number",
  "phases": [
    {
      "phase": "BRANCH",
      "status": "SUCCESS",
      "detail": "task/1111-filter-order-number"
    },
    {
      "phase": "COMMIT",
      "status": "SUCCESS",
      "detail": "fix(orders): scope date filter"
    },
    {
      "phase": "PUSH",
      "status": "SUCCESS",
      "detail": "origin/task/1111-filter-order-number"
    },
    {
      "phase": "PR",
      "status": "SUCCESS",
      "detail": "https://github.com/acme/repo/pull/88"
    }
  ]
}
```

**Failure (stops at COMMIT):**

```json
{
  "run_id": "gfs-20240601-143012",
  "verdict": "failure",
  "phases": [
    {
      "phase": "BRANCH",
      "status": "SUCCESS",
      "detail": "task/1111-filter-order-number"
    },
    {
      "phase": "COMMIT",
      "status": "FAILED",
      "detail": "{\"error\":\"refusing to commit secrets\",\"paths\":[\".env.local\"]}"
    }
  ]
}
```

---

## Common examples

### Ship a fix end-to-end

```bash
export PR_HOST=github
export REPO_OWNER=acme
export REPO_NAME=platform
export GITHUB_TOKEN=ghp_...
export WORK_ITEM_TITLE="filter order number"

bash orchestrator/ship.sh \
  --work-item-id 1111 \
  --title "filter order number" \
  --commit-type fix \
  --commit-scope orders \
  --commit-subject "scope date filter to active records" \
  --files "src/orders/filter.ts tests/orders/filter.test.ts"
```

### Just create a branch

```bash
bash scripts/create-branch.sh --work-item-id 1111 --title "filter order number"
```

### Just commit (files already staged)

```bash
bash scripts/create-commit.sh --type feat --scope auth --subject "add OAuth2 PKCE flow"
```

### Push and open a draft PR

```bash
bash scripts/push-branch.sh
bash scripts/create-pr.sh --work-item-id 1111 --draft
```
