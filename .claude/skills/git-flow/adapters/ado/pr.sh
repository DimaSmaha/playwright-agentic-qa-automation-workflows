#!/usr/bin/env bash
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

EXISTING_COUNT=$(echo "$EXISTING" | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('value',[])))" 2>/dev/null || echo 0)

if [[ "$EXISTING_COUNT" -gt 0 ]]; then
  echo "$EXISTING" | python3 -c "
import sys, json, os
pr = json.load(sys.stdin)['value'][0]
wi = os.environ.get('PR_WORK_ITEM_ID', '')
org, proj, repo = os.environ['ORG'], os.environ['PROJECT'], os.environ['REPO']
url = f'https://dev.azure.com/{org}/{proj}/_git/{repo}/pullrequest/{pr[\"pullRequestId\"]}'
print(json.dumps({
  'id':                 pr['pullRequestId'],
  'url':                url,
  'title':              pr['title'],
  'linked_work_item_id': int(wi) if wi else None,
  'deduped':            True
}))
" ORG="$ORG" PROJECT="$PROJECT" REPO="$REPO"
  exit 0
fi

# ── create PR ─────────────────────────────────────────────────────────────────
DRAFT_BOOL=$( [[ "$PR_DRAFT" == true ]] && echo "true" || echo "false" )

WI_REFS="[]"
if [[ -n "${PR_WORK_ITEM_ID:-}" ]]; then
  WI_REFS="[{\"id\":${PR_WORK_ITEM_ID}}]"
fi

REQUEST=$(python3 -c "
import json, os
print(json.dumps({
  'sourceRefName': f'refs/heads/{os.environ[\"BRANCH\"]}',
  'targetRefName': f'refs/heads/{os.environ[\"PR_BASE\"]}',
  'title':         os.environ['PR_TITLE'],
  'description':   os.environ['PR_BODY'],
  'isDraft':       os.environ['PR_DRAFT'] == 'true',
  'workItemRefs':  json.loads(os.environ['WI_REFS']),
}))
" BRANCH="$BRANCH" WI_REFS="$WI_REFS")

RESPONSE=$(curl -sf -X POST \
  -H "$AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -d "$REQUEST" \
  "${API}?${API_VERSION}" 2>/dev/null) || json_err "Azure DevOps API request failed"

python3 -c "
import json, sys, os
pr = json.loads('''$RESPONSE''')
wi = os.environ.get('PR_WORK_ITEM_ID', '')
org, proj, repo = os.environ['ORG'], os.environ['PROJECT'], os.environ['REPO']
url = f'https://dev.azure.com/{org}/{proj}/_git/{repo}/pullrequest/{pr[\"pullRequestId\"]}'
print(json.dumps({
  'id':                 pr['pullRequestId'],
  'url':                url,
  'title':              pr['title'],
  'linked_work_item_id': int(wi) if wi else None,
  'deduped':            False
}))
" ORG="$ORG" PROJECT="$PROJECT" REPO="$REPO"