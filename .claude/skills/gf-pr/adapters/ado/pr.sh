#!/usr/bin/env bash
# NOT TESTED — requires live credentials; no automated test coverage.
# adapters/ado/pr.sh — Azure DevOps Pull Request adapter for gf-pr
# Uses Azure DevOps REST API via curl + ADO_TOKEN (Personal Access Token).
#
# Required env:
#   ADO_TOKEN     Personal Access Token (needs Code: Read+Write)
#   REPO_OWNER    ADO organization name
#   REPO_NAME     repository name
#   ADO_PROJECT   ADO project name (set this in your env)
#   PR_TITLE  PR_BODY  PR_BASE  PR_DRAFT  PR_WORK_ITEM_ID

set -euo pipefail

json_err() { printf '{"error":"%s"}\n' "$1"; exit 1; }

TOKEN="${ADO_TOKEN:-}"    ; [[ -z "$TOKEN"      ]] && json_err "ADO_TOKEN not set"
PROJECT="${ADO_PROJECT:-}"; [[ -z "$PROJECT"    ]] && json_err "ADO_PROJECT not set"
ORG="${REPO_OWNER:-}"    ; [[ -z "$ORG"        ]] && json_err "REPO_OWNER (org) not set"
REPO="${REPO_NAME:-}"    ; [[ -z "$REPO"       ]] && json_err "REPO_NAME not set"

BRANCH=$(git rev-parse --abbrev-ref HEAD)
B64_TOKEN=$(echo -n ":${TOKEN}" | base64)
API="https://dev.azure.com/${ORG}/${PROJECT}/_apis/git/repositories/${REPO}/pullrequests"
AUTH_HEADER="Authorization: Basic ${B64_TOKEN}"
API_VERSION="api-version=7.1-preview.1"

# ── deduplication ─────────────────────────────────────────────────────────────
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

# ── create PR ─────────────────────────────────────────────────────────────────
DRAFT_BOOL=$( [[ "$PR_DRAFT" == true ]] && echo "true" || echo "false" )

WI_REFS="[]"
if [[ -n "${PR_WORK_ITEM_ID:-}" ]]; then
  WI_REFS="[{\"id\":${PR_WORK_ITEM_ID}}]"
fi

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