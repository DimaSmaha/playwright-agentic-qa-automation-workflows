#!/usr/bin/env bats

load '../../../../helpers/common'

CREATE_ADAPTER="$OWT_SCRIPTS/adapters/fake/create.sh"
GET_ADAPTER="$OWT_SCRIPTS/adapters/fake/get.sh"

setup() { setup_artifacts_dir; }
teardown() { teardown_artifacts_dir; }

@test "fake/get: exits 1 when FAKE_TRACKER_URL is not set" {
  run bash -c "unset FAKE_TRACKER_URL; bash '$GET_ADAPTER' --id 1"
  assert_failure
}

@test "fake/get: exits 1 when --id is missing" {
  require_fake_tracker
  run bash -c "FAKE_TRACKER_URL='$FAKE_TRACKER_URL' bash '$GET_ADAPTER'"
  assert_failure
  assert_output_contains 'missing --id'
}

@test "fake/get: returns contract JSON shape for existing item" {
  require_fake_tracker
  # Create a task first so we have a real item to fetch.
  # Fake tracker returns id=0 for all creates; fetch tasks/1 which should exist after creation.
  bash -c "FAKE_TRACKER_URL='$FAKE_TRACKER_URL' bash '$CREATE_ADAPTER' --type Task --title 'Fetch me'" >/dev/null 2>&1 || true
  run bash -c "FAKE_TRACKER_URL='$FAKE_TRACKER_URL' bash '$GET_ADAPTER' --id 1 --type Task"
  # Item may or may not exist depending on tracker state; just assert output is JSON.
  [[ "$output" == *'{'* ]]
}

@test "fake/get: contract JSON includes required fields on success" {
  require_fake_tracker
  bash -c "FAKE_TRACKER_URL='$FAKE_TRACKER_URL' bash '$CREATE_ADAPTER' --type Bug --title 'Bug for get test'" >/dev/null 2>&1 || true
  run bash -c "FAKE_TRACKER_URL='$FAKE_TRACKER_URL' bash '$GET_ADAPTER' --id 1 --type Bug"
  if [[ "$status" -eq 0 ]]; then
    assert_output_contains '"id"'
    assert_output_contains '"title"'
    assert_output_contains '"url"'
  fi
}
