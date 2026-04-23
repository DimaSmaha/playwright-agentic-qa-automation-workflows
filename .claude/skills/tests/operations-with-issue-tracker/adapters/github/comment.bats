#!/usr/bin/env bats

load '../../../../helpers/common'

CREATE_ADAPTER="$OWT_SCRIPTS/adapters/github/create.sh"
COMMENT_ADAPTER="$OWT_SCRIPTS/adapters/github/comment.sh"

CREATED_ISSUE_ID=""

setup() { setup_artifacts_dir; }

teardown() {
  teardown_artifacts_dir
  if [[ -n "$CREATED_ISSUE_ID" && -n "${REPO_OWNER:-}" && -n "${REPO_NAME:-}" ]]; then
    gh issue close "$CREATED_ISSUE_ID" --repo "$REPO_OWNER/$REPO_NAME" >/dev/null 2>&1 || true
    CREATED_ISSUE_ID=""
  fi
}

_env() {
  printf 'REPO_OWNER=%s REPO_NAME=%s WORKFLOW_ARTIFACTS_DIR=%s' \
    "'$REPO_OWNER'" "'$REPO_NAME'" "'$WORKFLOW_ARTIFACTS_DIR'"
}

@test "github/comment: exits 1 when --id is missing" {
  require_github
  run bash -c "$(_env) bash '$COMMENT_ADAPTER' --body-file /dev/null"
  assert_failure
  assert_output_contains 'missing --id'
}

@test "github/comment: exits 1 when --body-file is missing" {
  require_github
  run bash -c "$(_env) bash '$COMMENT_ADAPTER' --id 1"
  assert_failure
  assert_output_contains 'missing --body-file'
}

@test "github/comment: exits 1 when body file does not exist" {
  require_github
  run bash -c "$(_env) bash '$COMMENT_ADAPTER' --id 1 --body-file /no/such/file"
  assert_failure
  assert_output_contains 'does not exist'
}

@test "github/comment: posts a comment on a real issue" {
  require_github
  local create_out
  create_out="$(bash -c "$(_env) bash '$CREATE_ADAPTER' --type Task --title '[bats-test] comment adapter test'")";
  CREATED_ISSUE_ID="$(printf '%s' "$create_out" | jq -r '.id' 2>/dev/null || true)"
  [[ -z "$CREATED_ISSUE_ID" ]] && skip "could not create test issue"

  local body_file
  body_file="$(mktemp)"
  printf 'Automated bats test comment\n' > "$body_file"

  run bash -c "$(_env) bash '$COMMENT_ADAPTER' --id '$CREATED_ISSUE_ID' --body-file '$body_file'"
  rm -f "$body_file"
  assert_success
  assert_output_contains '"ok":true'
}
