#!/usr/bin/env bats

load '../../../../helpers/common'

CREATE_ADAPTER="$OWT_SCRIPTS/adapters/github/create.sh"
UPDATE_STEPS_ADAPTER="$OWT_SCRIPTS/adapters/github/update-steps.sh"

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

@test "github/update-steps: exits 1 when --id is missing" {
  require_github
  run bash -c "$(_env) bash '$UPDATE_STEPS_ADAPTER' --steps-file /dev/null"
  assert_failure
  assert_output_contains 'missing --id'
}

@test "github/update-steps: exits 1 when --steps-file is missing" {
  require_github
  run bash -c "$(_env) bash '$UPDATE_STEPS_ADAPTER' --id 1"
  assert_failure
  assert_output_contains 'missing --steps-file'
}

@test "github/update-steps: exits 1 when steps file does not exist" {
  require_github
  run bash -c "$(_env) bash '$UPDATE_STEPS_ADAPTER' --id 1 --steps-file /no/such/file"
  assert_failure
  assert_output_contains 'does not exist'
}

@test "github/update-steps: appends steps XML to issue body" {
  require_github
  local create_out
  create_out="$(bash -c "$(_env) bash '$CREATE_ADAPTER' --type 'Test Case' --title '[bats-test] update-steps test'")";
  CREATED_ISSUE_ID="$(printf '%s' "$create_out" | jq -r '.id' 2>/dev/null || true)"
  [[ -z "$CREATED_ISSUE_ID" ]] && skip "could not create test issue"

  local steps_file
  steps_file="$(mktemp)"
  printf '<step id="1"><action>Click login</action></step>\n' > "$steps_file"

  run bash -c "$(_env) bash '$UPDATE_STEPS_ADAPTER' --id '$CREATED_ISSUE_ID' --steps-file '$steps_file'"
  rm -f "$steps_file"
  assert_success
  assert_output_contains '"ok":true'
}

@test "github/update-steps: --replace clears old steps before writing" {
  require_github
  local create_out
  create_out="$(bash -c "$(_env) bash '$CREATE_ADAPTER' --type 'Test Case' --title '[bats-test] replace steps test'")";
  CREATED_ISSUE_ID="$(printf '%s' "$create_out" | jq -r '.id' 2>/dev/null || true)"
  [[ -z "$CREATED_ISSUE_ID" ]] && skip "could not create test issue"

  local steps_file
  steps_file="$(mktemp)"
  printf '<step id="1"><action>Step A</action></step>\n' > "$steps_file"
  bash -c "$(_env) bash '$UPDATE_STEPS_ADAPTER' --id '$CREATED_ISSUE_ID' --steps-file '$steps_file'" >/dev/null

  printf '<step id="1"><action>Step B</action></step>\n' > "$steps_file"
  run bash -c "$(_env) bash '$UPDATE_STEPS_ADAPTER' --id '$CREATED_ISSUE_ID' --steps-file '$steps_file' --replace"
  rm -f "$steps_file"
  assert_success
  assert_output_contains '"ok":true'
}
