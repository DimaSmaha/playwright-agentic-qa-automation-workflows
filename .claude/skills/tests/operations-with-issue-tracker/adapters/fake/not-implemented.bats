#!/usr/bin/env bats

load '../../../../helpers/common'

NOT_IMPL="$OWT_SCRIPTS/adapters/fake/_not_implemented.sh"

@test "fake/_not_implemented: exits 0" {
  run bash "$NOT_IMPL" update
  assert_success
}

@test "fake/_not_implemented: outputs ok:true" {
  run bash "$NOT_IMPL" link
  assert_success
  assert_output_contains '"ok":true'
}

@test "fake/_not_implemented: outputs skipped:true" {
  run bash "$NOT_IMPL" comment
  assert_success
  assert_output_contains '"skipped":true'
}

@test "fake/_not_implemented: includes a reason field" {
  run bash "$NOT_IMPL" query
  assert_success
  assert_output_contains '"reason"'
}
