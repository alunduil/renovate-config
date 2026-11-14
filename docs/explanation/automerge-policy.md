# Automerge policy

An update automerges when its pull request's checks can show it is
safe. It waits for review when it changes what a release runs or
ships, because no check on the pull request sees that.

This page is for maintainers of a repository that extends the preset
and wonders why an update waited. The README covers how to extend the
automerge presets.

## What automerges

With `automerge-minor` and `automerge-workflow-majors` extended, these
merge once required checks pass:

- Minor, patch, and pin updates the versioning scheme doesn't mark as
  breaking.
- Lock file maintenance.
- Major updates to GitHub Actions, runner images, and pre-commit hooks
  outside a release job.

A repository opts in to each preset separately, so an update merges
only if the repository asked for its kind.

## What waits

These wait for review whichever automerge presets the repository
extends:

- Breaking updates, majors included, other than the workflow majors
  above.
- Updates in `.github/workflows/release.yml` and in the composite
  actions under `.github/actions/`, other than runner images.
- Runtime dependencies, in a repository that extends
  `hold-bundled-dependencies`.

Renovate automerges a branch only when every update in it automerges.
An action that `ci.yml` and `release.yml` both use updates in one
branch, so the hold on `release.yml` holds the `ci.yml` change too.

## Why release jobs wait

A release job holds a credential: an account token for
release-please, or a trusted-publishing identity for PyPI. Every
action and tool the job runs runs beside that credential. A
compromised release of one of them, or a tag repointed to new code,
reaches the credential the first time the release job runs, which is
after the update merged.

Digest updates make this sharper. A tag-pinned action's digest
changing is what a repointed tag looks like, and digests skip the
three-day release wait. Without the hold, such an update could merge
within hours.

The hold covers every composite action under `.github/actions/`, not
only those the release job calls. Renovate can't tell which workflows
call an action, so setup actions shared between CI and release also
wait.

Runner images automerge anyway. GitHub supplies both the image and the
OIDC token a release job publishes with, so a review of the image adds
nothing to the trust the token already needs. A runner update also
touches every workflow at once, so holding it would hold a
repository's whole CI.

## Why bundled dependencies wait

A package that bundles its runtime dependencies ships their code. The
release approval reviews the package's own changes, not the code
inside an updated dependency, so a merged dependency update ships
unreviewed.

The default preset can't tell which packages bundle, so the hold is
opt-in. It matches the dependency types Renovate gives runtime
dependencies: `dependencies` for npm, Cargo, and Poetry, and
`project.dependencies` for PEP 621. Development dependencies and lock
file maintenance still automerge. Lock file maintenance can move a
bundled dependency's transitive versions; the hold leaves that open
in exchange for an unattended weekly lock file update.
