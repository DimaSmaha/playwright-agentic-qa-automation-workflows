#!/usr/bin/env bats

load '../helpers/common'
load '../helpers/mock-git'

CREATE_COMMIT="$GF_COMMIT_SCRIPTS/create-commit.sh"

setup() {
  setup_git_repo
  # Work on a feature branch — script refuses to commit on main/master
  git -C "$GIT_REPO_DIR" checkout -b feature/test -q
}

teardown() { teardown_git_repo; }

@test "create-commit: exits 1 when --type is missing" {
  stage_file "file.txt"
  run bash -c "cd '$GIT_REPO_DIR' && bash '$CREATE_COMMIT' --subject 'add something'"
  assert_failure
  assert_output_contains 'missing --type'
}

@test "create-commit: exits 1 when --subject is missing" {
  stage_file "file.txt"
  run bash -c "cd '$GIT_REPO_DIR' && bash '$CREATE_COMMIT' --type fix"
  assert_failure
  assert_output_contains 'missing --subject'
}

@test "create-commit: exits 1 for an invalid --type" {
  stage_file "file.txt"
  run bash -c "cd '$GIT_REPO_DIR' && bash '$CREATE_COMMIT' --type bad --subject 'x'"
  assert_failure
  assert_output_contains 'invalid type'
}

@test "create-commit: exits 1 when nothing is staged" {
  run bash -c "cd '$GIT_REPO_DIR' && bash '$CREATE_COMMIT' --type fix --subject 'nothing staged'"
  assert_failure
  assert_output_contains 'nothing staged'
}

@test "create-commit: exits 1 when on main branch" {
  git -C "$GIT_REPO_DIR" checkout main -q
  stage_file "file.txt"
  run bash -c "cd '$GIT_REPO_DIR' && bash '$CREATE_COMMIT' --type fix --subject 'should fail'"
  assert_failure
  assert_output_contains 'main'
}

@test "create-commit: exits 1 when a secret file is staged" {
  stage_file ".env" "SECRET=abc"
  run bash -c "cd '$GIT_REPO_DIR' && bash '$CREATE_COMMIT' --type chore --subject 'add env'"
  assert_failure
  assert_output_contains 'secrets'
  assert_output_contains '.env'
}

@test "create-commit: exits 1 when a .key file is staged" {
  stage_file "my.key" "key content"
  run bash -c "cd '$GIT_REPO_DIR' && bash '$CREATE_COMMIT' --type chore --subject 'add key'"
  assert_failure
  assert_output_contains 'secrets'
}

@test "create-commit: happy path returns SHA, branch and message" {
  stage_file "feature.txt"
  run bash -c "cd '$GIT_REPO_DIR' && bash '$CREATE_COMMIT' --type feat --subject 'add feature'"
  assert_success
  assert_output_contains '"sha"'
  assert_json_field 'branch' 'feature/test'
  assert_output_contains 'feat: add feature'
}

@test "create-commit: includes scope in message when --scope given" {
  stage_file "scoped.txt"
  run bash -c "cd '$GIT_REPO_DIR' && bash '$CREATE_COMMIT' --type fix --scope orders --subject 'fix filter'"
  assert_success
  assert_output_contains 'fix(orders): fix filter'
}

@test "create-commit: --files stages extra paths before committing" {
  printf 'content\n' > "$GIT_REPO_DIR/extra.txt"
  run bash -c "cd '$GIT_REPO_DIR' && bash '$CREATE_COMMIT' --type chore --subject 'add extra' --files extra.txt"
  assert_success
  assert_json_field 'files_committed' '1'
}

@test "create-commit: files_committed count matches staged file count" {
  stage_file "a.txt"
  stage_file "b.txt"
  run bash -c "cd '$GIT_REPO_DIR' && bash '$CREATE_COMMIT' --type chore --subject 'two files'"
  assert_success
  assert_json_field 'files_committed' '2'
}
