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
readonly REPO_API="repos/${GITHUB_REPOSITORY}"

fail() {
  echo "::error::${CASE}: $*"
  exit 1
}

# The App can't write .github/workflows/, so the workflow case plants a hook
# that edits a workflow file and leaves the fix to the hooks job.
planted_path() {
  case "${CASE}" in
    whitespace | clean) echo REUSE.toml ;;
    workflow) echo .pre-commit-config.yaml ;;
  esac
}

planted_content() {
  gh api "${REPO_API}/contents/$1?ref=${BASE_SHA}" --jq .content | base64 -d
  case "${CASE}" in
    whitespace) printf '# hook-fix self-test   \n' ;;
    clean) printf '# hook-fix self-test\n' ;;
    workflow)
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
      ;;
  esac
}

# Prints the planted commit's SHA.
plant() {
  local path blob content
  path="$(planted_path)"
  blob="$(gh api "${REPO_API}/contents/${path}?ref=${BASE_SHA}" --jq .sha)"
  content="$(planted_content "${path}" | base64 -w0)"
  gh api -X PUT "${REPO_API}/contents/${path}" \
    -f message="test: plant the ${CASE} hook-fix case" \
    -f content="${content}" -f sha="${blob}" -f branch="${BRANCH}" \
    --jq .commit.sha
}

branch_head() {
  gh api "${REPO_API}/git/ref/heads/${BRANCH}" --jq .object.sha
}

# Sets CI_RUN to the ID of CI's completed pull request run on a commit.
wait_for_ci() {
  local sha=$1 deadline=$((SECONDS + 1200)) run
  while :; do
    run="$(GH_TOKEN="${ACTIONS_TOKEN}" gh api \
      "${REPO_API}/actions/runs?head_sha=${sha}&event=pull_request" \
      --jq '[.workflow_runs[] | select(.name == "CI")] | first // empty | "\(.id) \(.status)"')"
    if [[ "${run}" == *" completed" ]]; then
      CI_RUN="${run%% *}"
      return
    fi
    ((SECONDS < deadline)) || fail "CI didn't finish on ${sha}"
    sleep 20
  done
}

# Jobs from a called workflow are named "<caller job> / <called job>".
job_conclusion() {
  GH_TOKEN="${ACTIONS_TOKEN}" gh api --paginate "${REPO_API}/actions/runs/$1/jobs" \
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

run_case() {
  case "${CASE}" in
    whitespace | clean | workflow) ;;
    *) fail "unknown case" ;;
  esac

  # This is the call alunduil-infrastructure#1289 probes: GitHub's response
  # shows whether an App without Workflows can branch at a commit whose
  # workflow files differ from main's.
  gh api -X POST "${REPO_API}/git/refs" \
    -f ref="refs/heads/${BRANCH}" -f sha="${BASE_SHA}" >/dev/null

  local planted
  planted="$(plant)"
  gh api -X POST "${REPO_API}/pulls" \
    -f title="test: hook-fix self-test (${CASE})" \
    -f head="${BRANCH}" -f base=main -F draft=true \
    -f body="Opened by the hook-fix self-test run ${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}. It closes and deletes this branch when it finishes." \
    >/dev/null
  wait_for_ci "${planted}"

  case "${CASE}" in
    whitespace)
      expect_job "${CI_RUN}" "${HOOKS_JOB}" success
      local fixed commit
      fixed="$(branch_head)"
      [[ "${fixed}" != "${planted}" ]] || fail "no fix commit arrived"
      commit="$(gh api "${REPO_API}/commits/${fixed}" \
        --jq '"\(.parents | map(.sha) | join(" "))|\(.author.login)|\(.commit.message)"')"
      [[ "${commit}" == "${planted}|${FIX_AUTHOR}|${FIX_MESSAGE}" ]] ||
        fail "expected one '${FIX_MESSAGE}' commit by ${FIX_AUTHOR} on ${planted}, got '${commit}'"
      wait_for_ci "${fixed}"
      expect_job "${CI_RUN}" "${PRE_COMMIT_JOB}" success
      # The App's own push must not start a second fix round.
      expect_job "${CI_RUN}" "${HOOKS_JOB}" skipped
      ;;
    clean)
      expect_job "${CI_RUN}" "${HOOKS_JOB}" success
      expect_job "${CI_RUN}" "${PUSH_JOB}" skipped
      expect_unchanged "${planted}"
      ;;
    workflow)
      expect_job "${CI_RUN}" "${PUSH_JOB}" failure
      expect_unchanged "${planted}"
      ;;
  esac
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
