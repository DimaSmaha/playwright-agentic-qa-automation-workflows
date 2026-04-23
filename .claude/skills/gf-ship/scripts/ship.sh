#!/usr/bin/env bash
# gf-ship — scripts/ship.sh
# Runs branch → commit → push → pr in order. Stops on first failure.
# Prints a phase table to stderr and emits a final JSON artifact to stdout.
#
# Usage:
#   ship.sh \
#     --work-item-id 11111 \
#     --title "filter order number" \
#     --commit-type fix \
#     --commit-scope orders \
#     --commit-subject "scope date filter" \
#     [--base main] \
#     [--pr-title "..."] \
#     [--draft] \
#     [--files "path1 path2"]
#
# Required env:
#   PR_HOST  REPO_OWNER  REPO_NAME  GITHUB_TOKEN | GITLAB_TOKEN | ADO_TOKEN
# Optional env:
#   CORE_BRANCH  WORK_ITEM_TITLE  PR_TEMPLATE_PATH

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="${SCRIPT_DIR}/../../"

# ── helpers ───────────────────────────────────────────────────────────────────
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

# ── arg parsing ───────────────────────────────────────────────────────────────
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

[[ -z "$WORK_ITEM_ID"    ]] && { printf '{"error":"missing --work-item-id"}\n';   exit 1; }
[[ -z "$COMMIT_TYPE"     ]] && { printf '{"error":"missing --commit-type"}\n';    exit 1; }
[[ -z "$COMMIT_SUBJECT"  ]] && { printf '{"error":"missing --commit-subject"}\n'; exit 1; }

export WORK_ITEM_TITLE
export CORE_BRANCH="$BASE"

printf "\n%-8s %-8s %s\n" "Phase" "Status" "Detail" >&2
printf "%s\n" "----------------------------------------" >&2

# ── phase 1: branch ───────────────────────────────────────────────────────────
BRANCH_RESULT=$(bash "${SKILLS_DIR}/gf-branch/scripts/create-branch.sh" \
  --work-item-id "$WORK_ITEM_ID" \
  --title "${WORK_ITEM_TITLE:-}" \
  --base "$BASE" 2>/dev/null) || fatal "BRANCH" "$BRANCH_RESULT"

BRANCH_NAME=$(printf '%s' "$BRANCH_RESULT" | jq -r '.branch // "unknown"' 2>/dev/null || echo "unknown")
phase_record "BRANCH" "SUCCESS" "$BRANCH_NAME"

# ── phase 2: commit ───────────────────────────────────────────────────────────
COMMIT_ARGS=(--type "$COMMIT_TYPE" --subject "$COMMIT_SUBJECT")
[[ -n "$COMMIT_SCOPE" ]] && COMMIT_ARGS+=(--scope "$COMMIT_SCOPE")
[[ -n "$FILES_ARG"    ]] && COMMIT_ARGS+=(--files "$FILES_ARG")

COMMIT_RESULT=$(bash "${SKILLS_DIR}/gf-commit/scripts/create-commit.sh" "${COMMIT_ARGS[@]}" 2>/dev/null) \
  || fatal "COMMIT" "$COMMIT_RESULT"

COMMIT_MSG=$(printf '%s' "$COMMIT_RESULT" | jq -r '.message // "committed"' 2>/dev/null || echo "committed")
phase_record "COMMIT" "SUCCESS" "$COMMIT_MSG"

# ── phase 3: push ─────────────────────────────────────────────────────────────
PUSH_RESULT=$(bash "${SKILLS_DIR}/gf-push/scripts/push-branch.sh" 2>/dev/null) \
  || fatal "PUSH" "$PUSH_RESULT"

PUSHED_SHA=$(printf '%s' "$PUSH_RESULT" | jq -r '(.remote + "/" + .branch) // "pushed"' 2>/dev/null || echo "pushed")
phase_record "PUSH" "SUCCESS" "$PUSHED_SHA"

# ── phase 4: pr ───────────────────────────────────────────────────────────────
PR_ARGS=(--work-item-id "$WORK_ITEM_ID" --base "$BASE")
[[ -n "$PR_TITLE_ARG" ]] && PR_ARGS+=(--title "$PR_TITLE_ARG")
[[ -n "$DRAFT_FLAG"   ]] && PR_ARGS+=("$DRAFT_FLAG")

PR_RESULT=$(bash "${SKILLS_DIR}/gf-pr/scripts/create-pr.sh" "${PR_ARGS[@]}" 2>/dev/null) \
  || fatal "PR" "$PR_RESULT"

PR_URL=$(printf '%s' "$PR_RESULT" | jq -r '.url // "unknown"' 2>/dev/null || echo "unknown")
phase_record "PR" "SUCCESS" "$PR_URL"

printf "%s\n\n" "----------------------------------------" >&2

# ── final output ──────────────────────────────────────────────────────────────
printf '{"run_id":"%s","verdict":"success","pr_url":"%s","branch_name":"%s","phases":%s}\n' \
  "$RUN_ID" "$PR_URL" "$BRANCH_NAME" "$PHASES_JSON"
