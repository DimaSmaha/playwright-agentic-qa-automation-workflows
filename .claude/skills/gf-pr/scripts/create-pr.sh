#!/usr/bin/env bash
# gf-pr — create-pr.sh
# Opens a PR (or returns the existing one — deduplication built-in).
# Delegates to the correct host adapter via PR_HOST env var.
# Outputs JSON only. Exit 0 = success, non-zero = failure.
#
# Usage:
#   create-pr.sh [--title "..."] [--work-item-id 11111] [--base main] [--draft]
#
# Required env:
#   PR_HOST         github | gitlab | ado
#   REPO_OWNER      org or user (GitHub/GitLab) or org (ADO)
#   REPO_NAME       repository name
#   GITHUB_TOKEN / GITLAB_TOKEN / ADO_TOKEN
#
# Optional env:
#   WORK_ITEM_TITLE  used to auto-build title if --title not given
#   PR_TEMPLATE_PATH path to pull_request_template.md (auto-detected if absent)

set -euo pipefail

# Load .env from repo root if GITHUB_TOKEN is not already in the environment
[ -z "${GITHUB_TOKEN:-}" ] && [ -f .env ] && { set -a; source .env; set +a; }

# ── helpers ───────────────────────────────────────────────────────────────────
json_err() { printf '{"error":"%s"}\n' "$1"; exit 1; }

# ── args ──────────────────────────────────────────────────────────────────────
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

# ── validate env ──────────────────────────────────────────────────────────────
PR_HOST="${PR_HOST:-}"
[[ -z "$PR_HOST" ]] && json_err "PR_HOST not set (github|gitlab|ado)"
[[ "$PR_HOST" =~ ^(github|gitlab|ado)$ ]] || json_err "PR_HOST must be github, gitlab, or ado"

REPO_OWNER="${REPO_OWNER:-}" ; [[ -z "$REPO_OWNER" ]] && json_err "REPO_OWNER not set"
REPO_NAME="${REPO_NAME:-}"   ; [[ -z "$REPO_NAME"  ]] && json_err "REPO_NAME not set"

# ── resolve title ─────────────────────────────────────────────────────────────
if [[ -z "$TITLE" ]]; then
  if [[ -n "$WORK_ITEM_ID" && -n "${WORK_ITEM_TITLE:-}" ]]; then
    TITLE="[${WORK_ITEM_ID}] ${WORK_ITEM_TITLE}"
  else
    # Fall back to first commit subject on branch vs base
    if git rev-parse --verify "origin/${BASE}" &>/dev/null; then
      TITLE=$(git log --oneline "origin/${BASE}..HEAD" | tail -1 | cut -d' ' -f2-)
    fi
    [[ -z "$TITLE" ]] && TITLE=$(git rev-parse --abbrev-ref HEAD)
  fi
fi

# ── resolve PR body ───────────────────────────────────────────────────────────
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
  # Minimal fallback template
  BRANCH=$(git rev-parse --abbrev-ref HEAD)
  BODY="## Summary

<!-- Describe the change and why -->

## Changes

$(git rev-parse --verify "origin/${BASE}" &>/dev/null && git log --oneline "origin/${BASE}..HEAD" 2>/dev/null | sed 's/^/- /' || echo '- see commits')

## Testing

- [ ] Unit tests pass
- [ ] Manual verification done
"
  if [[ -n "$WORK_ITEM_ID" ]]; then
    BODY="${BODY}
## Linked work item

Closes #${WORK_ITEM_ID}
"
  fi
fi

# ── export resolved values for adapter ───────────────────────────────────────
export PR_TITLE="$TITLE"
export PR_BODY="$BODY"
export PR_BASE="$BASE"
export PR_DRAFT="$DRAFT"
export PR_WORK_ITEM_ID="${WORK_ITEM_ID}"

# ── delegate to adapter ───────────────────────────────────────────────────────
ADAPTER="${SCRIPT_DIR}/../adapters/${PR_HOST}/pr.sh"
[[ -f "$ADAPTER" ]] || json_err "adapter not found: adapters/${PR_HOST}/pr.sh"

exec bash "$ADAPTER"