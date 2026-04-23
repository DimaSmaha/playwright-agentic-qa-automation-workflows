#!/usr/bin/env bats

load '../../../helpers/common'
load '../../../helpers/mock-git'

PR_ADAPTER="$SKILLS_DIR/gf-pr/adapters/github/pr.sh"

setup() {
  setup_git_repo
  # We need a real remote GitHub repo here; otherwise skip.
  require_github
  # The adapter needs a real branch pushed to a real GitHub repo.
  local branch="bats-pr-adapter-$(date +%s)"
  BATS_TEST_BRANCH="$branch"
  git -C "$GIT_REPO_DIR" checkout -b "$branch" -q
  printf 'adapter test\n' > "$GIT_REPO_DIR/adapter.txt"
  git -C "$GIT_REPO_DIR" add adapter.txt
  git -C "$GIT_REPO_DIR" commit -m "feat: adapter smoke test" -q
  # We use GIT_REPO_DIR as local; adapter needs push to a real GitHub remote.
  # Skip if REPO_OWNER/REPO_NAME is not the real GitHub repo.
}

teardown() {
  teardown_git_repo
  if [[ -n "${BATS_TEST_PR_ID:-}" ]]; then
    gh pr close "$BATS_TEST_PR_ID" --repo "$REPO_OWNER/$REPO_NAME" >/dev/null 2>&1 || true
  fi
  if [[ -n "${BATS_TEST_BRANCH:-}" ]]; then
    gh api -X DELETE "repos/$REPO_OWNER/$REPO_NAME/git/refs/heads/$BATS_TEST_BRANCH" >/dev/null 2>&1 || true
  fi
  unset BATS_TEST_BRANCH BATS_TEST_PR_ID
}

@test "gf-pr/github/pr: exits 1 when GITHUB_TOKEN is not set" {
  run bash -c "unset GITHUB_TOKEN GH_TOKEN; REPO_OWNER=o REPO_NAME=r PR_TITLE=T PR_BODY=B PR_BASE=main PR_DRAFT=false PR_WORK_ITEM_ID='' bash '$PR_ADAPTER'"
  assert_failure
  assert_output_contains 'GITHUB_TOKEN'
}

@test "gf-pr/github/pr: creates a real PR against the GitHub repo" {
  require_github
  # Push BATS_TEST_BRANCH to the real GitHub remote
  git -C "$GIT_REPO_DIR" remote set-url origin "https://x-access-token:${GITHUB_TOKEN:-${GH_TOKEN:-}}@github.com/$REPO_OWNER/$REPO_NAME.git" 2>/dev/null || true
  git -C "$GIT_REPO_DIR" push origin "$BATS_TEST_BRANCH" -q 2>/dev/null || skip "cannot push to GitHub remote"

  run bash -c "cd '$GIT_REPO_DIR' && git checkout '$BATS_TEST_BRANCH' -q 2>/dev/null; GITHUB_TOKEN='${GITHUB_TOKEN:-${GH_TOKEN:-}}' REPO_OWNER='$REPO_OWNER' REPO_NAME='$REPO_NAME' PR_TITLE='[bats-test] pr adapter smoke' PR_BODY='Automated bats test' PR_BASE=main PR_DRAFT=false PR_WORK_ITEM_ID='' bash '$PR_ADAPTER'"
  BATS_TEST_PR_ID="$(printf '%s' "$output" | jq -r '.id // empty' 2>/dev/null || true)"

  assert_success
  assert_json_field 'deduped' 'false'
  assert_output_contains '"url"'
}

@test "gf-pr/github/pr: deduplicates when PR already exists" {
  require_github
  git -C "$GIT_REPO_DIR" remote set-url origin "https://x-access-token:${GITHUB_TOKEN:-${GH_TOKEN:-}}@github.com/$REPO_OWNER/$REPO_NAME.git" 2>/dev/null || true
  git -C "$GIT_REPO_DIR" push origin "$BATS_TEST_BRANCH" -q 2>/dev/null || skip "cannot push to GitHub remote"

  local env_vars="cd '$GIT_REPO_DIR' && git checkout '$BATS_TEST_BRANCH' -q 2>/dev/null; GITHUB_TOKEN='${GITHUB_TOKEN:-${GH_TOKEN:-}}' REPO_OWNER='$REPO_OWNER' REPO_NAME='$REPO_NAME' PR_TITLE='[bats-test] dedupe pr' PR_BODY='body' PR_BASE=main PR_DRAFT=false PR_WORK_ITEM_ID=''"
  bash -c "$env_vars bash '$PR_ADAPTER'" >/dev/null
  BATS_TEST_PR_ID="$(bash -c "$env_vars bash '$PR_ADAPTER'" | jq -r '.id // empty' 2>/dev/null || true)"

  run bash -c "$env_vars bash '$PR_ADAPTER'"
  assert_success
  assert_json_field 'deduped' 'true'
}
