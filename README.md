# renovate-config

The shared Renovate preset for alunduil's repositories. Extend it from a
repository's `renovate.json` to inherit one dependency-update policy
instead of copying it.

## Use the preset

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["github>alunduil/renovate-config"]
}
```

Renovate also checks this repository for a `default.json` when it
onboards a new repository, so a repository with no config of its own
inherits the policy.

## What the preset sets

- `config:best-practices`: Renovate's recommended base plus pinned
  GitHub Action and Docker digests, weekly lock file maintenance, and
  the dependency dashboard.
- `security:openssf-scorecard`: adds an OpenSSF Scorecard column to
  the update table in PR bodies.
- `customManagers:githubActionsVersions`: updates `*_VERSION`
  variables in workflow and action files when a
  `# renovate: datasource=… depName=…` comment annotates them.
- A three-day `minimumReleaseAge` bake before any update PR opens.
  Update types with no release timestamp (`pin`, `digest`,
  `lockFileMaintenance`, and others) are exempt, because they can never
  satisfy the bake and would otherwise stall without opening a PR.
- OSV vulnerability alerts, pre-commit hook updates, the
  `Europe/London` timezone, and `alunduil` as reviewer.

The preset leaves `schedule` unset, so PRs open as soon as the bake
passes, rate-limited by Renovate's default of two per hour. It also
leaves `baseBranchPatterns` unset; Renovate detects each repository's
default branch.

## Override the preset

Settings in a repository's `renovate.json` take precedence over the
preset. Most fields replace the preset's value; a few merge with it:

| Field                 | Behaviour                                  |
| --------------------- | ------------------------------------------ |
| `packageRules`        | Concatenated after the preset's rules.     |
| `customManagers`      | Concatenated with the preset's managers.   |
| `addLabels`           | Added to `labels`.                         |
| `additionalReviewers` | Added to `reviewers`.                      |
| `labels`              | Replaces the preset's value.               |
| `reviewers`           | Replaces the preset's value.               |

To add a reviewer without dropping `alunduil`, set
`additionalReviewers` rather than `reviewers`.
