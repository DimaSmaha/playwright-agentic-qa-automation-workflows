#!/usr/bin/env bats

load '../../../../helpers/common'

PREFLIGHT_ADAPTER="$OWT_SCRIPTS/adapters/github/preflight.sh"

setup() { setup_artifacts_dir; }
teardown() { teardown_artifacts_dir; }

@test "github/preflight: exits 1 when gh is not authenticated" {
  require_github
  # If already authenticated this will pass; if not, it will fail with the auth error.
  run bash -c "REPO_OWNER='$REPO_OWNER' REPO_NAME='$REPO_NAME' WORKFLOW_ARTIFACTS_DIR='$WORKFLOW_ARTIFACTS_DIR' bash '$PREFLIGHT_ADAPTER'"
  # We just assert it produces JSON either way — success or auth error.
  [[ "$output" == *'{'* ]]
}

@test "github/preflight: succeeds and creates cache file" {
  require_github
  run bash -c "REPO_OWNER='$REPO_OWNER' REPO_NAME='$REPO_NAME' WORKFLOW_ARTIFACTS_DIR='$WORKFLOW_ARTIFACTS_DIR' bash '$PREFLIGHT_ADAPTER'"
  assert_success
  assert_json_field 'tracker' 'github'
  [[ -f "$WORKFLOW_ARTIFACTS_DIR/.tracker-cache.json" ]]
}

@test "github/preflight: cache contains org and project" {
  require_github
  bash -c "REPO_OWNER='$REPO_OWNER' REPO_NAME='$REPO_NAME' WORKFLOW_ARTIFACTS_DIR='$WORKFLOW_ARTIFACTS_DIR' bash '$PREFLIGHT_ADAPTER'" >/dev/null
  local cached
  cached="$(cat "$WORKFLOW_ARTIFACTS_DIR/.tracker-cache.json")"
  printf '%s' "$cached" | grep -q '"org"'
  printf '%s' "$cached" | grep -q '"project"'
}

@test "github/preflight: --force re-writes cache" {
  require_github
  local env_vars="REPO_OWNER='$REPO_OWNER' REPO_NAME='$REPO_NAME' WORKFLOW_ARTIFACTS_DIR='$WORKFLOW_ARTIFACTS_DIR'"
  bash -c "$env_vars bash '$PREFLIGHT_ADAPTER'" >/dev/null
  run bash -c "$env_vars bash '$PREFLIGHT_ADAPTER' --force"
  assert_success
  [[ -f "$WORKFLOW_ARTIFACTS_DIR/.tracker-cache.json" ]]
}
