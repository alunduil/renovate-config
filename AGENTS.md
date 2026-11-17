# renovate-config

The shared Renovate preset for alunduil's repositories. Each JSON file at
the root except `renovate.json` is a preset. `renovate.json` configures
Renovate on this repository.

## A preset change reaches consumers unreviewed

A change merged to `default.json` reaches every consuming repository on
its next Renovate run, with no PR in any of them. A change to an opt-in
preset reaches every repository that extends it. Consumers extend
`github>alunduil/renovate-config` and its named presets without a tag,
so they float on `main`. The repository cuts no releases.

## Validate presets

Run `renovate-config-validator` with `--strict --no-global`. Without
`--no-global`, it validates each file passed by path as self-hosted
global config. The pre-commit hook passes both flags:

```bash
pre-commit run --all-files
```

The validator leaves presets in `extends` unresolved, so a misspelt
preset name passes locally and fails on the next Renovate run.

## Update the README with each preset change

Describe what the change does to a consuming repository: which PRs
open, when they merge, what waits for review. Leave the JSON out of the
README.
