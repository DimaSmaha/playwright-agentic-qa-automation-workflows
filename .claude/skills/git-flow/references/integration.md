# Integration Reference — git-flow

How git-flow skills wire into Pipeline A (feature flow) and Pipeline B (triage).

---

## Shared conventions across pipelines

Both pipelines must:

1. **Set environment variables** before calling any git-flow script
2. **Parse JSON stdout** from each script
3. **Surface `pr_url`** in the pipeline's final output artifact
4. **Stop on any non-zero exit** from a git-flow script

### Minimal env block (add to pipeline bootstrap)

```bash
export PR_HOST=github           # or gitlab / ado
export REPO_OWNER=acme
export REPO_NAME=platform
export GITHUB_TOKEN="${GITHUB_TOKEN}"   # from CI secret store
export CORE_BRANCH=main
```

---

## Pipeline B — Triage fix flow

Pipeline B detects a test failure, triages the root cause, patches the code,
then uses git-flow to ship the fix.

### Flow

```
[Pipeline B: triage agent]
        │
        ▼
  fetch work item title
        │
        ▼
  gf-branch  ──→  {"branch": "task/11111-...", "base_sha": "..."}
        │
        ▼
  [apply patch]
        │
        ▼
  gf-commit  ──→  {"sha": "...", "message": "fix(orders): ..."}
        │
        ▼
  gf-push    ──→  {"pushed_sha": "..."}
        │
        ▼
  gf-pr      ──→  {"url": "...", "id": 88, "deduped": false}
        │
        ▼
  emit artifact: { run_id, verdict, pr_url, branch_name }
```

### Calling pattern (Pipeline B)

```bash
# 1. Create branch
BRANCH_OUT=$(bash scripts/create-branch.sh \
  --work-item-id "$WORK_ITEM_ID" \
  --title "$WORK_ITEM_TITLE" \
  --base "$CORE_BRANCH")
echo "$BRANCH_OUT"   # log to pipeline trace

# 2. Apply patch (pipeline B's own logic)
apply_patch "$PATCH_FILE"

# 3. Stage and commit
COMMIT_OUT=$(bash scripts/create-commit.sh \
  --type fix \
  --scope "$SCOPE" \
  --subject "$COMMIT_SUBJECT" \
  --files "$CHANGED_FILES")

# 4. Push
PUSH_OUT=$(bash scripts/push-branch.sh)

# 5. Open PR
PR_OUT=$(bash scripts/create-pr.sh \
  --work-item-id "$WORK_ITEM_ID")

PR_URL=$(echo "$PR_OUT" | python3 -c "import json,sys; print(json.load(sys.stdin)['url'])")
```

### Pipeline B artifact shape

```json
{
  "run_id": "pipe-b-20240601-001",
  "verdict": "success",
  "pr_url": "https://github.com/acme/platform/pull/88",
  "branch_name": "task/11111-filter-order-number",
  "triage_sha": "deadbeef..."
}
```

---

## Pipeline A — Feature flow

Pipeline A generates user stories and automated tests, then optionally ships
the scaffold via gf-ship.

### Flow

```
[Pipeline A: feature agent]
        │
        ▼
  user story → test scaffold generated
        │
        ▼
  gf-ship  ──→  phase table + final artifact
        │
        ▼
  emit artifact: { run_id, verdict, pr_url }
```

### Calling pattern (Pipeline A)

```bash
# Option 1: use orchestrator (recommended)
SHIP_OUT=$(bash orchestrator/ship.sh \
  --work-item-id "$STORY_ID" \
  --title "$STORY_TITLE" \
  --commit-type feat \
  --commit-scope "$FEATURE_SCOPE" \
  --commit-subject "scaffold $STORY_TITLE tests" \
  --files "$GENERATED_FILES")

# Option 2: step-by-step (if pipeline needs intermediate outputs)
# same as Pipeline B pattern above
```

### Pipeline A artifact shape

```json
{
  "run_id":      "pipe-a-20240601-001",
  "verdict":     "success",
  "pr_url":      "https://github.com/acme/platform/pull/91",
  "branch_name": "task/45200-add-order-filter-tests",
  "story_id":    45200,
  "phases":      [...]
}
```

---

## Shared script: fetch-work-item-title.sh

Both pipelines need the work item title to build branch names and PR titles.
Add this to your pipeline toolkit:

```bash
#!/usr/bin/env bash
# fetch-work-item-title.sh
# Usage: fetch-work-item-title.sh --id 11111
# Outputs the title string (plain text, not JSON)
# Requires: WORK_ITEM_HOST (jira|ado|linear|github-issue)
#           + appropriate API token

set -euo pipefail

ID=""
while [[ $# -gt 0 ]]; do
  case $1 in --id) ID="$2"; shift 2 ;; *) shift ;; esac
done
[[ -z "$ID" ]] && { echo "missing --id"; exit 1; }

case "${WORK_ITEM_HOST:-}" in
  jira)
    curl -sf -u "${JIRA_USER}:${JIRA_TOKEN}" \
      "${JIRA_BASE_URL}/rest/api/3/issue/${ID}" \
    | python3 -c "import json,sys; print(json.load(sys.stdin)['fields']['summary'])"
    ;;
  ado)
    B64=$(echo -n ":${ADO_TOKEN}" | base64)
    curl -sf -H "Authorization: Basic $B64" \
      "https://dev.azure.com/${REPO_OWNER}/${ADO_PROJECT}/_apis/wit/workitems/${ID}?api-version=7.1" \
    | python3 -c "import json,sys; print(json.load(sys.stdin)['fields']['System.Title'])"
    ;;
  linear)
    curl -sf -H "Authorization: ${LINEAR_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{\"query\":\"{issue(id:\\\"${ID}\\\"){title}}\"}" \
      "https://api.linear.app/graphql" \
    | python3 -c "import json,sys; print(json.load(sys.stdin)['data']['issue']['title'])"
    ;;
  github-issue)
    curl -sf -H "Authorization: Bearer ${GITHUB_TOKEN}" \
      "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/issues/${ID}" \
    | python3 -c "import json,sys; print(json.load(sys.stdin)['title'])"
    ;;
  *)
    echo "WORK_ITEM_HOST not set or unknown (jira|ado|linear|github-issue)"
    exit 1
    ;;
esac
```

Usage in both pipelines:

```bash
export WORK_ITEM_TITLE=$(bash fetch-work-item-title.sh --id "$WORK_ITEM_ID")
```

---

## Error handling in pipelines

All git-flow scripts use exit codes:

```bash
RESULT=$(bash scripts/create-branch.sh --work-item-id 11111 ...) || {
  ERROR=$(echo "$RESULT" | python3 -c "import json,sys; print(json.load(sys.stdin)['error'])")
  echo "Pipeline failed at BRANCH: $ERROR"
  # emit failure artifact and exit
  exit 1
}
```

Always emit a failure artifact with `verdict: "failure"` so downstream observers can react.

---

## Verification checklist

Run these in a scratch repo to verify the full chain:

```bash
# 1. Happy path
bash orchestrator/ship.sh --work-item-id 99999 --title "test" \
  --commit-type chore --commit-subject "verify git-flow wiring"

# 2. Deduplication (run ship.sh twice with same args, second should deduped=true)

# 3. Secret rejection
touch .env.local && git add .env.local
bash scripts/create-commit.sh --type fix --subject "test"
# expect: error "refusing to commit secrets"

# 4. Push to main rejection
git checkout main
bash scripts/push-branch.sh
# expect: error "refusing to push directly to main"

# 5. Commit on main rejection
git checkout main
echo "x" >> README.md && git add README.md
bash scripts/create-commit.sh --type fix --subject "test"
# expect: error "refusing to commit directly on main"
```
