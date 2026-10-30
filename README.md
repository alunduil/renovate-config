# renovate-config

[![License](https://img.shields.io/github/license/alunduil/renovate-config)](LICENSE)

The shared Renovate preset for alunduil's repositories. Extend it from a
repository's `renovate.json` to take on the common dependency-update
policy.

## Use the preset

The preset does nothing until the [Renovate GitHub
app](https://github.com/apps/renovate) runs on the repository. With the
app installed, extend the preset from `renovate.json`:

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
- Releases from registries that publish no dates, such as Hackage,
  also skip the wait. The Dependency Dashboard lists this as a warning
  under Repository Problems.
- Renovate pins GitHub Actions and Docker images to digests.
- A `# renovate: datasource=… depName=…` comment above a `*_VERSION`
  variable in a workflow or action file lets Renovate update that
  version.
- Pre-commit hook updates, OSV vulnerability alerts, and weekly lock
  file maintenance are on.
- Every PR carries the `dependencies` label, an OpenSSF Scorecard
  column, and a review request for alunduil.
- PRs open as soon as the wait clears, at most two per hour, against
  each repository's own default branch.

## Override the preset

A repository's `renovate.json` wins over the preset. Most fields replace
the preset's value; these merge with it instead:

| Field                 | Effect                                            |
| --------------------- | ------------------------------------------------- |
| `packageRules`        | Appended after the preset's, so yours win.        |
| `customManagers`      | Appended to the preset's managers.                |
| `addLabels`           | Adds to `labels` without dropping `dependencies`. |
| `additionalReviewers` | Adds to `reviewers` without dropping alunduil.    |

## Fix hooks on Renovate branches

A reusable workflow pushes pre-commit hook fixes to Renovate pull
requests. See [Fix hooks on Renovate
branches](docs/how-to/fix-hooks-on-renovate-branches.md).

## Contributions

This preset follows the needs of alunduil's repositories and isn't
accepting contributions.
