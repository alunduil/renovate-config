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

## Call the workflow

Add a job to the workflow that runs on `pull_request`. Replace `SHA`
with a commit on `main`; Renovate bumps the pin from there.

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
- Only files the repository already tracks are fixed. A file a hook
  creates isn't carried.
- If the fixed commit still fails a hook, the check stays red. The App
  doesn't push a second round.
