#!/usr/bin/env bats

load '../../../../helpers/common'

CREATE_ADAPTER="$OWT_SCRIPTS/adapters/fake/create.sh"

setup() { setup_artifacts_dir; }
teardown() { teardown_artifacts_dir; }

@test "fake/create: exits 1 when FAKE_TRACKER_URL is not set" {
  run bash -c "unset FAKE_TRACKER_URL; bash '$CREATE_ADAPTER' --type Bug --title 'T'"
  assert_failure
}

@test "fake/create: exits 1 when --type is missing" {
  require_fake_tracker
  run bash -c "FAKE_TRACKER_URL='$FAKE_TRACKER_URL' bash '$CREATE_ADAPTER' --title 'T'"
  assert_failure
  assert_output_contains 'missing --type'
}

@test "fake/create: exits 1 when --title is missing" {
  require_fake_tracker
  run bash -c "FAKE_TRACKER_URL='$FAKE_TRACKER_URL' bash '$CREATE_ADAPTER' --type Bug"
  assert_failure
  assert_output_contains 'missing --title'
}

@test "fake/create: creates a Bug item and returns id=0" {
  require_fake_tracker
  run bash -c "FAKE_TRACKER_URL='$FAKE_TRACKER_URL' bash '$CREATE_ADAPTER' --type Bug --title 'Bats test bug'"
  assert_success
  assert_json_field 'id' '0'
  assert_json_field 'deduped' 'false'
}

@test "fake/create: creates a Test Case item" {
  require_fake_tracker
  run bash -c "FAKE_TRACKER_URL='$FAKE_TRACKER_URL' bash '$CREATE_ADAPTER' --type 'Test Case' --title 'Bats test case'"
  assert_success
  assert_json_field 'id' '0'
  assert_output_contains 'testcases'
}

@test "fake/create: creates a Task item" {
  require_fake_tracker
  run bash -c "FAKE_TRACKER_URL='$FAKE_TRACKER_URL' bash '$CREATE_ADAPTER' --type Task --title 'Bats task'"
  assert_success
  assert_json_field 'id' '0'
}

@test "fake/create: creates with description file" {
  require_fake_tracker
  local desc_file
  desc_file="$(mktemp)"
  printf 'Step 1\nStep 2\n' > "$desc_file"
  run bash -c "FAKE_TRACKER_URL='$FAKE_TRACKER_URL' bash '$CREATE_ADAPTER' --type 'Test Case' --title 'TC with steps' --description-file '$desc_file'"
  rm -f "$desc_file"
  assert_success
  assert_json_field 'id' '0'
}
