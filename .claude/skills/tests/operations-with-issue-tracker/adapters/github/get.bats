#!/usr/bin/env bats

load '../../../../helpers/common'

CREATE_ADAPTER="$OWT_SCRIPTS/adapters/github/create.sh"
GET_ADAPTER="$OWT_SCRIPTS/adapters/github/get.sh"

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

@test "github/get: exits 1 when --id is missing" {
  require_github
  run bash -c "$(_env) bash '$GET_ADAPTER'"
  assert_failure
  assert_output_contains 'missing --id'
}

@test "github/get: returns contract JSON for a real issue" {
  require_github
  # Create a real issue to fetch
  local create_out
  create_out="$(bash -c "$(_env) bash '$CREATE_ADAPTER' --type Task --title '[bats-test] get adapter test'")";
  CREATED_ISSUE_ID="$(printf '%s' "$create_out" | jq -r '.id' 2>/dev/null || true)"
  [[ -z "$CREATED_ISSUE_ID" ]] && skip "could not create test issue"

  run bash -c "$(_env) bash '$GET_ADAPTER' --id '$CREATED_ISSUE_ID'"
  assert_success
  assert_json_field 'id' "$CREATED_ISSUE_ID"
  assert_json_field 'type' 'Task'
  assert_output_contains '"title"'
  assert_output_contains '"url"'
  assert_output_contains '"acl"'
  assert_output_contains '"steps_xml"'
}
