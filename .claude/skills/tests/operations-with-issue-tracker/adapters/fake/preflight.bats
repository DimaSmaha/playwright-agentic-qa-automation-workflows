#!/usr/bin/env bats

load '../../../../helpers/common'

PREFLIGHT_ADAPTER="$OWT_SCRIPTS/adapters/fake/preflight.sh"

setup() { setup_artifacts_dir; }
teardown() { teardown_artifacts_dir; }

@test "fake/preflight: exits 1 when FAKE_TRACKER_URL is not set" {
  run bash -c "unset FAKE_TRACKER_URL; bash '$PREFLIGHT_ADAPTER'"
  assert_failure
}

@test "fake/preflight: exits 1 when server is not reachable" {
  run bash -c "FAKE_TRACKER_URL=http://localhost:19999 WORKFLOW_ARTIFACTS_DIR='$WORKFLOW_ARTIFACTS_DIR' bash '$PREFLIGHT_ADAPTER'"
  assert_failure
  assert_output_contains '"error"'
}

@test "fake/preflight: succeeds and creates cache when server is up" {
  require_fake_tracker
  run bash -c "FAKE_TRACKER_URL='$FAKE_TRACKER_URL' WORKFLOW_ARTIFACTS_DIR='$WORKFLOW_ARTIFACTS_DIR' bash '$PREFLIGHT_ADAPTER'"
  assert_success
  assert_json_field 'tracker' 'fake'
  [[ -f "$WORKFLOW_ARTIFACTS_DIR/.tracker-cache.json" ]]
}

@test "fake/preflight: cache file contains tracker=fake" {
  require_fake_tracker
  bash -c "FAKE_TRACKER_URL='$FAKE_TRACKER_URL' WORKFLOW_ARTIFACTS_DIR='$WORKFLOW_ARTIFACTS_DIR' bash '$PREFLIGHT_ADAPTER'" >/dev/null
  local cached
  cached="$(cat "$WORKFLOW_ARTIFACTS_DIR/.tracker-cache.json")"
  printf '%s' "$cached" | grep -q '"tracker":"fake"'
}
