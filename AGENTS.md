# renovate-config

The shared Renovate preset for alunduil's repositories. Each JSON file at
the root except `renovate.json` is a preset; `renovate.json` configures
Renovate on this repository itself.

## A preset change reaches consumers unreviewed

A change merged to `default.json` reaches every consuming repository on
its next Renovate run, with no PR in any of them. A change to an opt-in
preset reaches every repository that extends it. Consumers extend
`github>alunduil/renovate-config` (or a named preset such as
`:application`) without a tag, so they float on `main`. The repository
cuts no releases.

## Validate presets

Run the validator with `--strict --no-global`. Without `--no-global`,
`renovate-config-validator` checks a named file as self-hosted global
config, not repository config. The pre-commit hook already passes both
flags:

```bash
pre-commit run --all-files
```

The validator leaves presets in `extends` unresolved, so a misspelt
preset name passes locally and fails only on the next Renovate run.

## Document effects, not JSON

The README describes what a preset changes for a consuming repository:
which PRs open, when they merge, what waits for review. Update the
matching README section with every user-visible preset change.
