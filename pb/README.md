# `pb` — the amoebius pre-binary host-assertion CLI

`pb` is the only amoebius program that runs before an amoebius binary exists. It asserts the
per-substrate floor, ensures the Haskell toolchain, builds `exe:amoebius`, and replaces itself with
it. Everything richer belongs to the binary, because the no-environment / no-`PATH` contract cannot
begin until there is a binary to enforce it.

The contract is
[`documents/engineering/substrate_doctrine.md` §6](../documents/engineering/substrate_doctrine.md#6-the-bootstrap-coordinator-contract-a-python-cli-ensures-a-toolchain-builds-the-binary-hands-off);
the floor it asserts is
[§3.1](../documents/engineering/substrate_doctrine.md#31-the-per-substrate-floor-what-only-the-operator-can-supply).
The plan that delivers it is
[Phase 3](../DEVELOPMENT_PLAN/phase_50_host_assert_cli.md).

## Install

`pb` is a distribution, installed with `pipx` so its dependencies live in their own environment and
never enter a project's:

```
pipx install ./pb
```

## Development

Every command runs from `pb/`, and `check_code` and `test_all` are modules rather than commands on
`PATH`, so there is exactly one supported way to run each:

```
poetry install
poetry run python -m pb.check_code    # ruff, then black --check, then mypy strict; fail-fast
poetry run python -m pb.test_all      # the suite under branch coverage, floor 100
```

`pytest` is deliberately not a supported entry point: `test/spec/pb/conftest.py` refuses a run that
did not come through `pb.test_all`, so the suite always runs with one configuration.

## Surface

The command topology is closed and enumerable, and it is joined in both directions against
`test/oracle/host_assert_cli_surfaces.tsv` by `tools/host_assert_cli_gate.py`. An unknown verb is a
refusal rather than a guess.
