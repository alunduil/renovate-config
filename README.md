# renovate-config

The shared Renovate preset for alunduil's repositories. Extend it from a
repository's `renovate.json` to take on the common dependency-update
policy.

## Use the preset

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["github>alunduil/renovate-config"]
}
```

Add only repository-specific settings beside `extends`. Renovate's
onboarding PR for a new repository extends this preset automatically.

## What changes for a consuming repository

- Update PRs wait until a release is three days old. Pins, digests,
  and lock file maintenance carry no release date, so they skip the
  wait.
- GitHub Actions and Docker images are pinned to digests.
- A `# renovate: datasource=… depName=…` comment above a `*_VERSION`
  variable in a workflow or action file puts that version under
  Renovate.
- Pre-commit hook updates, OSV vulnerability alerts, and weekly lock
  file maintenance are on.
- PR bodies carry an OpenSSF Scorecard column, and alunduil is
  requested as reviewer.
- PRs open as soon as the wait clears, at most two per hour, against
  each repository's own default branch.

## Override the preset

A repository's `renovate.json` wins over the preset. Most fields replace
the preset's value; these merge with it instead:

| Field                 | Effect                                         |
| --------------------- | ---------------------------------------------- |
| `packageRules`        | Appended after the preset's; local wins.       |
| `customManagers`      | Appended to the preset's managers.             |
| `addLabels`           | Adds to `labels`.                              |
| `additionalReviewers` | Adds to `reviewers` without dropping alunduil. |
