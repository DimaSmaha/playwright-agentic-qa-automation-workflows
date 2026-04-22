#!/usr/bin/env bash
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
ENCODED_PATH=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${REPO_OWNER}/${REPO_NAME}', safe=''))")
API="https://${HOST}/api/v4/projects/${ENCODED_PATH}"
AUTH_HEADER="PRIVATE-TOKEN: ${TOKEN}"

# ── deduplication ─────────────────────────────────────────────────────────────
EXISTING=$(curl -sf -H "$AUTH_HEADER" \
  "${API}/merge_requests?state=opened&source_branch=${BRANCH}&target_branch=${PR_BASE}" \
  2>/dev/null || echo "[]")

EXISTING_COUNT=$(echo "$EXISTING" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)

if [[ "$EXISTING_COUNT" -gt 0 ]]; then
  echo "$EXISTING" | python3 -c "
import sys, json, os
mr = json.load(sys.stdin)[0]
wi = os.environ.get('PR_WORK_ITEM_ID', '')
print(json.dumps({
  'id':                 mr['iid'],
  'url':                mr['web_url'],
  'title':              mr['title'],
  'linked_work_item_id': int(wi) if wi else None,
  'deduped':            True
}))
"
  exit 0
fi

# ── create MR ─────────────────────────────────────────────────────────────────
WIP_PREFIX=$( [[ "$PR_DRAFT" == true ]] && echo "Draft: " || echo "" )

REQUEST=$(python3 -c "
import json, os
print(json.dumps({
  'source_branch':        os.environ['BRANCH'],
  'target_branch':        os.environ['PR_BASE'],
  'title':                os.environ.get('WIP_PREFIX','') + os.environ['PR_TITLE'],
  'description':          os.environ['PR_BODY'],
  'remove_source_branch': True,
}))
" BRANCH="$BRANCH" WIP_PREFIX="$WIP_PREFIX")

RESPONSE=$(curl -sf -X POST \
  -H "$AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -d "$REQUEST" \
  "${API}/merge_requests" 2>/dev/null) || json_err "GitLab API request failed"

python3 -c "
import json, sys, os
mr = json.loads('''$RESPONSE''')
wi = os.environ.get('PR_WORK_ITEM_ID', '')
print(json.dumps({
  'id':                 mr['iid'],
  'url':                mr['web_url'],
  'title':              mr['title'],
  'linked_work_item_id': int(wi) if wi else None,
  'deduped':            False
}))
"