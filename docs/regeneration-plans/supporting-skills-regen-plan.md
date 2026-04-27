# Supporting Skills Regeneration Plan — operations-with-issue-tracker + gf-*

## Context

This document is a **self-contained regeneration blueprint** for the two shared dependency skill families used by both Pipeline A and Pipeline B:

- **`operations-with-issue-tracker`** — tracker-agnostic wrapper for all work-item CRUD (get, create, update, link, comment, query, transition). Used by `gt-test-case-generator`, `ft-bug-reporter`, and any other skill that needs to touch an issue tracker.
- **`gf-*`** — git flow primitives (`gf-branch`, `gf-commit`, `gf-push`, `gf-pr`) and their orchestrator (`gf-ship`). Used by `ft-orchestrator` after a fix is verified, and by `gt-us-to-spec` at the ship phase.

Both families are listed as "already present in repo — do not regenerate" inside `ft-pipeline-b-regen-plan.md` and `gt-pipeline-a-regen-plan.md`. This document is the authoritative source for regenerating them if they are ever lost.

**Why a separate document:** These skills are cross-cutting infrastructure shared by both pipelines. Embedding them in either pipeline plan would be misleading and would make both those plans unwieldy.

---

## Directory Structure to Create

```
.claude/skills/
├── operations-with-issue-tracker/
│   ├── SKILL.md
│   ├── references/
│   │   ├── tracker-schema.md
│   │   ├── scripts.md
│   │   └── adapters.md
│   └── scripts/
│       ├── _common.sh
│       ├── _dispatch.sh
│       ├── preflight.sh
│       ├── get.sh
│       ├── create.sh
│       ├── update.sh
│       ├── update-steps.sh
│       ├── link.sh
│       ├── comment.sh
│       ├── query.sh
│       ├── transition.sh
│       └── adapters/
│           ├── fake/
│           │   ├── _common.sh
│           │   ├── _not_implemented.sh
│           │   ├── preflight.sh
│           │   ├── create.sh
│           │   └── get.sh
│           ├── github/
│           │   ├── _common.sh
│           │   ├── preflight.sh
│           │   ├── create.sh
│           │   ├── get.sh
│           │   ├── comment.sh
│           │   ├── update.sh
│           │   ├── update-steps.sh
│           │   ├── link.sh
│           │   ├── transition.sh
│           │   └── query.sh
│           ├── ado/
│           │   ├── preflight.sh
│           │   └── _not_implemented.sh
│           ├── jira/
│           │   ├── preflight.sh
│           │   └── _not_implemented.sh
│           └── linear/
│               ├── preflight.sh
│               └── _not_implemented.sh
├── gf-branch/
│   ├── SKILL.md
│   └── scripts/
│       └── create-branch.sh
├── gf-commit/
│   ├── SKILL.md
│   └── scripts/
│       └── create-commit.sh
├── gf-push/
│   ├── SKILL.md
│   └── scripts/
│       └── push-branch.sh
├── gf-pr/
│   ├── SKILL.md
│   ├── scripts/
│   │   └── create-pr.sh
│   └── adapters/
│       ├── github/
│       │   └── pr.sh
│       ├── ado/
│       │   └── pr.sh
│       └── gitlab/
│           └── pr.sh
└── gf-ship/
    ├── SKILL.md
    └── scripts/
        └── ship.sh
```

---

## 1. Output Contracts (JSON Schemas)

All scripts emit JSON only to stdout. Non-zero exit = failure.

### Common error envelope
```json
{ "error": "human-readable reason", "tracker": "github", "verb": "create" }
```

### `preflight.sh` success
```json
{ "ok": true, "cached_path": ".workflow-artifacts/.tracker-cache.json", "tracker": "github", "org": "acme", "project": "platform" }
```
Fake tracker variant: `{"ok":true,"tracker":"fake","base_url":"http://localhost:3000"}`

### `get.sh` success
```json
{
  "id": 11111,
  "type": "User Story",
  "title": "...",
  "description": "plain text",
  "acl": [],
  "parent_id": null,
  "url": "https://...",
  "steps_xml": "",
  "image_urls": []
}
```

### `create.sh` success
```json
{ "id": 11111, "url": "https://...", "deduped": false }
```
Fake tracker always returns `{"id":"TEST-xxxxx","url":"...","deduped":false}`. Normalized `id` may be `0` for legacy runs — this is valid.

### `update.sh` success
```json
{ "id": 11111, "updated": { "severity": "high", "priority": "p1", "state": "In Progress" } }
```

### `update-steps.sh` / `link.sh` / `comment.sh` success
```json
{ "ok": true }
```
`link.sh` adds `"existed": false/true`.

### `query.sh` success
```json
{ "results": [{ "id": 11111, "type": "Bug", "title": "...", "state": "OPEN", "url": "..." }], "count": 1 }
```

### `transition.sh` success
```json
{ "id": 11111, "from": "OPEN", "to": "Closed", "changed": true }
```

### `gf-branch` success
```json
{ "branch": "task/1234-fix-login-timeout", "base": "main", "base_sha": "abc123...", "work_item_id": 1234 }
```

### `gf-commit` success
```json
{ "sha": "deadbeef...", "branch": "task/1234-fix-login", "message": "fix(auth): correct token refresh timing", "files_committed": 2 }
```

### `gf-push` success
```json
{ "branch": "task/1234-fix-login", "remote": "origin", "set_upstream": true, "pushed_sha": "deadbeef..." }
```

### `gf-pr` success
```json
{ "id": 88, "url": "https://github.com/org/repo/pull/88", "title": "[1234] fix(auth): ...", "linked_work_item_id": 1234, "deduped": false }
```

### `gf-ship` success
```json
{ "run_id": "gfs-20240601-143012", "verdict": "success", "pr_url": "https://...", "branch_name": "task/...", "phases": [...] }
```

---

## 2. Universal Hard Constraints

### operations-with-issue-tracker

1. All scripts emit JSON to stdout only — never free-form text.
2. `preflight.sh` must be run once per session before any other script; all other scripts call `require_preflight`.
3. `_dispatch.sh` routes by `ISSUE_TRACKER` env var. Never hardcode a tracker in caller code.
4. Adapters handle all tracker-specific field mapping; public scripts stay tracker-neutral.
5. `id:0` from fake tracker on create is valid — not an error.
6. Unsupported verbs on fake tracker return `{"ok":true,"skipped":true}` — not an error.
7. ADO, Jira, and Linear adapters are stub-only (preflight + `_not_implemented.sh`) — not tested against live credentials.
8. `--dedupe-by` on create prevents duplicate items; always use it in pipeline contexts.
9. `.env` is sourced automatically by `_common.sh`; never prefix bash calls with `source .env &&`.

### gf-* skills

1. Never create a branch from or on `main`/`master`.
2. Never force-push.
3. Never commit on `main`/`master`.
4. Never skip hooks (`--no-verify`).
5. Secret files (`.env`, `*.key`, `*.pem`, `playwright/.auth/*.json`) are blocked by `create-commit.sh` — callers must not pre-stage them.
6. `gf-ship` is EXPLICIT-INVOCATION ONLY — never auto-triggered from other skills.
7. Individual skills never read their own bash scripts before executing them — call them directly.
8. Return exact JSON output from scripts — never summarize or invent field values.
9. `gf-pr` deduplicates: if an open PR already exists on the branch, return it with `deduped: true`.
10. `GITHUB_TOKEN` / `GH_TOKEN` must be present before the PR phase; sourced from `.env` automatically.

---

## 3. File Contents

### 3.1 `operations-with-issue-tracker/SKILL.md`

```markdown
---
name: operations-with-issue-tracker
description: >
  Unified issue-tracker wrapper skill for downstream agentic flows. Use when
  any workflow needs to read, create, update, link, comment on, query, or
  transition work items. Supports GitHub Issues, ADO, Jira, Linear, and the
  fake mock tracker (localhost or ngrok). Strongly prefer this skill over direct
  tracker CLI/API calls so all callers share one stable JSON contract.
---

# operations-with-issue-tracker

Stable JSON interface for issue-tracker operations. All callers must use these
wrapper scripts and must not invoke tracker-specific CLIs or APIs directly.

## When this skill fits

Use it for:

- Fetching a user story, bug, or test case by ID
- Creating a bug, test case, or task in the tracker
- Updating, linking, or commenting on work items
- Any tracker operation inside Pipeline A or Pipeline B

Do **not** call tracker APIs directly — always go through these scripts.

## Required environment

Set `ISSUE_TRACKER` to one of: `ado`, `github`, `jira`, `linear`, `fake`

| Tracker | Required vars |
|---|---|
| `ado` | `ADO_TOKEN` |
| `github` | `GITHUB_TOKEN` or `GH_TOKEN`, `REPO_OWNER`, `REPO_NAME` |
| `jira` | `JIRA_BASE_URL`, `JIRA_TOKEN` |
| `linear` | `LINEAR_TOKEN` |
| `fake` | `FAKE_TRACKER_URL` (ngrok URL or `http://localhost:3000`) |

### Fake tracker (`ISSUE_TRACKER=fake`)

The fake tracker is a lightweight mock REST server. No auth is needed.

```bash
export ISSUE_TRACKER=fake
export FAKE_TRACKER_URL=https://<your-ngrok-domain>  # or http://localhost:3000
```

Supported endpoints: `GET /tasks/:id`, `GET /bugs/:id`, `GET /testcases/:id`,
`POST /tasks/create`, `POST /bugs/create`, `POST /testcases/create`

Unsupported verbs (update, link, comment, query, transition) return
`{"ok":true,"skipped":true}` — they do not fail.

The fake tracker returns `{"status":"ok"}` on create with no ID.
The adapter normalizes this to `{"id":0,"url":"...","deduped":false}`.

## Script inventory

All scripts emit JSON only to stdout.

| Script | Purpose |
|---|---|
| `scripts/preflight.sh` | Validate config and write cache |
| `scripts/get.sh --id <id>` | Fetch work item by ID |
| `scripts/create.sh --type <t> --title <t>` | Create work item |
| `scripts/update.sh --id <id>` | Update fields |
| `scripts/update-steps.sh --id <id>` | Update test case steps |
| `scripts/link.sh --source <id> --target <id>` | Link two items |
| `scripts/comment.sh --id <id> --body-file <f>` | Add comment |
| `scripts/query.sh --query <q>` | Search work items |
| `scripts/transition.sh --id <id> --to <state>` | Change state |

## Workflow

### 1. Run preflight once per session

```bash
bash .claude/skills/operations-with-issue-tracker/scripts/preflight.sh
```

### 2. Fetch a work item

```bash
bash .claude/skills/operations-with-issue-tracker/scripts/get.sh --id 112
```

### 3. Create a work item

```bash
bash .claude/skills/operations-with-issue-tracker/scripts/create.sh \
  --type "Bug" \
  --title "Login button unresponsive on Safari" \
  --description-file /tmp/bug-desc.md \
  --tag "claude-generated" \
  --dedupe-by title
```

Returns: `{ "id": 11111, "url": "https://...", "deduped": false }`

With fake tracker: `{"id":0,"url":"http://localhost:3000/bugs/create","deduped":false}`

## Output contract

- **Success:** domain object (e.g. `{"id":123,...}` or `{"ok":true}`)
- **Failure:** `{"error":"human-readable reason",...context}` + non-zero exit

## Rules

1. Run `preflight.sh` once before any other script in a session.
2. Use `--dedupe-by` on create calls to avoid duplicate items.
3. Do not hardcode tracker field IDs in caller code.
4. Keep caller logic tracker-agnostic — adapter scripts handle tracker specifics.
5. With the fake tracker, `id:0` on create is expected and valid.

## References

- Detailed contracts: `references/tracker-schema.md`
- Script usage examples: `references/scripts.md`
- Adapter behavior: `references/adapters.md`
```

---

### 3.2 `operations-with-issue-tracker/scripts/_common.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

# Load .env from project root if present and vars not already set
if [[ -f "${PWD}/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${PWD}/.env"
  set +a
fi

WORKFLOW_DIR="${WORKFLOW_ARTIFACTS_DIR:-${PWD}/.workflow-artifacts}"
CACHE_PATH="${WORKFLOW_DIR}/.tracker-cache.json"

json_escape() {
  local value="${1-}"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  value="${value//$'\t'/\\t}"
  printf '%s' "$value"
}

emit_error() {
  local message="${1:-unknown error}"
  shift || true
  local json
  json="{\"error\":\"$(json_escape "$message")\""
  while [[ $# -gt 1 ]]; do
    local key="$1"
    local value="$2"
    shift 2
    json+=",\"$(json_escape "$key")\":\"$(json_escape "$value")\""
  done
  json+="}"
  printf '%s\n' "$json"
  exit 1
}

emit_ok() {
  local json='{"ok":true'
  while [[ $# -gt 1 ]]; do
    local key="$1"
    local value="$2"
    shift 2
    json+=",\"$(json_escape "$key")\":\"$(json_escape "$value")\""
  done
  json+='}'
  printf '%s\n' "$json"
}

require_cmd() {
  local cmd="${1:?missing command name}"
  command -v "$cmd" >/dev/null 2>&1 || emit_error "required command not found" "command" "$cmd"
}

tracker_from_env() {
  local tracker="${ISSUE_TRACKER:-}"
  [[ -z "$tracker" ]] && emit_error "ISSUE_TRACKER is required (ado|github|jira|linear)"
  case "$tracker" in
    ado|github|jira|linear|fake) ;;
    *) emit_error "ISSUE_TRACKER must be one of: ado|github|jira|linear|fake" "value" "$tracker" ;;
  esac
  printf '%s' "$tracker"
}

require_auth() {
  local tracker="${1:-$(tracker_from_env)}"
  case "$tracker" in
    ado)
      if [[ -z "${ADO_TOKEN:-}" ]]; then
        emit_error "ADO_TOKEN is required for ISSUE_TRACKER=ado"
      fi
      ;;
    github)
      if [[ -z "${GITHUB_TOKEN:-}" && -z "${GH_TOKEN:-}" ]]; then
        emit_error "GITHUB_TOKEN or GH_TOKEN is required for ISSUE_TRACKER=github"
      fi
      ;;
    jira)
      if [[ -z "${JIRA_BASE_URL:-}" ]]; then
        emit_error "JIRA_BASE_URL is required for ISSUE_TRACKER=jira"
      fi
      if [[ -z "${JIRA_TOKEN:-}" ]]; then
        emit_error "JIRA_TOKEN is required for ISSUE_TRACKER=jira"
      fi
      ;;
    linear)
      if [[ -z "${LINEAR_TOKEN:-}" ]]; then
        emit_error "LINEAR_TOKEN is required for ISSUE_TRACKER=linear"
      fi
      ;;
    fake)
      if [[ -z "${FAKE_TRACKER_URL:-}" ]]; then
        emit_error "FAKE_TRACKER_URL is required for ISSUE_TRACKER=fake (e.g. http://localhost:3000 or https://<ngrok>.ngrok.io)"
      fi
      ;;
  esac
}

ensure_workflow_dir() {
  mkdir -p "$WORKFLOW_DIR"
}

require_preflight() {
  local tracker="${1:-$(tracker_from_env)}"
  [[ -f "$CACHE_PATH" ]] || emit_error "preflight cache missing; run scripts/preflight.sh first" "cache_path" "$CACHE_PATH"
  if ! grep -Eiq "\"tracker\"[[:space:]]*:[[:space:]]*\"${tracker}\"" "$CACHE_PATH"; then
    emit_error "preflight cache is for a different tracker; rerun scripts/preflight.sh" "cache_path" "$CACHE_PATH" "tracker" "$tracker"
  fi
}

slug() {
  local input="${1-}"
  printf '%s' "$input" \
    | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9]/-/g; s/-\+/-/g; s/^-//; s/-$//'
}

sha1_prefix() {
  local input="${1-}"
  local length="${2:-12}"
  local hash=""
  if command -v sha1sum >/dev/null 2>&1; then
    hash="$(printf '%s' "$input" | sha1sum | awk '{print $1}')"
  elif command -v shasum >/dev/null 2>&1; then
    hash="$(printf '%s' "$input" | shasum -a 1 | awk '{print $1}')"
  elif command -v openssl >/dev/null 2>&1; then
    hash="$(printf '%s' "$input" | openssl sha1 | awk '{print $NF}')"
  else
    hash="$(printf '%s' "$input" | tr -cd 'a-zA-Z0-9' | tr '[:upper:]' '[:lower:]')"
  fi
  printf '%s' "${hash:0:${length}}"
}

html_encode() {
  local input="${1-}"
  printf '%s' "$input" \
    | sed -e 's/&/\&amp;/g' \
          -e 's/</\&lt;/g' \
          -e 's/>/\&gt;/g' \
          -e 's/"/\&quot;/g' \
          -e "s/'/\&#39;/g"
}

md_to_html() {
  local src="${1-}"
  local markdown=""
  if [[ -f "$src" ]]; then
    markdown="$(cat "$src")"
  else
    markdown="$src"
  fi

  if command -v pandoc >/dev/null 2>&1; then
    printf '%s' "$markdown" | pandoc -f gfm -t html
    return 0
  fi

  local escaped
  escaped="$(html_encode "$markdown")"
  escaped="$(printf '%s' "$escaped" | sed ':a;N;$!ba;s/\r//g;s/\n\n/<\/p><p>/g;s/\n/<br\/>/g')"
  printf '<p>%s</p>' "$escaped"
}

is_valid_json() {
  local payload="${1-}"
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$payload" | jq -e . >/dev/null 2>&1
    return $?
  fi
  printf '%s' "$payload" | grep -Eq '^[[:space:]]*[{[]'
}

normalize_json() {
  local payload="${1-}"
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$payload" | jq -c .
    return 0
  fi
  printf '%s' "$payload" | tr -d '\r' | tr '\n' ' '
}
```

---

### 3.3 `operations-with-issue-tracker/scripts/_dispatch.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"

dispatch_to_adapter() {
  local verb="${1:?missing verb}"
  shift || true

  local tracker
  tracker="$(tracker_from_env)"
  local adapter_dir="${SCRIPT_DIR}/adapters/${tracker}"
  local adapter="${adapter_dir}/${verb}.sh"
  local fallback="${adapter_dir}/_not_implemented.sh"

  if [[ ! -f "$adapter" ]]; then
    [[ -f "$fallback" ]] || emit_error "adapter not found" "tracker" "$tracker" "verb" "$verb"
    adapter="$fallback"
  fi

  local stdout_file stderr_file rc raw err normalized
  stdout_file="$(mktemp)"
  stderr_file="$(mktemp)"

  if [[ "$adapter" == "$fallback" ]]; then
    if bash "$adapter" "$verb" "$@" >"$stdout_file" 2>"$stderr_file"; then
      raw="$(cat "$stdout_file")"
      if [[ -z "${raw//[[:space:]]/}" ]]; then
        raw='{"ok":true}'
      fi
      is_valid_json "$raw" || emit_error "adapter returned invalid JSON" "tracker" "$tracker" "verb" "$verb"
      normalized="$(normalize_json "$raw")"
      rm -f "$stdout_file" "$stderr_file"
      printf '%s\n' "$normalized"
      return 0
    fi
  else
    if bash "$adapter" "$@" >"$stdout_file" 2>"$stderr_file"; then
      raw="$(cat "$stdout_file")"
      if [[ -z "${raw//[[:space:]]/}" ]]; then
        raw='{"ok":true}'
      fi
      is_valid_json "$raw" || emit_error "adapter returned invalid JSON" "tracker" "$tracker" "verb" "$verb"
      normalized="$(normalize_json "$raw")"
      rm -f "$stdout_file" "$stderr_file"
      printf '%s\n' "$normalized"
      return 0
    fi
  fi

  rc=$?
  raw="$(cat "$stdout_file" 2>/dev/null || true)"
  err="$(cat "$stderr_file" 2>/dev/null || true)"
  rm -f "$stdout_file" "$stderr_file"

  if [[ -n "${raw//[[:space:]]/}" ]] && is_valid_json "$raw"; then
    printf '%s\n' "$(normalize_json "$raw")"
    return "$rc"
  fi

  err="$(printf '%s' "$err" | tr '\r\n' ' ')"
  emit_error "adapter failed" "tracker" "$tracker" "verb" "$verb" "stderr" "$err"
}
```

---

### 3.4 `operations-with-issue-tracker/scripts/preflight.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"
source "${SCRIPT_DIR}/_dispatch.sh"

FORCE=false
while [[ $# -gt 0 ]]; do
  case $1 in
    --force) FORCE=true; shift ;;
    *) emit_error "unknown argument: $1" ;;
  esac
done

TRACKER="$(tracker_from_env)"
require_auth "$TRACKER"

ARGS=()
[[ "$FORCE" == true ]] && ARGS+=(--force)
dispatch_to_adapter preflight "${ARGS[@]}"
```

---

### 3.5 `operations-with-issue-tracker/scripts/get.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"
source "${SCRIPT_DIR}/_dispatch.sh"

ID=""
TYPE=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --id)   ID="${2-}";   shift 2 ;;
    --type) TYPE="${2-}"; shift 2 ;;
    *)
      if [[ -z "$ID" ]]; then
        ID="$1"
        shift
      else
        emit_error "unknown argument: $1"
      fi
      ;;
  esac
done

if [[ -z "$ID" ]]; then
  emit_error "missing id; use get.sh --id <item-id>"
fi

TRACKER="$(tracker_from_env)"
require_auth "$TRACKER"
require_preflight "$TRACKER"

DISPATCH_ARGS=(--id "$ID")
[[ -n "$TYPE" ]] && DISPATCH_ARGS+=(--type "$TYPE")
dispatch_to_adapter get "${DISPATCH_ARGS[@]}"
```

---

### 3.6 `operations-with-issue-tracker/scripts/create.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"
source "${SCRIPT_DIR}/_dispatch.sh"

TYPE=""
TITLE=""
DESCRIPTION_FILE=""
PARENT_ID=""
PARENT_RELATION=""
TAG=""
DEDUPE_BY=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --type) TYPE="${2-}"; shift 2 ;;
    --title) TITLE="${2-}"; shift 2 ;;
    --description-file) DESCRIPTION_FILE="${2-}"; shift 2 ;;
    --parent) PARENT_ID="${2-}"; shift 2 ;;
    --parent-relation) PARENT_RELATION="${2-}"; shift 2 ;;
    --tag) TAG="${2-}"; shift 2 ;;
    --dedupe-by) DEDUPE_BY="${2-}"; shift 2 ;;
    *) emit_error "unknown argument: $1" ;;
  esac
done

[[ -z "$TYPE" ]] && emit_error "missing --type"
[[ -z "$TITLE" ]] && emit_error "missing --title"

case "$TYPE" in
  "Test Case"|"User Story"|"Bug"|"Task") ;;
  *) emit_error "invalid --type; expected one of: Test Case|User Story|Bug|Task" "type" "$TYPE" ;;
esac

if [[ -n "$DEDUPE_BY" ]]; then
  case "$DEDUPE_BY" in
    title|tag|error-hash) ;;
    *) emit_error "invalid --dedupe-by; expected title|tag|error-hash" "dedupe_by" "$DEDUPE_BY" ;;
  esac
fi

if [[ -n "$DESCRIPTION_FILE" && ! -f "$DESCRIPTION_FILE" ]]; then
  emit_error "description file does not exist" "path" "$DESCRIPTION_FILE"
fi

TRACKER="$(tracker_from_env)"
require_auth "$TRACKER"
require_preflight "$TRACKER"

ARGS=(--type "$TYPE" --title "$TITLE")
[[ -n "$DESCRIPTION_FILE" ]] && ARGS+=(--description-file "$DESCRIPTION_FILE")
[[ -n "$PARENT_ID" ]] && ARGS+=(--parent "$PARENT_ID")
[[ -n "$PARENT_RELATION" ]] && ARGS+=(--parent-relation "$PARENT_RELATION")
[[ -n "$TAG" ]] && ARGS+=(--tag "$TAG")
[[ -n "$DEDUPE_BY" ]] && ARGS+=(--dedupe-by "$DEDUPE_BY")

dispatch_to_adapter create "${ARGS[@]}"
```

---

### 3.7 `operations-with-issue-tracker/scripts/update.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"
source "${SCRIPT_DIR}/_dispatch.sh"

ID=""
SEVERITY=""
PRIORITY=""
STATE=""
TAG=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --id) ID="${2-}"; shift 2 ;;
    --severity) SEVERITY="${2-}"; shift 2 ;;
    --priority) PRIORITY="${2-}"; shift 2 ;;
    --state) STATE="${2-}"; shift 2 ;;
    --tag) TAG="${2-}"; shift 2 ;;
    *) emit_error "unknown argument: $1" ;;
  esac
done

[[ -z "$ID" ]] && emit_error "missing --id"
if [[ -z "$SEVERITY" && -z "$PRIORITY" && -z "$STATE" && -z "$TAG" ]]; then
  emit_error "at least one update field is required (--severity|--priority|--state|--tag)"
fi

TRACKER="$(tracker_from_env)"
require_auth "$TRACKER"
require_preflight "$TRACKER"

ARGS=(--id "$ID")
[[ -n "$SEVERITY" ]] && ARGS+=(--severity "$SEVERITY")
[[ -n "$PRIORITY" ]] && ARGS+=(--priority "$PRIORITY")
[[ -n "$STATE" ]] && ARGS+=(--state "$STATE")
[[ -n "$TAG" ]] && ARGS+=(--tag "$TAG")

dispatch_to_adapter update "${ARGS[@]}"
```

---

### 3.8 `operations-with-issue-tracker/scripts/update-steps.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"
source "${SCRIPT_DIR}/_dispatch.sh"

ID=""
STEPS_FILE=""
REPLACE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --id) ID="${2-}"; shift 2 ;;
    --steps-file) STEPS_FILE="${2-}"; shift 2 ;;
    --replace) REPLACE=true; shift ;;
    *) emit_error "unknown argument: $1" ;;
  esac
done

[[ -z "$ID" ]] && emit_error "missing --id"
[[ -z "$STEPS_FILE" ]] && emit_error "missing --steps-file"
[[ -f "$STEPS_FILE" ]] || emit_error "steps file does not exist" "path" "$STEPS_FILE"

TRACKER="$(tracker_from_env)"
require_auth "$TRACKER"
require_preflight "$TRACKER"

ARGS=(--id "$ID" --steps-file "$STEPS_FILE")
[[ "$REPLACE" == true ]] && ARGS+=(--replace)
dispatch_to_adapter update-steps "${ARGS[@]}"
```

---

### 3.9 `operations-with-issue-tracker/scripts/link.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"
source "${SCRIPT_DIR}/_dispatch.sh"

SOURCE_ID=""
TARGET_ID=""
RELATION_TYPE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --source) SOURCE_ID="${2-}"; shift 2 ;;
    --target) TARGET_ID="${2-}"; shift 2 ;;
    --type) RELATION_TYPE="${2-}"; shift 2 ;;
    *) emit_error "unknown argument: $1" ;;
  esac
done

[[ -z "$SOURCE_ID" ]] && emit_error "missing --source"
[[ -z "$TARGET_ID" ]] && emit_error "missing --target"
[[ -z "$RELATION_TYPE" ]] && emit_error "missing --type"

TRACKER="$(tracker_from_env)"
require_auth "$TRACKER"
require_preflight "$TRACKER"

dispatch_to_adapter link --source "$SOURCE_ID" --target "$TARGET_ID" --type "$RELATION_TYPE"
```

---

### 3.10 `operations-with-issue-tracker/scripts/comment.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"
source "${SCRIPT_DIR}/_dispatch.sh"

ID=""
BODY_FILE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --id) ID="${2-}"; shift 2 ;;
    --body-file) BODY_FILE="${2-}"; shift 2 ;;
    *) emit_error "unknown argument: $1" ;;
  esac
done

[[ -z "$ID" ]] && emit_error "missing --id"
[[ -z "$BODY_FILE" ]] && emit_error "missing --body-file"
[[ -f "$BODY_FILE" ]] || emit_error "body file does not exist" "path" "$BODY_FILE"

TRACKER="$(tracker_from_env)"
require_auth "$TRACKER"
require_preflight "$TRACKER"

dispatch_to_adapter comment --id "$ID" --body-file "$BODY_FILE"
```

---

### 3.11 `operations-with-issue-tracker/scripts/query.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"
source "${SCRIPT_DIR}/_dispatch.sh"

QUERY=""
LIMIT="25"

while [[ $# -gt 0 ]]; do
  case $1 in
    --query) QUERY="${2-}"; shift 2 ;;
    --limit) LIMIT="${2-}"; shift 2 ;;
    *) emit_error "unknown argument: $1" ;;
  esac
done

[[ "$LIMIT" =~ ^[0-9]+$ ]] || emit_error "--limit must be an integer" "limit" "$LIMIT"

TRACKER="$(tracker_from_env)"
require_auth "$TRACKER"
require_preflight "$TRACKER"

ARGS=(--limit "$LIMIT")
[[ -n "$QUERY" ]] && ARGS+=(--query "$QUERY")
dispatch_to_adapter query "${ARGS[@]}"
```

---

### 3.12 `operations-with-issue-tracker/scripts/transition.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"
source "${SCRIPT_DIR}/_dispatch.sh"

ID=""
TO_STATE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --id) ID="${2-}"; shift 2 ;;
    --to) TO_STATE="${2-}"; shift 2 ;;
    *) emit_error "unknown argument: $1" ;;
  esac
done

[[ -z "$ID" ]] && emit_error "missing --id"
[[ -z "$TO_STATE" ]] && emit_error "missing --to"

TRACKER="$(tracker_from_env)"
require_auth "$TRACKER"
require_preflight "$TRACKER"

dispatch_to_adapter transition --id "$ID" --to "$TO_STATE"
```

---

### 3.13 `operations-with-issue-tracker/scripts/adapters/fake/_common.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

# Reads FAKE_TRACKER_URL from env — required, no default.
: "${FAKE_TRACKER_URL:?FAKE_TRACKER_URL is required (e.g. http://localhost:3000 or https://<ngrok>.ngrok.io)}"

fake_type_to_path() {
  local type="${1:?missing type}"
  case "$type" in
    "Bug")         printf 'bugs' ;;
    "Test Case")   printf 'testcases' ;;
    "Task"|"User Story"|*) printf 'tasks' ;;
  esac
}

# curl_with_retry <method> <url> [<extra curl args...>]
# Retries up to 3 times on HTTP 500 or connection failure.
curl_with_retry() {
  local method="${1:?missing method}"
  local url="${2:?missing url}"
  shift 2
  local attempt body http_code
  for attempt in 1 2 3; do
    body="$(curl -s -w '\n%{http_code}' -X "$method" "$url" "$@" 2>/dev/null || true)"
    http_code="$(printf '%s' "$body" | tail -n1)"
    body="$(printf '%s' "$body" | head -n -1)"
    if [[ "$http_code" =~ ^[2][0-9]{2}$ ]]; then
      printf '%s' "$body"
      return 0
    fi
    if [[ "$attempt" -lt 3 ]]; then
      sleep 1
    fi
  done
  printf '{"error":"fake tracker returned HTTP %s after 3 attempts","url":"%s"}\n' "$http_code" "$url"
  exit 1
}
```

---

### 3.14 `operations-with-issue-tracker/scripts/adapters/fake/preflight.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"

PARENT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${PARENT_DIR}/_common.sh"

WORKFLOW_DIR="${WORKFLOW_ARTIFACTS_DIR:-${PWD}/.workflow-artifacts}"
CACHE_PATH="${WORKFLOW_DIR}/.tracker-cache.json"

ensure_workflow_dir

response="$(curl -sf "${FAKE_TRACKER_URL}/" 2>/dev/null || true)"

if [[ -z "$response" ]]; then
  emit_error \
    "fake tracker not reachable at ${FAKE_TRACKER_URL} — start the server or set FAKE_TRACKER_URL to the correct ngrok URL" \
    "url" "${FAKE_TRACKER_URL}"
fi

cache="{\"ok\":true,\"tracker\":\"fake\",\"base_url\":\"${FAKE_TRACKER_URL}\"}"
printf '%s\n' "$cache" > "$CACHE_PATH"
printf '%s\n' "$cache"
```

---

### 3.15 `operations-with-issue-tracker/scripts/adapters/fake/create.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"

PARENT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${PARENT_DIR}/_common.sh"

TYPE=""
TITLE=""
DESCRIPTION_FILE=""
PARENT_ID=""
TAG=""
DEDUPE_BY=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --type)             TYPE="${2-}";             shift 2 ;;
    --title)            TITLE="${2-}";            shift 2 ;;
    --description-file) DESCRIPTION_FILE="${2-}"; shift 2 ;;
    --parent)           PARENT_ID="${2-}";        shift 2 ;;
    --parent-relation)  shift 2 ;;  # accepted but unused by fake tracker
    --tag)              TAG="${2-}";              shift 2 ;;
    --dedupe-by)        DEDUPE_BY="${2-}";        shift 2 ;;
    *) emit_error "unknown argument: $1" ;;
  esac
done

[[ -z "$TYPE" ]]  && emit_error "missing --type"
[[ -z "$TITLE" ]] && emit_error "missing --title"

DESCRIPTION=""
if [[ -n "$DESCRIPTION_FILE" && -f "$DESCRIPTION_FILE" ]]; then
  DESCRIPTION="$(cat "$DESCRIPTION_FILE")"
fi

PATH_SEGMENT="$(fake_type_to_path "$TYPE")"
URL="${FAKE_TRACKER_URL}/${PATH_SEGMENT}/create"

escaped_title="$(json_escape "$TITLE")"
escaped_desc="$(json_escape "$DESCRIPTION")"
escaped_tag="$(json_escape "$TAG")"
escaped_parent="$(json_escape "$PARENT_ID")"
escaped_type="$(json_escape "$TYPE")"
escaped_dedupe="$(json_escape "$DEDUPE_BY")"

if [[ "$PATH_SEGMENT" == "testcases" ]]; then
  if [[ -n "$DESCRIPTION" ]]; then
    steps_json="$(printf '%s' "$DESCRIPTION" | jq -Rs '[split("\n")[] | select(length > 0)]')"
    [[ "$steps_json" == "[]" ]] && steps_json="[\"${escaped_title}\"]"
  else
    steps_json="[\"${escaped_title}\"]"
  fi
  payload="{\"title\":\"${escaped_title}\",\"type\":\"${escaped_type}\",\"steps\":${steps_json}"
else
  payload="{\"title\":\"${escaped_title}\",\"description\":\"${escaped_desc}\",\"type\":\"${escaped_type}\""
fi
[[ -n "$TAG" ]]       && payload+=",\"tag\":\"${escaped_tag}\""
[[ -n "$PARENT_ID" ]] && payload+=",\"parent_id\":\"${escaped_parent}\""
[[ -n "$DEDUPE_BY" ]] && payload+=",\"dedupe_by\":\"${escaped_dedupe}\""
payload+="}"

response="$(curl_with_retry POST "$URL" \
  -H "Content-Type: application/json" \
  -d "$payload")"

tracker_id="$(printf '%s' "$response" | jq -r '.data.id // 0')"
escaped_url="$(json_escape "$URL")"
printf '{"id":"%s","url":"%s","deduped":false}\n' "$tracker_id" "$escaped_url"
```

---

### 3.16 `operations-with-issue-tracker/scripts/adapters/fake/get.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"

PARENT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${PARENT_DIR}/_common.sh"

ID=""
TYPE="Task"

while [[ $# -gt 0 ]]; do
  case $1 in
    --id)   ID="${2-}";   shift 2 ;;
    --type) TYPE="${2-}"; shift 2 ;;
    *) emit_error "unknown argument: $1" ;;
  esac
done

[[ -z "$ID" ]] && emit_error "missing --id"

PATH_SEGMENT="$(fake_type_to_path "$TYPE")"
URL="${FAKE_TRACKER_URL}/${PATH_SEGMENT}/${ID}"

raw="$(curl_with_retry GET "$URL")"

title="$(printf '%s' "$raw" | jq -r '.title // ""' 2>/dev/null || true)"
if [[ "$PATH_SEGMENT" == "testcases" ]]; then
  description="$(printf '%s' "$raw" | jq -r 'if (.steps | length) > 0 then .steps | join("\n") else (.description // "") end' 2>/dev/null || true)"
else
  description="$(printf '%s' "$raw" | jq -r '.description // ""' 2>/dev/null || true)"
fi

[[ -z "$title" ]] && title="item-${ID}"

escaped_title="$(json_escape "$title")"
escaped_desc="$(json_escape "$description")"
escaped_url="$(json_escape "$URL")"
escaped_type="$(json_escape "$TYPE")"

printf '{"id":%s,"type":"%s","title":"%s","description":"%s","acl":[],"parent_id":null,"url":"%s","steps_xml":"","image_urls":[]}\n' \
  "$ID" "$escaped_type" "$escaped_title" "$escaped_desc" "$escaped_url"
```

---

### 3.17 `operations-with-issue-tracker/scripts/adapters/fake/_not_implemented.sh`

```bash
#!/usr/bin/env bash
# Graceful no-op for verbs not supported by the fake tracker:
# update, update-steps, link, comment, query, transition.
printf '{"ok":true,"skipped":true,"reason":"verb not supported by fake tracker"}\n'
exit 0
```

The same pattern applies to the `_not_implemented.sh` in `ado/`, `jira/`, and `linear/` adapters — those files are identical in content.

---

### 3.18 `operations-with-issue-tracker/scripts/adapters/github/_common.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

ADAPTER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "${ADAPTER_DIR}/../.." && pwd)"
source "${SCRIPTS_DIR}/_common.sh"

gh_repo_args() {
  GH_REPO_ARGS=()
  if [[ -n "${TRACKER_REPO:-}" ]]; then
    GH_REPO_ARGS=(--repo "${TRACKER_REPO}")
  elif [[ -n "${REPO_OWNER:-}" && -n "${REPO_NAME:-}" ]]; then
    GH_REPO_ARGS=(--repo "${REPO_OWNER}/${REPO_NAME}")
  fi
}

gh_type_to_label() {
  case "${1:-Task}" in
    "Test Case") printf 'type:test-case' ;;
    "User Story") printf 'type:user-story' ;;
    "Bug") printf 'type:bug' ;;
    *) printf 'type:task' ;;
  esac
}

gh_normalized_type_jq() {
  cat <<'EOF'
if ([.labels[]?.name] | index("type:test-case")) then "Test Case"
elif ([.labels[]?.name] | index("type:user-story")) then "User Story"
elif ([.labels[]?.name] | index("type:bug")) then "Bug"
else "Task" end
EOF
}
```

---

### 3.19 `operations-with-issue-tracker/scripts/adapters/github/preflight.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"

FORCE=false
while [[ $# -gt 0 ]]; do
  case $1 in
    --force) FORCE=true; shift ;;
    *) emit_error "unknown argument: $1" ;;
  esac
done

require_cmd gh
if ! gh auth status >/dev/null 2>&1; then
  emit_error "gh auth is not configured"
fi

gh_repo_args

ORG="${REPO_OWNER:-}"
PROJECT="${REPO_NAME:-}"
if [[ -z "$ORG" || -z "$PROJECT" ]]; then
  REPO_FULL="$(gh repo view "${GH_REPO_ARGS[@]}" --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || true)"
  if [[ -n "$REPO_FULL" && "$REPO_FULL" == */* ]]; then
    ORG="${REPO_FULL%/*}"
    PROJECT="${REPO_FULL#*/}"
  fi
fi

ensure_workflow_dir
if [[ "$FORCE" == true || ! -f "$CACHE_PATH" ]]; then
  printf '{"tracker":"github","org":"%s","project":"%s","relation_types":["related","duplicate","tests","tested-by"],"generated_at":"%s"}\n' \
    "$(json_escape "$ORG")" "$(json_escape "$PROJECT")" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$CACHE_PATH"
fi

printf '{"ok":true,"cached_path":"%s","tracker":"github","org":"%s","project":"%s"}\n' \
  "$(json_escape "$CACHE_PATH")" "$(json_escape "$ORG")" "$(json_escape "$PROJECT")"
```

---

### 3.20 `operations-with-issue-tracker/scripts/adapters/github/create.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"

TYPE=""
TITLE=""
DESCRIPTION_FILE=""
PARENT_ID=""
PARENT_RELATION="Related"
TAG=""
DEDUPE_BY=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --type) TYPE="${2-}"; shift 2 ;;
    --title) TITLE="${2-}"; shift 2 ;;
    --description-file) DESCRIPTION_FILE="${2-}"; shift 2 ;;
    --parent) PARENT_ID="${2-}"; shift 2 ;;
    --parent-relation) PARENT_RELATION="${2-}"; shift 2 ;;
    --tag) TAG="${2-}"; shift 2 ;;
    --dedupe-by) DEDUPE_BY="${2-}"; shift 2 ;;
    *) emit_error "unknown argument: $1" ;;
  esac
done

[[ -z "$TYPE" ]] && emit_error "missing --type"
[[ -z "$TITLE" ]] && emit_error "missing --title"
if [[ -n "$DESCRIPTION_FILE" && ! -f "$DESCRIPTION_FILE" ]]; then
  emit_error "description file does not exist" "path" "$DESCRIPTION_FILE"
fi

require_cmd gh
gh_repo_args

DESCRIPTION=""
[[ -n "$DESCRIPTION_FILE" ]] && DESCRIPTION="$(cat "$DESCRIPTION_FILE")"

HASH_LABEL=""
SEARCH_QUERY=""
if [[ -n "$DEDUPE_BY" ]]; then
  case "$DEDUPE_BY" in
    title) SEARCH_QUERY="$TITLE in:title" ;;
    tag)
      FIRST_TAG="$(printf '%s' "$TAG" | awk -F',' '{print $1}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
      [[ -z "$FIRST_TAG" ]] && emit_error "--dedupe-by tag requires --tag"
      SEARCH_QUERY="label:${FIRST_TAG} ${TITLE} in:title"
      ;;
    error-hash)
      HASH_LABEL="error-hash:$(sha1_prefix "${TITLE}:${TYPE}")"
      SEARCH_QUERY="label:${HASH_LABEL}"
      ;;
    *) emit_error "invalid --dedupe-by" "value" "$DEDUPE_BY" ;;
  esac
fi

if [[ -n "$SEARCH_QUERY" ]]; then
  EXISTING_ID="$(gh issue list "${GH_REPO_ARGS[@]}" --state all --search "$SEARCH_QUERY" --limit 1 --json number --jq '.[0].number // empty' 2>/dev/null || true)"
  EXISTING_URL="$(gh issue list "${GH_REPO_ARGS[@]}" --state all --search "$SEARCH_QUERY" --limit 1 --json url --jq '.[0].url // empty' 2>/dev/null || true)"
  if [[ -n "$EXISTING_ID" && -n "$EXISTING_URL" ]]; then
    printf '{"id":%s,"url":"%s","deduped":true}\n' "$EXISTING_ID" "$(json_escape "$EXISTING_URL")"
    exit 0
  fi
fi

LABELS=("$(gh_type_to_label "$TYPE")")
if [[ -n "$TAG" ]]; then
  IFS=',' read -r -a TAGS <<<"$TAG"
  for tag_value in "${TAGS[@]}"; do
    cleaned="$(printf '%s' "$tag_value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [[ -n "$cleaned" ]] && LABELS+=("$cleaned")
  done
fi
[[ -n "$HASH_LABEL" ]] && LABELS+=("$HASH_LABEL")

LABEL_ARG=""
if [[ ${#LABELS[@]} -gt 0 ]]; then
  LABEL_ARG="$(IFS=,; echo "${LABELS[*]}")"
fi

BODY="$DESCRIPTION"
if [[ -n "$PARENT_ID" ]]; then
  [[ -n "$BODY" ]] && BODY+=$'\n\n'
  BODY+="Parent: #${PARENT_ID} (${PARENT_RELATION})"
fi

CREATE_ARGS=(--title "$TITLE" --body "$BODY")
[[ -n "$LABEL_ARG" ]] && CREATE_ARGS+=(--label "$LABEL_ARG")

CREATE_URL="$(gh issue create "${GH_REPO_ARGS[@]}" "${CREATE_ARGS[@]}" 2>/dev/null)" || emit_error "failed to create issue"
ISSUE_ID="${CREATE_URL##*/}"

if [[ -n "$PARENT_ID" ]]; then
  gh issue comment "$ISSUE_ID" "${GH_REPO_ARGS[@]}" \
    --body "[relation:${PARENT_RELATION}:${PARENT_ID}] auto-linked parent" >/dev/null 2>&1 || true
fi

printf '{"id":%s,"url":"%s","deduped":false}\n' "$ISSUE_ID" "$(json_escape "$CREATE_URL")"
```

---

### 3.21 `operations-with-issue-tracker/scripts/adapters/github/get.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"

ID=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --id) ID="${2-}"; shift 2 ;;
    *) emit_error "unknown argument: $1" ;;
  esac
done
[[ -z "$ID" ]] && emit_error "missing --id"

require_cmd gh
gh_repo_args

OUT="$(gh issue view "$ID" "${GH_REPO_ARGS[@]}" \
  --json number,title,body,url,labels \
  --jq '{
    id: .number,
    type: (
      if ([.labels[]?.name] | index("type:test-case")) then "Test Case"
      elif ([.labels[]?.name] | index("type:user-story")) then "User Story"
      elif ([.labels[]?.name] | index("type:bug")) then "Bug"
      else "Task"
      end
    ),
    title: .title,
    description: (.body // ""),
    acl: [],
    parent_id: null,
    url: .url,
    steps_xml: "",
    image_urls: []
  }' 2>/dev/null)" || emit_error "failed to fetch issue" "id" "$ID"

printf '%s\n' "$OUT"
```

---

### 3.22 `operations-with-issue-tracker/scripts/adapters/github/comment.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"

ID=""
BODY_FILE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --id) ID="${2-}"; shift 2 ;;
    --body-file) BODY_FILE="${2-}"; shift 2 ;;
    *) emit_error "unknown argument: $1" ;;
  esac
done

[[ -z "$ID" ]] && emit_error "missing --id"
[[ -z "$BODY_FILE" ]] && emit_error "missing --body-file"
[[ -f "$BODY_FILE" ]] || emit_error "body file does not exist" "path" "$BODY_FILE"

require_cmd gh
gh_repo_args

gh issue comment "$ID" "${GH_REPO_ARGS[@]}" --body-file "$BODY_FILE" >/dev/null 2>&1 \
  || emit_error "failed to post comment" "id" "$ID"

printf '{"ok":true}\n'
```

---

### 3.23 `operations-with-issue-tracker/scripts/adapters/github/update.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"

ID=""
SEVERITY=""
PRIORITY=""
STATE=""
TAG=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --id) ID="${2-}"; shift 2 ;;
    --severity) SEVERITY="${2-}"; shift 2 ;;
    --priority) PRIORITY="${2-}"; shift 2 ;;
    --state) STATE="${2-}"; shift 2 ;;
    --tag) TAG="${2-}"; shift 2 ;;
    *) emit_error "unknown argument: $1" ;;
  esac
done

[[ -z "$ID" ]] && emit_error "missing --id"

require_cmd gh
gh_repo_args

LABELS=()
[[ -n "$SEVERITY" ]] && LABELS+=("severity:${SEVERITY}")
[[ -n "$PRIORITY" ]] && LABELS+=("priority:${PRIORITY}")

if [[ -n "$TAG" ]]; then
  IFS=',' read -r -a TAGS <<<"$TAG"
  for tag_value in "${TAGS[@]}"; do
    cleaned="$(printf '%s' "$tag_value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [[ -n "$cleaned" ]] && LABELS+=("$cleaned")
  done
fi

if [[ ${#LABELS[@]} -gt 0 ]]; then
  LABEL_ARG="$(IFS=,; echo "${LABELS[*]}")"
  gh issue edit "$ID" "${GH_REPO_ARGS[@]}" --add-label "$LABEL_ARG" >/dev/null 2>&1 \
    || emit_error "failed to apply labels" "id" "$ID"
fi

if [[ -n "$STATE" ]]; then
  CURRENT_STATE="$(gh issue view "$ID" "${GH_REPO_ARGS[@]}" --json state --jq '.state' 2>/dev/null || true)"
  TARGET_STATE="$(printf '%s' "$STATE" | tr '[:upper:]' '[:lower:]')"
  case "$TARGET_STATE" in
    closed|close|done|resolved)
      if [[ "$CURRENT_STATE" != "CLOSED" ]]; then
        gh issue close "$ID" "${GH_REPO_ARGS[@]}" >/dev/null 2>&1 || emit_error "failed to close issue" "id" "$ID"
      fi
      ;;
    *)
      if [[ "$CURRENT_STATE" == "CLOSED" ]]; then
        gh issue reopen "$ID" "${GH_REPO_ARGS[@]}" >/dev/null 2>&1 || emit_error "failed to reopen issue" "id" "$ID"
      fi
      ;;
  esac
fi

UPDATED="{"
SEP=""
append_updated() {
  UPDATED+="${SEP}\"$(json_escape "$1")\":\"$(json_escape "$2")\""
  SEP=","
}
[[ -n "$SEVERITY" ]] && append_updated "severity" "$SEVERITY"
[[ -n "$PRIORITY" ]] && append_updated "priority" "$PRIORITY"
[[ -n "$STATE" ]] && append_updated "state" "$STATE"
[[ -n "$TAG" ]] && append_updated "tag" "$TAG"
UPDATED+="}"

printf '{"id":%s,"updated":%s}\n' "$ID" "$UPDATED"
```

---

### 3.24 `operations-with-issue-tracker/scripts/adapters/github/transition.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"

ID=""
TO_STATE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --id) ID="${2-}"; shift 2 ;;
    --to) TO_STATE="${2-}"; shift 2 ;;
    *) emit_error "unknown argument: $1" ;;
  esac
done

[[ -z "$ID" ]] && emit_error "missing --id"
[[ -z "$TO_STATE" ]] && emit_error "missing --to"

require_cmd gh
gh_repo_args

FROM_STATE="$(gh issue view "$ID" "${GH_REPO_ARGS[@]}" --json state --jq '.state' 2>/dev/null)" \
  || emit_error "failed to read current state" "id" "$ID"

TARGET_LC="$(printf '%s' "$TO_STATE" | tr '[:upper:]' '[:lower:]')"
DESIRED="OPEN"
case "$TARGET_LC" in
  close|closed|done|resolved) DESIRED="CLOSED" ;;
esac

CHANGED=false
if [[ "$DESIRED" == "CLOSED" && "$FROM_STATE" != "CLOSED" ]]; then
  gh issue close "$ID" "${GH_REPO_ARGS[@]}" >/dev/null 2>&1 || emit_error "failed to close issue" "id" "$ID"
  CHANGED=true
elif [[ "$DESIRED" == "OPEN" && "$FROM_STATE" == "CLOSED" ]]; then
  gh issue reopen "$ID" "${GH_REPO_ARGS[@]}" >/dev/null 2>&1 || emit_error "failed to reopen issue" "id" "$ID"
  CHANGED=true
fi

printf '{"id":%s,"from":"%s","to":"%s","changed":%s}\n' "$ID" "$(json_escape "$FROM_STATE")" "$(json_escape "$TO_STATE")" "$CHANGED"
```

---

### 3.25 `operations-with-issue-tracker/scripts/adapters/github/query.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"

QUERY=""
LIMIT="25"

while [[ $# -gt 0 ]]; do
  case $1 in
    --query) QUERY="${2-}"; shift 2 ;;
    --limit) LIMIT="${2-}"; shift 2 ;;
    *) emit_error "unknown argument: $1" ;;
  esac
done

[[ "$LIMIT" =~ ^[0-9]+$ ]] || emit_error "--limit must be numeric" "limit" "$LIMIT"
[[ -z "$QUERY" ]] && QUERY="is:issue"

require_cmd gh
gh_repo_args

OUT="$(gh issue list "${GH_REPO_ARGS[@]}" \
  --state all \
  --search "$QUERY" \
  --limit "$LIMIT" \
  --json number,title,url,state,labels \
  --jq '{
    results: map({
      id: .number,
      type: (
        if ([.labels[]?.name] | index("type:test-case")) then "Test Case"
        elif ([.labels[]?.name] | index("type:user-story")) then "User Story"
        elif ([.labels[]?.name] | index("type:bug")) then "Bug"
        else "Task"
        end
      ),
      title: .title,
      state: .state,
      url: .url
    }),
    count: length
  }' 2>/dev/null)" || emit_error "query failed"

printf '%s\n' "$OUT"
```

---

### 3.26 `operations-with-issue-tracker/scripts/adapters/github/link.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"

SOURCE_ID=""
TARGET_ID=""
RELATION_TYPE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --source) SOURCE_ID="${2-}"; shift 2 ;;
    --target) TARGET_ID="${2-}"; shift 2 ;;
    --type) RELATION_TYPE="${2-}"; shift 2 ;;
    *) emit_error "unknown argument: $1" ;;
  esac
done

[[ -z "$SOURCE_ID" ]] && emit_error "missing --source"
[[ -z "$TARGET_ID" ]] && emit_error "missing --target"
[[ -z "$RELATION_TYPE" ]] && emit_error "missing --type"

require_cmd gh
gh_repo_args

MARKER="[relation:${RELATION_TYPE}:${TARGET_ID}]"
EXISTED="$(gh issue view "$SOURCE_ID" "${GH_REPO_ARGS[@]}" --json comments \
  --jq --arg marker "$MARKER" '[.comments[]?.body | contains($marker)] | any' 2>/dev/null || echo false)"

if [[ "$EXISTED" == "true" ]]; then
  printf '{"ok":true,"existed":true}\n'
  exit 0
fi

gh issue comment "$SOURCE_ID" "${GH_REPO_ARGS[@]}" \
  --body "${MARKER} linked to #${TARGET_ID}" >/dev/null 2>&1 \
  || emit_error "failed to add relation comment" "source" "$SOURCE_ID" "target" "$TARGET_ID"

printf '{"ok":true,"existed":false}\n'
```

---

### 3.27 `operations-with-issue-tracker/scripts/adapters/github/update-steps.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"

ID=""
STEPS_FILE=""
REPLACE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --id) ID="${2-}"; shift 2 ;;
    --steps-file) STEPS_FILE="${2-}"; shift 2 ;;
    --replace) REPLACE=true; shift ;;
    *) emit_error "unknown argument: $1" ;;
  esac
done

[[ -z "$ID" ]] && emit_error "missing --id"
[[ -z "$STEPS_FILE" ]] && emit_error "missing --steps-file"
[[ -f "$STEPS_FILE" ]] || emit_error "steps file does not exist" "path" "$STEPS_FILE"

require_cmd gh
gh_repo_args

CURRENT_BODY="$(gh issue view "$ID" "${GH_REPO_ARGS[@]}" --json body --jq '.body // ""' 2>/dev/null || true)"
if [[ "$REPLACE" == true ]]; then
  CURRENT_BODY="$(printf '%s' "$CURRENT_BODY" | sed '/^### Test Steps (generated)$/,$d')"
fi

STEPS_XML="$(cat "$STEPS_FILE")"
NEW_BODY="$CURRENT_BODY"
[[ -n "$NEW_BODY" ]] && NEW_BODY+=$'\n\n'
NEW_BODY+="### Test Steps (generated)"
NEW_BODY+=$'\n```xml\n'
NEW_BODY+="$STEPS_XML"
NEW_BODY+=$'\n```'

gh issue edit "$ID" "${GH_REPO_ARGS[@]}" --body "$NEW_BODY" >/dev/null 2>&1 \
  || emit_error "failed to update test steps" "id" "$ID"

printf '{"ok":true}\n'
```

---

### 3.28 `operations-with-issue-tracker/scripts/adapters/ado/preflight.sh`

```bash
#!/usr/bin/env bash
# NOT TESTED — requires live credentials; no automated test coverage.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../_common.sh"

while [[ $# -gt 0 ]]; do
  case $1 in
    --force) shift ;;
    *) emit_error "unknown argument: $1" ;;
  esac
done

require_cmd az
require_auth ado

ORG="${TRACKER_ORG:-${REPO_OWNER:-}}"
PROJECT="${TRACKER_PROJECT:-${ADO_PROJECT:-${REPO_NAME:-}}}"

ensure_workflow_dir
printf '{"tracker":"ado","org":"%s","project":"%s","relation_types":["System.LinkTypes.Related","System.LinkTypes.Hierarchy-Forward","Microsoft.VSTS.Common.Tests","Microsoft.VSTS.Common.TestedBy-Reverse"],"generated_at":"%s"}\n' \
  "$(json_escape "$ORG")" "$(json_escape "$PROJECT")" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$CACHE_PATH"

printf '{"ok":true,"cached_path":"%s","tracker":"ado","org":"%s","project":"%s"}\n' \
  "$(json_escape "$CACHE_PATH")" "$(json_escape "$ORG")" "$(json_escape "$PROJECT")"
```

The `jira/preflight.sh` and `linear/preflight.sh` follow the same pattern — preflight writes the cache, all other verbs delegate to `_not_implemented.sh`.

---

### 3.29 `operations-with-issue-tracker/references/tracker-schema.md`

(Content as shown in Section 1 of this plan — emit the full schema reference for `preflight`, `get`, `create`, `update`, `update-steps`, `link`, `comment`, `query`, `transition`.)

---

### 3.30 `operations-with-issue-tracker/references/scripts.md`

```markdown
# Script reference

All commands emit JSON only.

## Preflight
```bash
bash scripts/preflight.sh [--force]
```

## Get
```bash
bash scripts/get.sh --id 11111
```

## Create
```bash
bash scripts/create.sh \
  --type "Test Case" \
  --title "Validate checkout address" \
  --description-file .workflow-artifacts/desc.md \
  --parent 40001 \
  --parent-relation "Tests" \
  --tag "automation,smoke" \
  --dedupe-by title
```

## Update
```bash
bash scripts/update.sh --id 11111 --severity high --priority p1 --state "In Progress" --tag "triaged"
```

## Update steps
```bash
bash scripts/update-steps.sh --id 11111 --steps-file .workflow-artifacts/steps.xml --replace
```

## Link
```bash
bash scripts/link.sh --source 11111 --target 11110 --type Related
```

## Comment
```bash
bash scripts/comment.sh --id 11111 --body-file .workflow-artifacts/comment.md
```

## Query
```bash
bash scripts/query.sh --query "state:open label:type:bug" --limit 20
```

## Transition
```bash
bash scripts/transition.sh --id 11111 --to Closed
```
```

---

### 3.31 `operations-with-issue-tracker/references/adapters.md`

```markdown
# Adapter reference

Adapter scripts live under:
`scripts/adapters/<tracker>/<verb>.sh`

Each adapter must emit the same JSON shape for each verb.

## Current support

- `github`: implemented for all verbs (`gh` CLI)
- `fake`: get and create implemented; update, update-steps, link, comment, query, transition return `{"ok":true,"skipped":true}` (no-op)
- `ado`: preflight implemented, verb stubs return JSON errors
- `jira`: preflight implemented, verb stubs return JSON errors
- `linear`: preflight implemented, verb stubs return JSON errors

## Adapter contract rules

1. Print JSON to stdout only.
2. Exit non-zero on failure.
3. Keep caller-facing fields tracker-neutral.
4. Handle tracker-native field mapping inside adapter scripts only.
```

---

### 3.32 `gf-branch/SKILL.md`

```markdown
---
name: gf-branch
description: >-
  Create a new Git branch from the latest main branch. Use when starting work
  on a feature, fix, or task. Requires a work-item-id or an explicit branch
  name; if neither is supplied, ask for it and stop. Do not use for merging,
  deleting branches, or opening pull requests.
argument-hint: "work-item-id [optional title]"
---

# gf-branch

Create and switch to a new feature branch safely.

## When this skill fits

Use it for requests like:

- "create a branch for task 1234"
- "start a branch for this fix"
- "checkout a new branch called fix/login-timeout"

Do **not** use it for:

- merging or rebasing branches
- deleting or renaming branches
- pushing or opening pull requests

## Workflow

### 1. Require a work-item-id or branch name

If neither is supplied, respond with:
```text
A work-item-id or branch name is required to create a branch.
```
Then stop.

### 2. Confirm the workspace is a git repo

Verify `git rev-parse --is-inside-work-tree` returns success.

### 3. Create the branch

```bash
bash .claude/skills/gf-branch/scripts/create-branch.sh \
  --work-item-id <id> \
  --title "<title>" \
  --base main
```

The script fetches latest `main`, verifies FF-only, refuses if branch exists locally or on origin, creates `task/<id>[-<slug>]`.

### 4. Return the result

Return the exact JSON output from the script. Do not paraphrase.

## Hard rules

- Never invent a branch name without a work-item-id or explicit input.
- Never create a branch from or on `main`.
- If the branch already exists, stop and show the script error.
- Return the exact git result, not a summary.
- Never read the bash scripts before executing them. Call them directly.
```

---

### 3.33 `gf-branch/scripts/create-branch.sh`

```bash
#!/usr/bin/env bash
# Creates a safe feature branch from the base branch.
# Usage: create-branch.sh --work-item-id 11111 --title "filter order number" [--base main]

set -euo pipefail

die() { printf '{"error":"%s","branch":"%s","location":"%s"}\n' "$1" "${BRANCH:-}" "${LOCATION:-}"; exit 1; }
json_success() { printf '%s\n' "$1"; exit 0; }

WORK_ITEM_ID=""
WORK_ITEM_TITLE=""
BASE="${CORE_BRANCH:-main}"

while [[ $# -gt 0 ]]; do
  case $1 in
    --work-item-id) WORK_ITEM_ID="$2"; shift 2 ;;
    --title)        WORK_ITEM_TITLE="$2"; shift 2 ;;
    --base)         BASE="$2"; shift 2 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ -z "$WORK_ITEM_ID" ]] && die "missing --work-item-id"

slug() {
  echo "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9]/-/g; s/-\+/-/g; s/^-//; s/-$//'
}

TITLE_SLUG=$(slug "${WORK_ITEM_TITLE:-}")
RAW="task/${WORK_ITEM_ID}${TITLE_SLUG:+-$TITLE_SLUG}"
BRANCH="${RAW:0:60}"

git rev-parse --git-dir >/dev/null 2>&1 || die "not a git repository"
git fetch origin "$BASE" 2>/dev/null || die "could not fetch origin/$BASE"

LOCAL_SHA=$(git rev-parse "$BASE" 2>/dev/null || true)
REMOTE_SHA=$(git rev-parse "origin/$BASE")
if [[ -n "$LOCAL_SHA" && "$LOCAL_SHA" != "$REMOTE_SHA" ]]; then
  git merge --ff-only "origin/$BASE" 2>/dev/null || die "base branch cannot be fast-forwarded — merge or rebase first"
fi

LOCATION=""
if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  LOCATION="local"
  die "branch already exists"
fi

if git ls-remote --exit-code --heads origin "$BRANCH" >/dev/null 2>&1; then
  LOCATION="origin"
  die "branch already exists"
fi

BASE_SHA=$(git rev-parse "origin/$BASE")
git switch -c "$BRANCH" "origin/$BASE"

json_success "$(printf '{"branch":"%s","base":"%s","base_sha":"%s","work_item_id":%s}' \
  "$BRANCH" "$BASE" "$BASE_SHA" "$WORK_ITEM_ID")"
```

---

### 3.34 `gf-commit/SKILL.md`

```markdown
---
name: gf-commit
description: >-
  Create a conventional commit on the current Git branch from staged changes.
  Use when the user asks to commit current work, save changes, or generate a
  commit message. Stages all modified files automatically, drafts a conventional
  commit message, and commits without asking for confirmation.
argument-hint: "optional commit context or scope"
---

# gf-commit

Create a commit for the current branch using the real git changes.

## Workflow

### 1. Stage all changes
```bash
git add .
```

### 2. Preview staged changes
```bash
git status --short
git diff --staged --stat
```
If no staged changes, stop.

### 3. Draft a conventional commit message

Format: `<type>[optional scope]: <subject>`

Types: `feat` | `fix` | `test` | `refactor` | `chore` | `ci` | `docs`

Subject: imperative mood, under 72 chars.

### 4. Create the commit

```bash
bash .claude/skills/gf-commit/scripts/create-commit.sh \
  --type <type> \
  --subject "<subject>" \
  --scope "<scope>" \
  --body "<body>" \
  --files <staged-paths>
```

Return the exact JSON output.

## Hard rules

- Never commit on `main` or `master`.
- Never commit secrets (`.env`, `*.pem`, `*.key`, `playwright/.auth/*.json`).
- Do not amend existing commits.
- Never skip hooks.
- Never read the bash scripts before executing them. Call them directly.
```

---

### 3.35 `gf-commit/scripts/create-commit.sh`

```bash
#!/usr/bin/env bash
# Conventional commit with secret detection.
# Usage: create-commit.sh --type fix --scope orders --subject "scope date filter" [--body "..."] [--files "path1 path2"]

set -euo pipefail

json_err()  { printf '{"error":"%s","paths":%s}\n' "$1" "${2:-[]}"; exit 1; }
json_ok()   { printf '%s\n' "$1"; exit 0; }

TYPE=""; SCOPE=""; SUBJECT=""; BODY=""; EXTRA_FILES=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --type)    TYPE="$2";    shift 2 ;;
    --scope)   SCOPE="$2";   shift 2 ;;
    --subject) SUBJECT="$2"; shift 2 ;;
    --body)    BODY="$2";    shift 2 ;;
    --files)   read -ra EXTRA_FILES <<< "$2"; shift 2 ;;
    *) json_err "unknown argument: $1" "[]" ;;
  esac
done

[[ -z "$TYPE" ]]    && json_err "missing --type"    "[]"
[[ -z "$SUBJECT" ]] && json_err "missing --subject" "[]"

VALID_TYPES="feat fix chore docs test refactor ci perf style revert"
[[ " $VALID_TYPES " == *" $TYPE "* ]] || json_err "invalid type: $TYPE (use one of: $VALID_TYPES)" "[]"

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
[[ "$CURRENT_BRANCH" == "main" || "$CURRENT_BRANCH" == "master" ]] \
  && json_err "refusing to commit directly on $CURRENT_BRANCH" "[]"

if [[ ${#EXTRA_FILES[@]} -gt 0 ]]; then
  git add -- "${EXTRA_FILES[@]}"
fi

mapfile -t STAGED < <(git diff --cached --name-only)
[[ ${#STAGED[@]} -eq 0 ]] && json_err "nothing staged to commit" "[]"

SECRET_PATTERNS=(
  '\.env$' '\.env\.' '\.key$' '\.pem$' '\.pfx$'
  'id_rsa' 'id_ed25519'
  'playwright/\.auth/.*\.json$'
  '\.p12$' 'secrets\.'
)

BAD_PATHS=()
for f in "${STAGED[@]}"; do
  for pat in "${SECRET_PATTERNS[@]}"; do
    if echo "$f" | grep -qE "$pat"; then
      BAD_PATHS+=("$f")
      break
    fi
  done
done

if [[ ${#BAD_PATHS[@]} -gt 0 ]]; then
  BAD_JSON=$(printf '"%s",' "${BAD_PATHS[@]}")
  BAD_JSON="[${BAD_JSON%,}]"
  json_err "refusing to commit secrets" "$BAD_JSON"
fi

if [[ -n "$SCOPE" ]]; then
  MSG_HEADER="${TYPE}(${SCOPE}): ${SUBJECT}"
else
  MSG_HEADER="${TYPE}: ${SUBJECT}"
fi

[[ -n "$BODY" ]] && FULL_MSG="${MSG_HEADER}"$'\n\n'"${BODY}" || FULL_MSG="$MSG_HEADER"

git commit -m "$FULL_MSG"

SHA=$(git rev-parse HEAD)
BRANCH=$(git rev-parse --abbrev-ref HEAD)

json_ok "$(printf '{"sha":"%s","branch":"%s","message":"%s","files_committed":%d}' \
  "$SHA" "$BRANCH" "$MSG_HEADER" "${#STAGED[@]}")"
```

---

### 3.36 `gf-push/SKILL.md`

```markdown
---
name: gf-push
description: >-
  Push the current local branch to origin using the same branch name. Use when
  the user wants to publish local commits or push a feature branch. Refuses to
  push main or master. Never force-pushes.
argument-hint: "optional remote name (default: origin)"
---

# gf-push

Push the current branch to `origin` safely.

## Workflow

### 1. Detect the current branch
Run `git branch --show-current`. Stop if it is `main` or `master`.

### 2. Push the branch

```bash
bash .claude/skills/gf-push/scripts/push-branch.sh
```

### 3. Return the result

Show the exact JSON output.

## Hard rules

- Never push `main` or `master`.
- Never add `--force` or `--force-with-lease`.
- Return the exact git result.
- Never read the bash scripts before executing them.
```

---

### 3.37 `gf-push/scripts/push-branch.sh`

```bash
#!/usr/bin/env bash
# Pushes the current branch to origin. Refuses main, force-push forbidden.

set -euo pipefail

json_err() { printf '{"error":"%s","branch":"%s","stderr":"%s"}\n' "$1" "${BRANCH:-}" "${2:-}"; exit 1; }
json_ok()  { printf '%s\n' "$1"; exit 0; }

REMOTE="origin"
while [[ $# -gt 0 ]]; do
  case $1 in
    --remote) REMOTE="$2"; shift 2 ;;
    *) json_err "unknown argument: $1" ;;
  esac
done

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) \
  || json_err "not a git repository" ""

[[ "$BRANCH" == "main" || "$BRANCH" == "master" ]] \
  && json_err "refusing to push directly to $BRANCH" ""

SET_UPSTREAM=true
if git rev-parse --abbrev-ref --symbolic-full-name "@{u}" >/dev/null 2>&1; then
  SET_UPSTREAM=false
fi

PUSH_STDERR_FILE=$(mktemp)
PUSH_FLAGS=(-u "$REMOTE" HEAD)

if ! git push "${PUSH_FLAGS[@]}" 2>"$PUSH_STDERR_FILE"; then
  STDERR_SNIPPET=$(tail -5 "$PUSH_STDERR_FILE" | tr '\n' ' ' | sed 's/"/\\"/g')
  rm -f "$PUSH_STDERR_FILE"
  json_err "push failed" "$STDERR_SNIPPET"
fi
rm -f "$PUSH_STDERR_FILE"

PUSHED_SHA=$(git rev-parse HEAD)

json_ok "$(printf '{"branch":"%s","remote":"%s","set_upstream":%s,"pushed_sha":"%s"}' \
  "$BRANCH" "$REMOTE" "$( [[ $SET_UPSTREAM == true ]] && echo true || echo false)" "$PUSHED_SHA")"
```

---

### 3.38 `gf-pr/SKILL.md`

```markdown
---
name: gf-pr
description: >-
  Create a pull request from the current branch to main on GitHub. Use when the
  user asks to open a PR, publish work for review, or create a pull request.
  Requires GITHUB_TOKEN. Deduplicates: if a PR already exists for the branch,
  returns the existing one. Do not use for merging, force-push, or PRs from main.
argument-hint: "optional PR title or work-item-id"
---

# gf-pr

Create a pull request from the current branch to `main` on GitHub.

## Workflow

### 1. Detect current branch. Stop if it is `main` or `master`.

### 2. Verify GITHUB_TOKEN is set (sourced from `.env` automatically).

### 3. Create the PR

```bash
bash .claude/skills/gf-pr/scripts/create-pr.sh \
  --work-item-id <id> \
  --base main
```

The script checks for an existing open PR on this branch (deduplication), builds
the PR title from work-item-id or commits, uses PR template if found, delegates
to `adapters/${PR_HOST}/pr.sh`.

### 4. Return exact JSON output including `url`.

## Hard rules

- Never create a PR from `main`.
- Never proceed without `GITHUB_TOKEN`.
- Never invent a PR URL.
- If open PR already exists, return it with `deduped: true`.
- Never read bash scripts before executing them.
```

---

### 3.39 `gf-pr/scripts/create-pr.sh`

```bash
#!/usr/bin/env bash
# Opens a PR (or returns the existing one). Delegates to the correct host adapter via PR_HOST.

set -euo pipefail

[ -z "${GITHUB_TOKEN:-}" ] && [ -f .env ] && { set -a; source .env; set +a; }

json_err() { printf '{"error":"%s"}\n' "$1"; exit 1; }

TITLE=""; WORK_ITEM_ID=""; BASE="${CORE_BRANCH:-main}"; DRAFT=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --title)         TITLE="$2";          shift 2 ;;
    --work-item-id)  WORK_ITEM_ID="$2";   shift 2 ;;
    --base)          BASE="$2";           shift 2 ;;
    --draft)         DRAFT=true;          shift   ;;
    *) json_err "unknown argument: $1" ;;
  esac
done

PR_HOST="${PR_HOST:-}"
[[ -z "$PR_HOST" ]] && json_err "PR_HOST not set (github|gitlab|ado)"
[[ "$PR_HOST" =~ ^(github|gitlab|ado)$ ]] || json_err "PR_HOST must be github, gitlab, or ado"

REPO_OWNER="${REPO_OWNER:-}" ; [[ -z "$REPO_OWNER" ]] && json_err "REPO_OWNER not set"
REPO_NAME="${REPO_NAME:-}"   ; [[ -z "$REPO_NAME"  ]] && json_err "REPO_NAME not set"

if [[ -z "$TITLE" ]]; then
  if [[ -n "$WORK_ITEM_ID" && -n "${WORK_ITEM_TITLE:-}" ]]; then
    TITLE="[${WORK_ITEM_ID}] ${WORK_ITEM_TITLE}"
  else
    if git rev-parse --verify "origin/${BASE}" &>/dev/null; then
      TITLE=$(git log --oneline "origin/${BASE}..HEAD" | tail -1 | cut -d' ' -f2-)
    fi
    [[ -z "$TITLE" ]] && TITLE=$(git rev-parse --abbrev-ref HEAD)
  fi
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_SEARCH_PATHS=(
  "${PR_TEMPLATE_PATH:-}"
  ".github/pull_request_template.md"
  ".gitlab/merge_request_templates/Default.md"
  "docs/pull_request_template.md"
  "pull_request_template.md"
)

BODY=""
for tpl in "${TEMPLATE_SEARCH_PATHS[@]}"; do
  [[ -z "$tpl" ]] && continue
  if [[ -f "$tpl" ]]; then
    BODY=$(cat "$tpl")
    break
  fi
done

if [[ -z "$BODY" ]]; then
  BODY="## Summary

<!-- Describe the change and why -->

## Changes

$(git rev-parse --verify "origin/${BASE}" &>/dev/null && git log --oneline "origin/${BASE}..HEAD" 2>/dev/null | sed 's/^/- /' || echo '- see commits')

## Testing

- [ ] Unit tests pass
- [ ] Manual verification done
"
  if [[ -n "$WORK_ITEM_ID" ]]; then
    BODY+="
## Linked work item

Closes #${WORK_ITEM_ID}
"
  fi
fi

export PR_TITLE="$TITLE"
export PR_BODY="$BODY"
export PR_BASE="$BASE"
export PR_DRAFT="$DRAFT"
export PR_WORK_ITEM_ID="${WORK_ITEM_ID}"

ADAPTER="${SCRIPT_DIR}/../adapters/${PR_HOST}/pr.sh"
[[ -f "$ADAPTER" ]] || json_err "adapter not found: adapters/${PR_HOST}/pr.sh"

exec bash "$ADAPTER"
```

---

### 3.40 `gf-pr/adapters/github/pr.sh`

```bash
#!/usr/bin/env bash
# GitHub PR adapter. Called by create-pr.sh after resolving title, body, base.
# Required env (set by create-pr.sh): GITHUB_TOKEN PR_TITLE PR_BODY PR_BASE PR_DRAFT
#                                      REPO_OWNER REPO_NAME PR_WORK_ITEM_ID

set -euo pipefail

json_err() { printf '{"error":"%s"}\n' "$1"; exit 1; }

TOKEN="${GITHUB_TOKEN:-}" ; [[ -z "$TOKEN" ]] && json_err "GITHUB_TOKEN not set"

BRANCH=$(git rev-parse --abbrev-ref HEAD)
API="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}"
AUTH_HEADER="Authorization: Bearer ${TOKEN}"

# Deduplication: check for existing open PR
EXISTING=$(curl -sf -H "$AUTH_HEADER" \
  "${API}/pulls?state=open&head=${REPO_OWNER}:${BRANCH}&base=${PR_BASE}" \
  2>/dev/null || echo "[]")

EXISTING_COUNT=$(printf '%s' "$EXISTING" | jq 'length' 2>/dev/null || echo 0)

if [[ "$EXISTING_COUNT" -gt 0 ]]; then
  EXISTING_PR=$(printf '%s' "$EXISTING" | jq -c --arg wi "${PR_WORK_ITEM_ID:-}" \
    '.[0] | {"id":.number,"url":.html_url,"title":.title,"linked_work_item_id":$wi,"deduped":true}')
  echo "$EXISTING_PR"
  exit 0
fi

DRAFT_BOOL=$( [[ "$PR_DRAFT" == true ]] && echo "true" || echo "false" )

REQUEST=$(jq -n \
  --arg title "$PR_TITLE" \
  --arg body "$PR_BODY" \
  --arg head "$BRANCH" \
  --arg base "$PR_BASE" \
  --argjson draft "$DRAFT_BOOL" \
  '{"title":$title,"body":$body,"head":$head,"base":$base,"draft":$draft}')

RESPONSE=$(curl -sf -X POST \
  -H "$AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -d "$REQUEST" \
  "${API}/pulls" 2>/dev/null) || json_err "GitHub API request failed"

printf '%s' "$RESPONSE" | jq -c \
  --arg wi "${PR_WORK_ITEM_ID:-}" \
  '{"id":.number,"url":.html_url,"title":.title,"linked_work_item_id":$wi,"deduped":false}'
```

---

### 3.41 `gf-pr/adapters/ado/pr.sh`

```bash
#!/usr/bin/env bash
# NOT TESTED — requires live credentials.
# Azure DevOps PR adapter.
# Required env: ADO_TOKEN REPO_OWNER(org) REPO_NAME ADO_PROJECT
#               PR_TITLE PR_BODY PR_BASE PR_DRAFT PR_WORK_ITEM_ID

set -euo pipefail

json_err() { printf '{"error":"%s"}\n' "$1"; exit 1; }

TOKEN="${ADO_TOKEN:-}"    ; [[ -z "$TOKEN"   ]] && json_err "ADO_TOKEN not set"
PROJECT="${ADO_PROJECT:-}"; [[ -z "$PROJECT" ]] && json_err "ADO_PROJECT not set"
ORG="${REPO_OWNER:-}"     ; [[ -z "$ORG"     ]] && json_err "REPO_OWNER (org) not set"
REPO="${REPO_NAME:-}"     ; [[ -z "$REPO"    ]] && json_err "REPO_NAME not set"

BRANCH=$(git rev-parse --abbrev-ref HEAD)
B64_TOKEN=$(echo -n ":${TOKEN}" | base64)
API="https://dev.azure.com/${ORG}/${PROJECT}/_apis/git/repositories/${REPO}/pullrequests"
AUTH_HEADER="Authorization: Basic ${B64_TOKEN}"
API_VERSION="api-version=7.1-preview.1"

EXISTING=$(curl -sf -H "$AUTH_HEADER" \
  "${API}?sourceRefName=refs/heads/${BRANCH}&targetRefName=refs/heads/${PR_BASE}&status=active&${API_VERSION}" \
  2>/dev/null || echo '{"value":[]}')

EXISTING_COUNT=$(printf '%s' "$EXISTING" | jq '.value | length' 2>/dev/null || echo 0)

if [[ "$EXISTING_COUNT" -gt 0 ]]; then
  printf '%s' "$EXISTING" | jq -c \
    --arg org "$ORG" --arg proj "$PROJECT" --arg repo "$REPO" \
    --argjson wi "${PR_WORK_ITEM_ID:-null}" \
    '.value[0] | {"id":.pullRequestId,"url":("https://dev.azure.com/"+$org+"/"+$proj+"/_git/"+$repo+"/pullrequest/"+(.pullRequestId|tostring)),"title":.title,"linked_work_item_id":$wi,"deduped":true}'
  exit 0
fi

DRAFT_BOOL=$( [[ "$PR_DRAFT" == true ]] && echo "true" || echo "false" )
WI_REFS="[]"
[[ -n "${PR_WORK_ITEM_ID:-}" ]] && WI_REFS="[{\"id\":${PR_WORK_ITEM_ID}}]"

REQUEST=$(jq -n \
  --arg source "refs/heads/$BRANCH" \
  --arg target "refs/heads/$PR_BASE" \
  --arg title "$PR_TITLE" \
  --arg desc "$PR_BODY" \
  --argjson draft "$DRAFT_BOOL" \
  --argjson wi_refs "$WI_REFS" \
  '{"sourceRefName":$source,"targetRefName":$target,"title":$title,"description":$desc,"isDraft":$draft,"workItemRefs":$wi_refs}')

RESPONSE=$(curl -sf -X POST \
  -H "$AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -d "$REQUEST" \
  "${API}?${API_VERSION}" 2>/dev/null) || json_err "Azure DevOps API request failed"

printf '%s' "$RESPONSE" | jq -c \
  --arg org "$ORG" --arg proj "$PROJECT" --arg repo "$REPO" \
  --argjson wi "${PR_WORK_ITEM_ID:-null}" \
  '{"id":.pullRequestId,"url":("https://dev.azure.com/"+$org+"/"+$proj+"/_git/"+$repo+"/pullrequest/"+(.pullRequestId|tostring)),"title":.title,"linked_work_item_id":$wi,"deduped":false}'
```

---

### 3.42 `gf-pr/adapters/gitlab/pr.sh`

```bash
#!/usr/bin/env bash
# NOT TESTED — requires live credentials.
# GitLab MR adapter.
# Required env: GITLAB_TOKEN REPO_OWNER(namespace) REPO_NAME
#               PR_TITLE PR_BODY PR_BASE PR_DRAFT PR_WORK_ITEM_ID
# Optional env: GITLAB_HOST (default: gitlab.com)

set -euo pipefail

json_err() { printf '{"error":"%s"}\n' "$1"; exit 1; }

TOKEN="${GITLAB_TOKEN:-}" ; [[ -z "$TOKEN" ]] && json_err "GITLAB_TOKEN not set"
HOST="${GITLAB_HOST:-gitlab.com}"

BRANCH=$(git rev-parse --abbrev-ref HEAD)
ENCODED_PATH="${REPO_OWNER}%2F${REPO_NAME}"
API="https://${HOST}/api/v4/projects/${ENCODED_PATH}"
AUTH_HEADER="PRIVATE-TOKEN: ${TOKEN}"

EXISTING=$(curl -sf -H "$AUTH_HEADER" \
  "${API}/merge_requests?state=opened&source_branch=${BRANCH}&target_branch=${PR_BASE}" \
  2>/dev/null || echo "[]")

EXISTING_COUNT=$(printf '%s' "$EXISTING" | jq 'length' 2>/dev/null || echo 0)

if [[ "$EXISTING_COUNT" -gt 0 ]]; then
  printf '%s' "$EXISTING" | jq -c \
    --argjson wi "${PR_WORK_ITEM_ID:-null}" \
    '.[0] | {"id":.iid,"url":.web_url,"title":.title,"linked_work_item_id":$wi,"deduped":true}'
  exit 0
fi

WIP_PREFIX=$( [[ "$PR_DRAFT" == true ]] && echo "Draft: " || echo "" )

REQUEST=$(jq -n \
  --arg source "$BRANCH" \
  --arg target "$PR_BASE" \
  --arg title "${WIP_PREFIX}${PR_TITLE}" \
  --arg desc "$PR_BODY" \
  '{"source_branch":$source,"target_branch":$target,"title":$title,"description":$desc,"remove_source_branch":true}')

RESPONSE=$(curl -sf -X POST \
  -H "$AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -d "$REQUEST" \
  "${API}/merge_requests" 2>/dev/null) || json_err "GitLab API request failed"

printf '%s' "$RESPONSE" | jq -c \
  --argjson wi "${PR_WORK_ITEM_ID:-null}" \
  '{"id":.iid,"url":.web_url,"title":.title,"linked_work_item_id":$wi,"deduped":false}'
```

---

### 3.43 `gf-ship/SKILL.md`

```markdown
---
name: gf-ship
description: >-
  EXPLICIT-INVOCATION ONLY. Run the full git workflow end-to-end: create branch,
  commit, push, open PR. Use only when the user explicitly asks to ship a
  complete feature branch from scratch in one flow. For any partial operation
  (just branch, just commit, just push, just PR) use the individual gf-* skills
  instead.
argument-hint: "work-item-id commit-subject [optional flags]"
---

# gf-ship

EXPLICIT-INVOCATION ONLY.

Coordinate `gf-branch` → `gf-commit` → `gf-push` → `gf-pr` as sequential phases.
Stops on the first failure.

## When this skill fits

Use it for requests like:
- "ship this feature end-to-end"
- "run the full branch-to-PR workflow"

Do **not** use it for:
- partial git operations (use individual skills)
- merging, rebasing, or history rewriting
- pushing to or creating a PR from `main`

## Workflow

### Option A — Script-driven

```bash
bash .claude/skills/gf-ship/scripts/ship.sh \
  --work-item-id <id> \
  --title "<work-item-title>" \
  --commit-type <type> \
  --commit-subject "<subject>" \
  --commit-scope "<scope>" \
  --base main \
  --files <space-separated-paths>
```

### Phase summary

```
| Phase | Skill     | Status  | Notes                              |
|-------|-----------|---------|-------------------------------------|
| 1     | gf-branch | SUCCESS | task/1234-fix-login-timeout         |
| 2     | gf-commit | SUCCESS | fix(auth): correct token refresh    |
| 3     | gf-push   | SUCCESS | origin/task/1234-fix-login-timeout  |
| 4     | gf-pr     | SUCCESS | https://github.com/org/repo/pull/88 |

PR: https://github.com/org/repo/pull/88
```

## Hard rules

- All hard rules from individual `gf-*` skills apply.
- Never push to or create a PR from `main`.
- Return the PR URL exactly as printed by `gh`.
- Never read the bash scripts before executing them.
```

---

### 3.44 `gf-ship/scripts/ship.sh`

```bash
#!/usr/bin/env bash
# gf-ship — Runs branch → commit → push → pr in order.
# Usage:
#   ship.sh --work-item-id 11111 --title "filter order number" \
#     --commit-type fix --commit-scope orders --commit-subject "scope date filter" \
#     [--base main] [--pr-title "..."] [--draft] [--files "path1 path2"]
# Required env: PR_HOST REPO_OWNER REPO_NAME GITHUB_TOKEN|GITLAB_TOKEN|ADO_TOKEN
# Optional env: CORE_BRANCH WORK_ITEM_TITLE PR_TEMPLATE_PATH

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="${SCRIPT_DIR}/../../"

RUN_ID="gfs-$(date +%Y%m%d-%H%M%S)"
PHASES_JSON="[]"

phase_record() {
  local phase="$1" status="$2" detail="$3"
  printf "%-8s %-8s %s\n" "$phase" "$status" "$detail" >&2
  PHASES_JSON=$(printf '%s' "$PHASES_JSON" | jq -c \
    --arg phase "$phase" --arg status "$status" --arg detail "$detail" \
    '. + [{"phase":$phase,"status":$status,"detail":$detail}]')
}

fatal() {
  local phase="$1" detail="$2"
  phase_record "$phase" "FAILED" "$detail"
  printf '{"run_id":"%s","verdict":"failure","phases":%s}\n' "$RUN_ID" "$PHASES_JSON"
  exit 1
}

WORK_ITEM_ID=""; WORK_ITEM_TITLE=""; BASE="${CORE_BRANCH:-main}"
COMMIT_TYPE=""; COMMIT_SCOPE=""; COMMIT_SUBJECT=""
PR_TITLE_ARG=""; DRAFT_FLAG=""; FILES_ARG=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --work-item-id)    WORK_ITEM_ID="$2";    shift 2 ;;
    --title)           WORK_ITEM_TITLE="$2"; shift 2 ;;
    --commit-type)     COMMIT_TYPE="$2";     shift 2 ;;
    --commit-scope)    COMMIT_SCOPE="$2";    shift 2 ;;
    --commit-subject)  COMMIT_SUBJECT="$2";  shift 2 ;;
    --base)            BASE="$2";            shift 2 ;;
    --pr-title)        PR_TITLE_ARG="$2";    shift 2 ;;
    --draft)           DRAFT_FLAG="--draft"; shift   ;;
    --files)           FILES_ARG="$2";       shift 2 ;;
    *) printf '{"error":"unknown argument: %s"}\n' "$1"; exit 1 ;;
  esac
done

[[ -z "$WORK_ITEM_ID"   ]] && { printf '{"error":"missing --work-item-id"}\n';   exit 1; }
[[ -z "$COMMIT_TYPE"    ]] && { printf '{"error":"missing --commit-type"}\n';    exit 1; }
[[ -z "$COMMIT_SUBJECT" ]] && { printf '{"error":"missing --commit-subject"}\n'; exit 1; }

export WORK_ITEM_TITLE
export CORE_BRANCH="$BASE"

printf "\n%-8s %-8s %s\n" "Phase" "Status" "Detail" >&2
printf "%s\n" "----------------------------------------" >&2

# Phase 1: branch
BRANCH_RESULT=$(bash "${SKILLS_DIR}/gf-branch/scripts/create-branch.sh" \
  --work-item-id "$WORK_ITEM_ID" \
  --title "${WORK_ITEM_TITLE:-}" \
  --base "$BASE" 2>/dev/null) || fatal "BRANCH" "$BRANCH_RESULT"

BRANCH_NAME=$(printf '%s' "$BRANCH_RESULT" | jq -r '.branch // "unknown"' 2>/dev/null || echo "unknown")
phase_record "BRANCH" "SUCCESS" "$BRANCH_NAME"

# Phase 2: commit
COMMIT_ARGS=(--type "$COMMIT_TYPE" --subject "$COMMIT_SUBJECT")
[[ -n "$COMMIT_SCOPE" ]] && COMMIT_ARGS+=(--scope "$COMMIT_SCOPE")
[[ -n "$FILES_ARG"    ]] && COMMIT_ARGS+=(--files "$FILES_ARG")

COMMIT_RESULT=$(bash "${SKILLS_DIR}/gf-commit/scripts/create-commit.sh" "${COMMIT_ARGS[@]}" 2>/dev/null) \
  || fatal "COMMIT" "$COMMIT_RESULT"

COMMIT_MSG=$(printf '%s' "$COMMIT_RESULT" | jq -r '.message // "committed"' 2>/dev/null || echo "committed")
phase_record "COMMIT" "SUCCESS" "$COMMIT_MSG"

# Phase 3: push
PUSH_RESULT=$(bash "${SKILLS_DIR}/gf-push/scripts/push-branch.sh" 2>/dev/null) \
  || fatal "PUSH" "$PUSH_RESULT"

PUSHED_SHA=$(printf '%s' "$PUSH_RESULT" | jq -r '(.remote + "/" + .branch) // "pushed"' 2>/dev/null || echo "pushed")
phase_record "PUSH" "SUCCESS" "$PUSHED_SHA"

# Phase 4: pr
PR_ARGS=(--work-item-id "$WORK_ITEM_ID" --base "$BASE")
[[ -n "$PR_TITLE_ARG" ]] && PR_ARGS+=(--title "$PR_TITLE_ARG")
[[ -n "$DRAFT_FLAG"   ]] && PR_ARGS+=("$DRAFT_FLAG")

PR_RESULT=$(bash "${SKILLS_DIR}/gf-pr/scripts/create-pr.sh" "${PR_ARGS[@]}" 2>/dev/null) \
  || fatal "PR" "$PR_RESULT"

PR_URL=$(printf '%s' "$PR_RESULT" | jq -r '.url // "unknown"' 2>/dev/null || echo "unknown")
phase_record "PR" "SUCCESS" "$PR_URL"

printf "%s\n\n" "----------------------------------------" >&2

printf '{"run_id":"%s","verdict":"success","pr_url":"%s","branch_name":"%s","phases":%s}\n' \
  "$RUN_ID" "$PR_URL" "$BRANCH_NAME" "$PHASES_JSON"
```

---

## 4. Required Dependencies (Prerequisites)

These must be present in the caller's environment before any skill can run:

| Dependency | Install command | Used by |
|---|---|---|
| `jq` | `apt install jq` / `brew install jq` | All tracker scripts |
| `gh` CLI | `brew install gh` / see GitHub CLI docs | GitHub tracker adapter, gf-pr |
| `curl` | Pre-installed on most systems | Fake tracker adapter |
| `git` | Pre-installed on most systems | All gf-* skills |
| `base64` | Pre-installed | gf-pr ADO adapter |

---

## 5. Environment Variables Required

`.env` is sourced automatically by `_common.sh`. Minimum required vars per use case:

| Variable | Required by | Value |
|---|---|---|
| `ISSUE_TRACKER` | All tracker scripts | `fake` \| `github` \| `jira` \| `ado` \| `linear` |
| `FAKE_TRACKER_URL` | Fake adapter | `http://localhost:3000` or ngrok HTTPS URL |
| `GITHUB_TOKEN` or `GH_TOKEN` | GitHub tracker adapter, gf-pr | GitHub PAT |
| `REPO_OWNER` | GitHub adapter, gf-pr | e.g. `DimaSmaha` |
| `REPO_NAME` | GitHub adapter, gf-pr | e.g. `playwright-agentic-qa-automation-workflows` |
| `ADO_TOKEN` | ADO adapter | ADO Personal Access Token |
| `ADO_PROJECT` | ADO PR adapter | ADO project name |
| `JIRA_BASE_URL` | Jira adapter | e.g. `https://org.atlassian.net` |
| `JIRA_TOKEN` | Jira adapter | Jira API token |
| `LINEAR_TOKEN` | Linear adapter | Linear API key |
| `GITLAB_TOKEN` | GitLab PR adapter | GitLab PAT |
| `GITLAB_HOST` | GitLab PR adapter (optional) | Default: `gitlab.com` |
| `PR_HOST` | gf-pr, gf-ship | `github` \| `gitlab` \| `ado` |
| `CORE_BRANCH` | gf-branch, gf-ship | `master` or `main` |

---

## 6. Verification

### Step 1 — Fake tracker smoke test

Start the fake tracker, then:

```bash
export ISSUE_TRACKER=fake
export FAKE_TRACKER_URL=http://localhost:3000

# Preflight
bash .claude/skills/operations-with-issue-tracker/scripts/preflight.sh
# Expected: {"ok":true,"tracker":"fake","base_url":"http://localhost:3000"}

# Create a bug
bash .claude/skills/operations-with-issue-tracker/scripts/create.sh \
  --type "Bug" \
  --title "Test bug" \
  --tag "test"
# Expected: {"id":"...","url":"http://localhost:3000/bugs/create","deduped":false}

# Get a task (id=1 must exist or fake tracker returns 404)
bash .claude/skills/operations-with-issue-tracker/scripts/get.sh --id 1 --type Task
```

### Step 2 — GitHub tracker smoke test

```bash
export ISSUE_TRACKER=github
export GITHUB_TOKEN=<pat>
export REPO_OWNER=<owner>
export REPO_NAME=<repo>

bash .claude/skills/operations-with-issue-tracker/scripts/preflight.sh
bash .claude/skills/operations-with-issue-tracker/scripts/create.sh \
  --type "Bug" --title "Smoke test" --dedupe-by title
```

### Step 3 — gf-ship dry-run (no actual changes needed)

```bash
# In a repo with staged changes on a feature branch:
export PR_HOST=github
bash .claude/skills/gf-ship/scripts/ship.sh \
  --work-item-id test-123 \
  --title "test ship" \
  --commit-type test \
  --commit-subject "verify gf-ship works" \
  --base master
```

Expected: phase table printed to stderr; JSON with `verdict: "success"` and `pr_url` to stdout.

### Step 4 — Verify adapter schema compliance

Each adapter's output must match Section 1 schemas:
- `create.sh` returns `{"id":..., "url":"...", "deduped":false}`
- `get.sh` returns object with `id`, `type`, `title`, `description`, `url`, `steps_xml`, `image_urls`
- `preflight.sh` returns `{"ok":true, "tracker":"...", ...}`

---

## 7. Key Design Decisions (Non-Obvious)

- **Facade + adapter pattern in `operations-with-issue-tracker`:** The public scripts (`get.sh`, `create.sh`, etc.) parse args, validate, and call `_dispatch.sh`. The dispatch function resolves the tracker type from `ISSUE_TRACKER` and routes to `adapters/<tracker>/<verb>.sh`. This isolates tracker-specific logic completely from caller code, and allows swapping trackers with a single env var change.

- **`_common.sh` is sourced by both the public scripts AND adapters:** The top-level `_common.sh` provides `emit_error`, `require_auth`, `require_preflight`, `json_escape`, `slug`, etc. The adapter-level `_common.sh` files (e.g. `adapters/github/_common.sh`) source the parent and add tracker-specific helpers (`gh_repo_args`, `gh_type_to_label`). This avoids duplication while keeping adapter helpers scoped.

- **`_not_implemented.sh` as graceful no-op:** For the fake tracker, unsupported verbs (update, link, etc.) return `{"ok":true,"skipped":true}` rather than failing. This allows Pipeline A/B to call `update.sh` or `link.sh` without branching logic based on tracker type — the adapter absorbs the no-op silently.

- **`require_preflight` enforces session ordering:** Every script except `preflight.sh` itself calls `require_preflight`, which checks the cache file for the current tracker type. This prevents a misconfigured tracker from silently creating items in the wrong system. Running `preflight.sh` with `--force` refreshes the cache.

- **`dedupe-by` strategies on `create.sh`:** `title` searches by title match; `tag` searches by label + title; `error-hash` computes `sha1(title:type)` and attaches it as a label, enabling deduplication across exact-title variants. The hash approach is used by `ft-bug-reporter` so that rerunning on the same failure never creates duplicate bugs.

- **`gf-ship` owns the run_id but is not a tracker:** The `gfs-<timestamp>` run_id in `ship.sh` is used only for the JSON output phases array — it is not written to `.workflow-artifacts/`. The orchestrators (`ft-orchestrator`, `gt-us-to-spec`) own the canonical run_ids that go on disk.

- **`gf-pr` deduplicates before creating:** The GitHub adapter checks `GET /repos/{owner}/{repo}/pulls?state=open&head={branch}` before POSTing a new PR. This makes `gf-pr` idempotent — calling it twice on the same branch returns the existing PR with `deduped: true`, never a duplicate.

- **`create-branch.sh` truncates branch names at 60 characters:** Git branch names have no hard limit, but many CI/CD systems have URL or display length constraints. The slug is derived from `work_item_id` + title, then capped at 60.

- **PR body resolution order in `create-pr.sh`:** The script looks for a PR template in this priority: `$PR_TEMPLATE_PATH` → `.github/pull_request_template.md` → `.gitlab/merge_request_templates/Default.md` → `docs/pull_request_template.md` → `pull_request_template.md` → minimal fallback. This makes it compatible with both GitHub and GitLab repo layouts without configuration.

- **ADO and GitLab adapters are untested stubs:** Both have been implemented but carry `# NOT TESTED` warnings. They were written to be structurally consistent with the GitHub adapter so they can be activated with real credentials when needed. Until tested, treat them as reference implementations only.
