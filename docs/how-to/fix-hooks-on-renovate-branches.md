# Fix hooks on Renovate branches

A Renovate update can change a formatter's output and leave its pull
request red until someone runs the hooks by hand. Calling
`fix-renovate-hooks.yml` runs the repository's pre-commit hooks on each
Renovate pull request and pushes any fixes back to the branch as the
`alunduil-hook-fix` App. The push re-runs the required checks on the
fixed commit.

This guide is for maintainers of a repository under the `alunduil`
account. It assumes the repository already runs its hooks in CI.

## Before you start

- The `alunduil-hook-fix` App is installed on the repository.
- The repository's `renovate` ruleset lets the App push to
  `renovate/**` branches. alunduil-infrastructure manages both.
- Renovate's `gitIgnoredAuthors` lists the App's commit email.
  Otherwise Renovate treats a fixed branch as edited by someone else
  and stops updating it. The preset doesn't set this yet; see
  [#14](https://github.com/alunduil/renovate-config/issues/14).

## Call the workflow

Add a job to a workflow triggered by a bare `pull_request:`, with no
`types:`. The workflow skips the App's own pushes by the event's
sender, so extra activity types such as `labeled` would let a later
event push a second round of fixes. Replace `SHA` with a commit on
`main`.

```yaml
jobs:
  fix-renovate-hooks:
    name: Fix hooks on the Renovate branch
    uses: alunduil/renovate-config/.github/workflows/fix-renovate-hooks.yml@SHA
    permissions:
      contents: read
      id-token: write
    with:
      node-version-file: .node-version
      setup: scripts/install-lychee.sh
```

The job needs `id-token: write` to read the App's credentials from
Google Secret Manager. Pass no secrets.

The workflow does nothing on other pull requests. It skips:

- branches outside `renovate/*`
- pull requests from forks
- pushes made by the App itself

## Inputs

Every input is optional.

- `node-version-file`: installs pnpm, Node from this file, and the
  lockfile's packages before the hooks.
- `setup`: a shell command run before the hooks, for tools that
  `language: system` hooks call.
- `hook-runner`: `pre-commit` (the default) or `prek`.

## What to expect

- A fix arrives as one commit, `style: apply hook fixes`, from
  `alunduil-hook-fix[bot]`.
- The App pushes only edits to files the repository already tracks,
  outside `.github/workflows/`. Fixes that create, delete, rename, or
  change the mode of a file, or touch a workflow, fail the push job;
  run the hooks by hand.
- If the fixed commit still fails a hook, the check stays red. The App
  doesn't push a second round.
- If the branch moved after the hooks ran, the push job skips. The
  newer commit gets a run of its own.
