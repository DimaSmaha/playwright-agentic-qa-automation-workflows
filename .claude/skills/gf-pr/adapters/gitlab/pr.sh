#!/usr/bin/env bash
# NOT TESTED — requires live credentials; no automated test coverage.
# adapters/gitlab/pr.sh — GitLab Merge Request adapter for gf-pr
# Uses GitLab REST API v4 via curl + GITLAB_TOKEN.
#
# Required env:
#   GITLAB_TOKEN  REPO_OWNER (namespace)  REPO_NAME
#   PR_TITLE  PR_BODY  PR_BASE  PR_DRAFT  PR_WORK_ITEM_ID
#
# Optional env:
#   GITLAB_HOST  (default: gitlab.com)

set -euo pipefail

json_err() { printf '{"error":"%s"}\n' "$1"; exit 1; }

TOKEN="${GITLAB_TOKEN:-}" ; [[ -z "$TOKEN" ]] && json_err "GITLAB_TOKEN not set"
HOST="${GITLAB_HOST:-gitlab.com}"

BRANCH=$(git rev-parse --abbrev-ref HEAD)
ENCODED_PATH="${REPO_OWNER}%2F${REPO_NAME}"
API="https://${HOST}/api/v4/projects/${ENCODED_PATH}"
AUTH_HEADER="PRIVATE-TOKEN: ${TOKEN}"

# ── deduplication ─────────────────────────────────────────────────────────────
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

# ── create MR ─────────────────────────────────────────────────────────────────
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