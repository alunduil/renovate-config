# Automerge policy

An update a repository opts in to automerges once required checks
pass, unless it changes what a release runs or ships. No check on the
pull request sees those changes, so they wait for review.

This page is for maintainers of a repository that extends the preset
and want to know why an update waited. The README covers how to
extend the automerge presets.

## What automerges

With `automerge-minor` and `automerge-workflow-majors` extended, these
merge once required checks pass:

- Minor, patch, and pin updates the versioning scheme doesn't mark as
  breaking.
- Lock file maintenance.
- Major updates to GitHub Actions, runner images, and pre-commit hooks
  outside a release job.

## What waits

These wait for review under either automerge preset:

- Other breaking updates, including other majors.
- Updates in `.github/workflows/release.yml` and in the composite
  actions under `.github/actions/`, except runner images.
- Runtime dependencies, in a repository that extends
  `hold-bundled-dependencies`.

Renovate updates a dependency in every file that uses it in one pull
request, and merges that pull request only if every file's update
automerges. An action used in both `ci.yml` and `release.yml`
therefore waits.

## Why release jobs wait

A release job holds a credential, such as an account token for
release-please or a trusted-publishing identity for PyPI. Every action
and tool in the job runs beside it. A compromised release of one, or a
tag repointed to new code, reaches the credential on the first release
after the update merges.

Digest updates skip the three-day release wait, and a changed digest
on a tag-pinned action is what a repointed tag looks like. Without the
hold, one could merge within hours.

The hold covers every composite action under `.github/actions/`.
Renovate can't tell which workflows call an action, so setup actions
shared by CI and release jobs also wait.

Runner images still automerge. GitHub supplies both the image and the
OIDC token the release job publishes with, so trusting the token
already means trusting GitHub's images. A runner update also touches
every workflow at once, so holding it would hold the repository's
whole CI.

## Why bundled dependencies wait

A package that bundles its runtime dependencies ships their code, and
the release approval reviews only the package's own changes. The
default preset can't tell which packages bundle, so the hold is
opt-in.

The hold covers npm, Cargo, Poetry, and PEP 621 runtime dependencies.
Runtime dependencies in other ecosystems, development dependencies,
and lock file maintenance still automerge. Lock file maintenance can
change the versions of a bundled dependency's own dependencies.
