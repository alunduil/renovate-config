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

## Pin exact versions in an application

Extend the `application` preset in place of the default:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["github>alunduil/renovate-config:application"]
}
```

Renovate opens a PR pinning every range except `peerDependencies` and
`engines`. Everything else matches the default preset. A published
library stays on the default, keeping its ranges so its consumers can
resolve shared dependencies.

## Automerge updates

Two opt-in presets merge updates once required checks pass. Extend
either one only when the branch ruleset lets Renovate merge. Add them
beside the default or `application` preset, keeping this order when
extending both:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "github>alunduil/renovate-config",
    "github>alunduil/renovate-config:automerge-minor",
    "github>alunduil/renovate-config:automerge-workflow-majors"
  ]
}
```

Listed last, `automerge-minor` holds workflow majors for review,
because Renovate marks every major as breaking.

Updates in `.github/workflows/release.yml` and `.github/actions/**`,
other than runner images, wait for review under either preset,
because a release job runs them beside its publishing credential.
Renovate can't tell which workflows call a composite action, so CI-only
updates to a shared setup action wait too. To hold another file a
release job runs, see [Release jobs](#release-jobs).

### Minor updates

The `automerge-minor` preset merges minor, patch, and pin updates, and
lock file maintenance. Updates the versioning scheme marks as breaking,
such as a semver 0.x minor, still wait for review.

Extend it only when required checks on every PR catch a broken
dependency update. A scheme without a breaking-change rule, such as
`loose` or `regex`, treats only majors as breaking, so its 0.x minors
merge on checks alone.

Renovate marks every 0.x update as breaking, patches included. The
exception is `prek`: the preset merges its patch updates wherever a
repository pins it. Minor updates to `prek` wait for review.

A repository that pins `prek` needs a required check that runs
`prek run --all-files`, since only that check catches a broken patch.
Without one, set `automerge: false` for `prek` in the repository's
`renovate.json`.

### Workflow majors

The `automerge-workflow-majors` preset merges major updates to runner
images, GitHub Actions, and pre-commit hooks. Other majors still wait
for review.

Extend it only when a required check on every PR runs each workflow
these updates touch. Otherwise a major in a workflow no PR runs, such
as a deploy, first runs after merge, on the default branch.

### Bundled dependencies

The `hold-bundled-dependencies` preset holds runtime dependency
updates for review under either automerge preset. Extend it when the
repository's package bundles its runtime dependencies and so ships
their code. It covers npm, Cargo, Poetry, and PEP 621 runtime
dependencies; lock file maintenance still automerges.

### Release jobs

The `hold-release-job` preset holds updates in the file it names for
review, other than runner images. Extend it for each file a release job
runs that the default preset doesn't hold, such as a deploy workflow:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "github>alunduil/renovate-config",
    "github>alunduil/renovate-config:automerge-minor",
    "github>alunduil/renovate-config:hold-release-job(.github/workflows/cd.yml)"
  ]
}
```

List it after the automerge presets. Listed before
`automerge-workflow-majors`, it lets majors in the file merge.

Name one path or glob per entry, and add an entry for each further
file. Renovate splits the argument at commas, so a list or a
`{a,b}` glob holds nothing.

A `packageRules` entry in the repository's `renovate.json` that turns
automerge on overrides this hold and the default one.

## Update GHC in a Haskell library

Extend the `haskell` preset beside the default:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "github>alunduil/renovate-config",
    "github>alunduil/renovate-config:haskell"
  ]
}
```

Renovate opens a PR when GHC releases a patch for an exact version in
a cabal file's `tested-with`. It ignores wildcards and ranges. Workflow
variables annotated with `depName=ghc/ghc` update the same way.

Updates stay within a series: `9.12.2` can become `9.12.4`, never
`9.14.1`. Add a new series to `tested-with` yourself.

Each update is a patch, so `automerge-minor` merges it once checks
pass.

## What changes for a consuming repository

- Update PRs wait until a release is three days old. Pins, digests,
  and lock file maintenance carry no release date, so they skip the
  wait.
- Releases from registries that publish no dates, such as Hackage,
  also skip the wait. The Dependency Dashboard lists this as a warning
  under Repository Problems.
- Automerge PRs merge once the branch ruleset's required checks pass,
  whatever other checks report. Keep automerge off in a repository
  without required checks.
- Renovate pins GitHub Actions and Docker images, dev container images
  included, to digests. Dev container features keep their tags because
  the dev container CLI rejects a feature pinned by tag and digest.
- A `# renovate: datasource=… depName=…` comment above a `*_VERSION`
  variable in a workflow or action file lets Renovate update that
  version.
- Pre-commit hook updates, OSV vulnerability alerts, and weekly lock
  file maintenance are on.
- Renovate changes the files `mise lock` writes under `.mise/locks/`
  only together with `mise.lock`, which records their digest.
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
