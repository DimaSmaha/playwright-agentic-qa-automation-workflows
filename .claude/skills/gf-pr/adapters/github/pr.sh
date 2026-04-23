#!/usr/bin/env bash
# adapters/github/pr.sh — GitHub PR adapter for gf-pr
# Called by create-pr.sh after resolving title, body, base.
# Uses GitHub REST API via curl + GITHUB_TOKEN.
#
# Required env (set by create-pr.sh + caller):
#   GITHUB_TOKEN  PR_TITLE  PR_BODY  PR_BASE  PR_DRAFT
#   REPO_OWNER    REPO_NAME  PR_WORK_ITEM_ID

set -euo pipefail

json_err() { printf '{"error":"%s"}\n' "$1"; exit 1; }

TOKEN="${GITHUB_TOKEN:-}" ; [[ -z "$TOKEN" ]] && json_err "GITHUB_TOKEN not set"

BRANCH=$(git rev-parse --abbrev-ref HEAD)
API="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}"
AUTH_HEADER="Authorization: Bearer ${TOKEN}"

# ── deduplication: check for existing open PR on this branch ──────────────────
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

# ── build request body ────────────────────────────────────────────────────────
DRAFT_BOOL=$( [[ "$PR_DRAFT" == true ]] && echo "true" || echo "false" )

REQUEST=$(jq -n \
  --arg title "$PR_TITLE" \
  --arg body "$PR_BODY" \
  --arg head "$BRANCH" \
  --arg base "$PR_BASE" \
  --argjson draft "$DRAFT_BOOL" \
  '{"title":$title,"body":$body,"head":$head,"base":$base,"draft":$draft}')

# ── create PR ─────────────────────────────────────────────────────────────────
RESPONSE=$(curl -sf -X POST \
  -H "$AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -d "$REQUEST" \
  "${API}/pulls" 2>/dev/null) || json_err "GitHub API request failed"

printf '%s' "$RESPONSE" | jq -c \
  --arg wi "${PR_WORK_ITEM_ID:-}" \
  '{"id":.number,"url":.html_url,"title":.title,"linked_work_item_id":$wi,"deduped":false}'