# Phase 50: The `pb` host-assertion CLI

> **Purpose**: Deliver the one pre-binary tool amoebius owns — a Python CLI that asserts the host floor
> idempotently, builds `exe:amoebius`, and hands off — and prove it does nothing else.
> **Read this if**: a bare host has to reach a built amoebius binary, or the `pb` command surface has to change.

This phase owns the pre-binary boundary: what `pb` asserts, what it builds, and where it stops. It does not
own anything the binary does after the handoff — the ensure algebra is
[Phase 51](phase_51_host_ensure_kernel.md)'s and every later host action is the binary's, as
[`substrate_doctrine.md` §6](../documents/engineering/substrate_doctrine.md#6-the-bootstrap-coordinator-contract-a-python-cli-ensures-a-toolchain-builds-the-binary-hands-off)
fixes. Its one prerequisite is the target tree [Phase 2](phase_02_repository_layout_conformance.md) moved.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_51_host_ensure_kernel.md, DEVELOPMENT_PLAN/phase_52_linux_engine_bringup.md, DEVELOPMENT_PLAN/phase_54_windows_engine_bringup.md, documents/engineering/substrate_doctrine.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 50.1: The Poetry distribution and its quality gate ✅](#sprint-501-the-poetry-distribution-and-its-quality-gate-)
- [Sprint 50.2: The closed command topology ✅](#sprint-502-the-closed-command-topology-)
- [Sprint 50.3: The idempotent host assertions ✅](#sprint-503-the-idempotent-host-assertions-)
- [Sprint 50.4: Build and hand off ✅](#sprint-504-build-and-hand-off-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done — sealed 2026-08-22. The workflow-routed eleven-sided gate passes on natural `arm64`, untranslated:
the Poetry/Click quality floor is green at 100% branch coverage; all 36 command, check and mutant surfaces
join; the fake-host replay converges once and mutates nothing thereafter; all four seeded defects redden
their exact checks; and the gate leaves both the authored tree and the outside-host inventory unchanged. Its
fresh tool environment is contained beneath `.build/toolchain/host_assert_cli/`, including Poetry and pip
caches. Attestation `sha256:452fc0ad35e56526c952558ff578a5fa175a00856f6af20b885630befda86ace`
binds source `sha256:48c9e75353198eb4…` over 2,318 files. Phase 51 is now the sole open contract.

Reopened 2026-08-19 by the generative re-baseline: the artifact, budget, lift, workflow and evidence calculi
change what this phase's gate must cover, so any earlier seal is history and no longer presents completion
evidence.

The run found four defects in this phase's own work, each now fixed and covered: the escape-hatch scan
decoded `.pyc` bytecode as UTF-8; it also reported prose that merely *named* a banned construct, which
made the rule unstatable in the module that states it; `linux-cuda`'s floor was read as forking
`linux-cpu`'s rather than extending it; and `available_memory` used `SC_AVPHYS_PAGES`, which Darwin
does not define — so the capacity admission was Linux-only and undecidable on two catalogue members.

---

## Phase Summary

`pb` is the only amoebius program that runs before an amoebius binary exists, and the whole design pressure
on it is to stay small. It asserts the per-substrate floor — the package-manager root, a hardware or firmware
fact, a credentialed account — resolves GHCup, GHC and Cabal, builds `exe:amoebius`, and replaces itself with
it. Everything richer is the binary's, because the no-environment, no-`PATH` contract cannot begin until
there is a binary to enforce it.

What this phase adds beyond today's package is rigour rather than reach. `pb` is currently an `argparse` CLI
under a bare setuptools `pyproject.toml` with no type checker, no formatter, no linter and no test suite
configured anywhere in the repository. This phase gives it a Poetry distribution installed with `pipx`, a
closed Click command topology, an explicit self-update surface, and a quality gate that runs before anything
it produces is trusted.

**Phase scope:** one cohesive claim — *the pre-binary assertions are idempotent, the command surface is
closed, and the handoff is the program's last act*. Its sprint seams are the distribution, the topology, the
assertions, and the handoff. It splits if a second acceptance register or a second substrate appears.

**Substrate:** `none` — the assertions run against a committed fake-host boundary, not a host ([§L](development_plan_phase_model.md#l-one-substrate-discipline)).

**Lane:** none ([§L](development_plan_phase_model.md#l-one-substrate-discipline)).

**Register:** 2 — boundary-with-fakes: the claim is about a tool boundary, not about a value ([§K](development_plan_phase_model.md#k-honesty-proven--tested--assumed)).

**Depends on:** [Phase 2](phase_02_repository_layout_conformance.md)

**Requires**: `host-floor`

**Gate:** `python3 tools/run_phase_gate.py 50` passes every check named in
[Gate integrity](#gate-integrity). Phase 51 does not open until it is green.

---

## Gate integrity

The gate is `python3 tools/host_assert_cli_gate.py`, and it decides four things that are checkable without a
host.


**The quality floor is a precondition, not a report.** `poetry run python -m pb.check_code` runs `ruff`,
then `black --check`, then `mypy` under `strict` with `disallow_any_explicit`, fail-fast in that order; and
`poetry run python -m pb.test_all` runs the suite at 100% branch coverage. A violation aborts the gate before
any assertion is exercised, because a style or typing failure should cost seconds rather than a full run.

**Idempotence is proved by replay against a committed fixture, not asserted.** Each assertion is driven
through an absent → present → present transcript held in `test/fixture/host_assert_cli/`. The first run must
converge, the second must report converged, and the second must mutate nothing — the transcript records
every argv the run issued, and an empty mutation set on the second pass is the property.

**The command surface is closed and the oracle is independent.** `test/oracle/host_assert_cli_surfaces.tsv`
enumerates every command, its options, and whether it is maintainer-only; the gate joins the parser's own
introspection against it in both directions, so a command the oracle does not name and an oracle row no
command implements are both failures. An unknown verb resolves to no command.

**Four seeded mutants must redden**, each at its own check and no other, registered in
`test/mutant/registry.tsv`: an assertion that reports converged without probing; an assertion whose second
run mutates; an invocation that names a bare command instead of an absolute path; and a run that continues
past a floor refusal.

---

- **Extension conformance (§M.13).** `L1`–`L5`, `C1`–`C7`; negatives under `test/negative/host_assert_cli/`.

## Doctrine adopted

- [`extension_conformance_doctrine.md`](../documents/engineering/extension_conformance_doctrine.md) — the `pb` host-assertion CLI is admitted by satisfying the contract, not by appearing on a list.
- [`substrate_doctrine.md` §6 — the bootstrap coordinator contract](../documents/engineering/substrate_doctrine.md#6-the-bootstrap-coordinator-contract-a-python-cli-ensures-a-toolchain-builds-the-binary-hands-off):
  one Python CLI, two modes, no shell script, and a handoff that does not return.
- [`substrate_doctrine.md` §3.1 — the per-substrate floor](../documents/engineering/substrate_doctrine.md#31-the-per-substrate-floor-what-only-the-operator-can-supply):
  the three classes that belong to the floor, and the rule that anything with a supported install plan is
  ensured rather than written down as a manual prerequisite.
- [`testing_doctrine.md` §4 — no skips, fail fast](../documents/engineering/testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact):
  a skipped assertion that reports success misrepresents coverage, so the suite carries no skip and no
  expected failure.

---

## Sprints

## Sprint 50.1: The Poetry distribution and its quality gate ✅
**Status**: Done
**Implementation**: `pb/pyproject.toml`, `pb/poetry.toml`, `pb/pb/check_code.py`, `pb/pb/test_all.py`, `pb/pb/narrow.py`, `pb/stubs/`, `test/spec/pb/`
**Blocked by**: none within the phase
**Requires**: `host-floor`
**Independent Validation**: `poetry run python -m pb.check_code` exits 0 over `pb` and `stubs`; `poetry run python -m pb.test_all` reports 100% branch coverage
**Docs to update**: `documents/engineering/substrate_doctrine.md`

### Objective

Adopt [`substrate_doctrine.md` §6](../documents/engineering/substrate_doctrine.md#6-the-bootstrap-coordinator-contract-a-python-cli-ensures-a-toolchain-builds-the-binary-hands-off);
give `pb` a distribution a consumer installs rather than a directory a consumer runs.

### Deliverables

- A Poetry `pyproject.toml` declaring the runtime dependencies and a `pb` console script; `poetry.toml`
  pinning the virtualenv in-project, which is what makes an environment check meaningful.
- `mypy` under `strict` with `disallow_any_explicit`, `warn_unused_ignores`, `warn_redundant_casts` and
  `warn_return_any`; `ruff` and `black` at one line length; `pytest` with a coverage floor of 100.
- `check_code` and `test_all` as module entry points, so there is exactly one supported way to run each.
- A `stubs/` directory on `mypy_path`, linted and formatted but not type-checked.

### Validation

1. Every `dict[str, Any]` at a JSON boundary is replaced by `object` plus an explicit narrowing helper
   (`pb/pb/narrow.py`), and `disallow_any_explicit` passes with no suppression. `mypy` cannot see a
   `cast` or a `# type: ignore`, so `check_code` scans the token stream for all three: the ban is
   enforced rather than configured.
2. Invoking `pytest` directly is refused; the runner is the only supported entry.

### Remaining Work

None.

## Sprint 50.2: The closed command topology ✅
**Status**: Done
**Implementation**: `pb/pb/cli.py`
**Blocked by**: Sprint 50.1
**Independent Validation**: the parser's introspection joins to `test/oracle/host_assert_cli_surfaces.tsv` in both directions
**Docs to update**: `documents/engineering/substrate_doctrine.md`

### Objective

Fix the command surface so that it is enumerable, and so that an unknown verb is a refusal rather than a
guess.

### Deliverables

- A Click group whose commands are registered at import: the consumer surface, and a maintainer surface that
  resolves to nothing outside this checkout's development environment.
- One pass-through command that stops option parsing at the first non-option token and forwards the
  remainder verbatim to the built binary.
- A friendly-error layer that turns a known failure class into one actionable line rather than a traceback.
- An explicit `update` command; nothing else consults or mutates the installation.

### Validation

1. An unknown verb produces `No such command`.
2. A maintainer command is absent from `--help` and unresolvable outside the development environment, and
   re-checks its authority in its own body.

### Remaining Work

None.

## Sprint 50.3: The idempotent host assertions ✅
**Status**: Done
**Implementation**: `pb/pb/prereqs.py`, `pb/pb/process.py`, `test/fixture/host_assert_cli/`, `test/harness/host_assert_cli/`
**Blocked by**: Sprint 50.2
**Independent Validation**: the absent → present → present replay converges once and mutates nothing thereafter
**Docs to update**: `documents/engineering/substrate_doctrine.md`

### Objective

Adopt [`substrate_doctrine.md` §3.1](../documents/engineering/substrate_doctrine.md#31-the-per-substrate-floor-what-only-the-operator-can-supply);
assert the floor and ensure the Haskell toolchain, and nothing beyond either.

### Deliverables

- One subprocess choke point: argv only, never a shell; an environment overlaid rather than replaced; output
  mirrored live and captured at once so a failure can be classified after the fact.
- A floor check per substrate that refuses with the remediation instruction rather than a bare failure.
- A pinned, digest-verified GHCup acquisition; no installer is piped to a shell.

### Validation

1. Every assertion is a probe followed by an action, and the probe is also the post-condition.
2. A failed floor check names what to do about it.

### Remaining Work

None.

## Sprint 50.4: Build and hand off ✅
**Status**: Done
**Implementation**: `pb/pb/bootstrap.py`
**Blocked by**: Sprint 50.3
**Independent Validation**: the built binary lands at one stable path and the program does not return
**Docs to update**: `documents/engineering/substrate_doctrine.md`, `DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md`

### Objective

Build `exe:amoebius` host-native and replace the Python process with it, so that the pre-binary boundary
closes at a single observable point.

### Deliverables

- A repo-local build whose output is copied to one stable path only when its bytes changed.
- A handoff that `exec`s on POSIX and propagates the child's exit code on Windows, with the difference stated
  rather than papered over.

### Validation

1. The binary path is absolute and the handoff refuses a relative one.
2. A second invocation with unchanged sources performs no copy.

### Remaining Work

None.

---

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/substrate_doctrine.md` — §6 records the distribution, the `update` surface, and the
  closed topology once they exist.
- `documents/engineering/repository_layout_doctrine.md` — §6 and §7 gain the ignore rule for the
  distribution's in-project virtualenv, which is the artifact class this phase creates.

**Cross-references to add:**
- `DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md` — retire the row recording that `pb` is an `argparse`
  CLI with no configured quality tooling, and record what the module split condemns.

---

## Related Documents
- [Substrate Doctrine](../documents/engineering/substrate_doctrine.md)
- [Testing Doctrine](../documents/engineering/testing_doctrine.md)
- [Phase 51](phase_51_host_ensure_kernel.md)
- [Development Plan](README.md)
