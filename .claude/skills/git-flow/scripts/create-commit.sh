#!/usr/bin/env bash
# gf-commit — create-commit.sh
# Scans staged files for secrets, then commits with a conventional commit message.
# Outputs JSON only. Exit 0 = success, non-zero = failure.
#
# Usage:
#   create-commit.sh --type fix --scope orders --subject "scope date filter" [--body "..."] [--files "path1 path2"]
#
# Flags:
#   --type     Conventional commit type (feat|fix|chore|docs|test|refactor|ci)
#   --scope    Optional scope (e.g. orders, auth)
#   --subject  Short imperative subject line
#   --body     Optional multi-line body (use \n for newlines)
#   --files    Space-separated list of files to stage (default: already-staged)
#
# Secret blocklist (paths and pattern matches):
#   .env  .env.*  *.key  *.pem  *.pfx  id_rsa*  playwright/.auth/*.json

set -euo pipefail

# ── helpers ───────────────────────────────────────────────────────────────────
json_err()  { printf '{"error":"%s","paths":%s}\n' "$1" "${2:-[]}"; exit 1; }
json_ok()   { printf '%s\n' "$1"; exit 0; }

# ── args ──────────────────────────────────────────────────────────────────────
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

# ── safety: refuse commit on main ─────────────────────────────────────────────
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
[[ "$CURRENT_BRANCH" == "main" || "$CURRENT_BRANCH" == "master" ]] \
  && json_err "refusing to commit directly on $CURRENT_BRANCH" "[]"

# ── stage extra files if provided ─────────────────────────────────────────────
if [[ ${#EXTRA_FILES[@]} -gt 0 ]]; then
  git add -- "${EXTRA_FILES[@]}"
fi

# ── collect staged files ──────────────────────────────────────────────────────
mapfile -t STAGED < <(git diff --cached --name-only)
[[ ${#STAGED[@]} -eq 0 ]] && json_err "nothing staged to commit" "[]"

# ── secret detection ──────────────────────────────────────────────────────────
SECRET_PATTERNS=(
  '\.env$'
  '\.env\.'
  '\.key$'
  '\.pem$'
  '\.pfx$'
  'id_rsa'
  'id_ed25519'
  'playwright/\.auth/.*\.json$'
  '\.p12$'
  'secrets\.'
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
  # Build JSON array of bad paths
  BAD_JSON=$(printf '"%s",' "${BAD_PATHS[@]}")
  BAD_JSON="[${BAD_JSON%,}]"
  json_err "refusing to commit secrets" "$BAD_JSON"
fi

# ── build commit message ───────────────────────────────────────────────────────
if [[ -n "$SCOPE" ]]; then
  MSG_HEADER="${TYPE}(${SCOPE}): ${SUBJECT}"
else
  MSG_HEADER="${TYPE}: ${SUBJECT}"
fi

if [[ -n "$BODY" ]]; then
  FULL_MSG="${MSG_HEADER}"$'\n\n'"${BODY}"
else
  FULL_MSG="$MSG_HEADER"
fi

# ── commit ────────────────────────────────────────────────────────────────────
git commit -m "$FULL_MSG"

SHA=$(git rev-parse HEAD)
BRANCH=$(git rev-parse --abbrev-ref HEAD)

json_ok "$(printf '{"sha":"%s","branch":"%s","message":"%s","files_committed":%d}' \
  "$SHA" "$BRANCH" "$MSG_HEADER" "${#STAGED[@]}")"