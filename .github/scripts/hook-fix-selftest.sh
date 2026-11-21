#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT
#
# Runs one hook-fix self-test case against CI's call to fix-renovate-hooks.yml.
#
#   run      Branch BRANCH from BASE_SHA, plant CASE's change, open a pull
#            request, wait for CI, and assert the outcome.
#   cleanup  Close the pull request and delete BRANCH.
#
# Environment:
#   GH_TOKEN       alunduil-hook-fix-selftest installation token
#   ACTIONS_TOKEN  token that reads this repository's Actions runs
#   BRANCH, BASE_SHA, CASE (whitespace, clean, or workflow)
set -euo pipefail

readonly HOOKS_JOB='Run hooks on the Renovate branch'
readonly PUSH_JOB='Push hook fixes to the Renovate branch'
readonly PRE_COMMIT_JOB='Run pre-commit hooks'
readonly FIX_AUTHOR='alunduil-hook-fix[bot]'
readonly FIX_MESSAGE='style: apply hook fixes'
readonly CI_TIMEOUT_SECONDS=1200
readonly CI_POLL_SECONDS=20
readonly REPO_API="repos/${GITHUB_REPOSITORY}"

fail() {
  echo "::error::${CASE}: $*"
  exit 1
}

actions_api() {
  GH_TOKEN="${ACTIONS_TOKEN}" gh api "$@"
}

branch_head() {
  gh api "${REPO_API}/git/ref/heads/${BRANCH}" --jq .object.sha
}

# Prints the ID of CI's completed pull request run on a commit, or fails after
# CI_TIMEOUT_SECONDS.
wait_for_ci() {
  local sha=$1 deadline=$((SECONDS + CI_TIMEOUT_SECONDS)) run
  while ((SECONDS < deadline)); do
    run="$(actions_api "${REPO_API}/actions/runs?head_sha=${sha}&event=pull_request" \
      --jq '[.workflow_runs[] | select(.name == "CI")] | first // empty | "\(.id) \(.status)"')"
    if [[ "${run}" == *" completed" ]]; then
      echo "${run%% *}"
      return
    fi
    sleep "${CI_POLL_SECONDS}"
  done
  return 1
}

# Jobs from a called workflow are named "<caller job> / <called job>".
job_conclusion() {
  actions_api --paginate "${REPO_API}/actions/runs/$1/jobs" \
    --jq ".jobs[] | select(.name == \"$2\" or (.name | endswith(\" / $2\"))) | .conclusion"
}

expect_job() {
  local actual
  actual="$(job_conclusion "$1" "$2")"
  [[ "${actual}" == "$3" ]] || fail "expected ${2} to conclude ${3}, got '${actual}'"
}

expect_unchanged() {
  [[ "$(branch_head)" == "$1" ]] || fail "expected no commit after ${1}"
}

expect_fix_commit() {
  local planted_sha=$1 fix_sha=$2 fix_commit
  [[ "${fix_sha}" != "${planted_sha}" ]] || fail "no fix commit arrived"
  fix_commit="$(gh api "${REPO_API}/commits/${fix_sha}" \
    --jq '"\(.parents | map(.sha) | join(" "))|\(.author.login)|\(.commit.message)"')"
  [[ "${fix_commit}" == "${planted_sha}|${FIX_AUTHOR}|${FIX_MESSAGE}" ]] ||
    fail "expected one '${FIX_MESSAGE}' commit by ${FIX_AUTHOR} on ${planted_sha}, got '${fix_commit}'"
}

# Each case defines <case>_path, the file it changes; <case>_addition, the
# text it appends there; and <case>_expect, its assertions on CI's run of the
# planted commit.

whitespace_path() { echo REUSE.toml; }
whitespace_addition() { printf '# hook-fix self-test   \n'; }
whitespace_expect() {
  local planted_sha=$1 ci_run=$2 fix_sha
  expect_job "${ci_run}" "${HOOKS_JOB}" success
  fix_sha="$(branch_head)"
  expect_fix_commit "${planted_sha}" "${fix_sha}"
  ci_run="$(wait_for_ci "${fix_sha}")" || fail "CI didn't finish on ${fix_sha}"
  expect_job "${ci_run}" "${PRE_COMMIT_JOB}" success
  # The App's own push must not start a second fix round.
  expect_job "${ci_run}" "${HOOKS_JOB}" skipped
}

clean_path() { echo REUSE.toml; }
clean_addition() { printf '# hook-fix self-test\n'; }
clean_expect() {
  expect_job "$2" "${HOOKS_JOB}" success
  expect_job "$2" "${PUSH_JOB}" skipped
  expect_unchanged "$1"
}

# The App can't write .github/workflows/, so this case plants a hook that
# edits a workflow file and leaves the fix to the hooks job.
workflow_path() { echo .pre-commit-config.yaml; }
workflow_addition() {
  cat <<'EOF'

  - repo: local
    hooks:
      - id: hook-fix-selftest
        name: Edit a workflow file
        language: system
        entry: sh -c 'echo "# hook-fix self-test" >> .github/workflows/pr-title.yml'
        pass_filenames: false
        always_run: true
EOF
}
workflow_expect() {
  expect_job "$2" "${PUSH_JOB}" failure
  expect_unchanged "$1"
}

create_branch() {
  gh api -X POST "${REPO_API}/git/refs" \
    -f ref="refs/heads/${BRANCH}" -f sha="${BASE_SHA}" >/dev/null
}

# Prints the planted commit's SHA.
plant() {
  local path file content
  path="$("${CASE}_path")"
  file="$(gh api "${REPO_API}/contents/${path}?ref=${BASE_SHA}")"
  content="$({
    jq -r .content <<<"${file}" | base64 -d
    "${CASE}_addition"
  } | base64 -w0)"
  gh api -X PUT "${REPO_API}/contents/${path}" \
    -f message="test: plant the ${CASE} hook-fix case" \
    -f content="${content}" -f sha="$(jq -r .sha <<<"${file}")" -f branch="${BRANCH}" \
    --jq .commit.sha
}

open_pull_request() {
  gh api -X POST "${REPO_API}/pulls" \
    -f title="test: hook-fix self-test (${CASE})" \
    -f head="${BRANCH}" -f base=main -F draft=true \
    -f body="Opened by the hook-fix self-test run ${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}. It closes and deletes this branch when it finishes." \
    >/dev/null
}

run_case() {
  declare -F "${CASE}_expect" >/dev/null || fail "unknown case"

  local planted_sha ci_run
  create_branch
  planted_sha="$(plant)"
  open_pull_request
  ci_run="$(wait_for_ci "${planted_sha}")" || fail "CI didn't finish on ${planted_sha}"
  "${CASE}_expect" "${planted_sha}" "${ci_run}"
}

cleanup() {
  local pr
  for pr in $(gh api "${REPO_API}/pulls?state=open&head=${GITHUB_REPOSITORY_OWNER}:${BRANCH}" --jq '.[].number'); do
    gh api -X PATCH "${REPO_API}/pulls/${pr}" -f state=closed >/dev/null
  done
  if gh api "${REPO_API}/git/ref/heads/${BRANCH}" >/dev/null 2>&1; then
    gh api -X DELETE "${REPO_API}/git/refs/heads/${BRANCH}"
  fi
}

case "${1:-}" in
  run) run_case ;;
  cleanup) cleanup ;;
  *)
    echo "usage: $0 run|cleanup" >&2
    exit 2
    ;;
esac
