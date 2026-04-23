#!/usr/bin/env bats

load '../../../../helpers/common'

CREATE_ADAPTER="$OWT_SCRIPTS/adapters/github/create.sh"
LINK_ADAPTER="$OWT_SCRIPTS/adapters/github/link.sh"

CREATED_SOURCE_ID=""
CREATED_TARGET_ID=""

setup() { setup_artifacts_dir; }

teardown() {
  teardown_artifacts_dir
  for id_var in CREATED_SOURCE_ID CREATED_TARGET_ID; do
    local id="${!id_var}"
    if [[ -n "$id" && -n "${REPO_OWNER:-}" && -n "${REPO_NAME:-}" ]]; then
      gh issue close "$id" --repo "$REPO_OWNER/$REPO_NAME" >/dev/null 2>&1 || true
    fi
  done
  CREATED_SOURCE_ID=""
  CREATED_TARGET_ID=""
}

_env() {
  printf 'REPO_OWNER=%s REPO_NAME=%s WORKFLOW_ARTIFACTS_DIR=%s' \
    "'$REPO_OWNER'" "'$REPO_NAME'" "'$WORKFLOW_ARTIFACTS_DIR'"
}

@test "github/link: exits 1 when --source is missing" {
  require_github
  run bash -c "$(_env) bash '$LINK_ADAPTER' --target 1 --type related"
  assert_failure
  assert_output_contains 'missing --source'
}

@test "github/link: exits 1 when --target is missing" {
  require_github
  run bash -c "$(_env) bash '$LINK_ADAPTER' --source 1 --type related"
  assert_failure
  assert_output_contains 'missing --target'
}

@test "github/link: exits 1 when --type is missing" {
  require_github
  run bash -c "$(_env) bash '$LINK_ADAPTER' --source 1 --target 2"
  assert_failure
  assert_output_contains 'missing --type'
}

@test "github/link: links two real issues and returns ok:true existed:false" {
  require_github
  local create_out
  create_out="$(bash -c "$(_env) bash '$CREATE_ADAPTER' --type Task --title '[bats-test] link source'")";
  CREATED_SOURCE_ID="$(printf '%s' "$create_out" | jq -r '.id' 2>/dev/null || true)"
  create_out="$(bash -c "$(_env) bash '$CREATE_ADAPTER' --type Task --title '[bats-test] link target'")";
  CREATED_TARGET_ID="$(printf '%s' "$create_out" | jq -r '.id' 2>/dev/null || true)"
  [[ -z "$CREATED_SOURCE_ID" || -z "$CREATED_TARGET_ID" ]] && skip "could not create test issues"

  run bash -c "$(_env) bash '$LINK_ADAPTER' --source '$CREATED_SOURCE_ID' --target '$CREATED_TARGET_ID' --type related"
  assert_success
  assert_output_contains '"ok":true'
  assert_json_field 'existed' 'false'
}

@test "github/link: returns existed:true when link already exists" {
  require_github
  local create_out
  create_out="$(bash -c "$(_env) bash '$CREATE_ADAPTER' --type Task --title '[bats-test] link idempotent source'")";
  CREATED_SOURCE_ID="$(printf '%s' "$create_out" | jq -r '.id' 2>/dev/null || true)"
  create_out="$(bash -c "$(_env) bash '$CREATE_ADAPTER' --type Task --title '[bats-test] link idempotent target'")";
  CREATED_TARGET_ID="$(printf '%s' "$create_out" | jq -r '.id' 2>/dev/null || true)"
  [[ -z "$CREATED_SOURCE_ID" || -z "$CREATED_TARGET_ID" ]] && skip "could not create test issues"

  bash -c "$(_env) bash '$LINK_ADAPTER' --source '$CREATED_SOURCE_ID' --target '$CREATED_TARGET_ID' --type related" >/dev/null
  run bash -c "$(_env) bash '$LINK_ADAPTER' --source '$CREATED_SOURCE_ID' --target '$CREATED_TARGET_ID' --type related"
  assert_success
  assert_json_field 'existed' 'true'
}
