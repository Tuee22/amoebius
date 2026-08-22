# Phase 54: Windows: WSL2 and the lifted Linux engine

> **Purpose**: Admit `windows` as a gated substrate — read the firmware fact before anything is installed,
> ensure WSL2, provision an amoebius-owned distro, and evaluate the proven Linux plan inside it unchanged.
> **Read this if**: a Windows host has to reach the Linux engine, or the reboot verdict has to change.

This phase owns the Windows route to the Linux frame: what is read before an install is attempted, what is
installed, what a required reboot means, and where the route stops. It does not own the plan that runs once
the frame exists — that is Phase 52's, and this phase evaluates it rather than restating it — nor the mount
contract and the provider mapping, which
[`substrate_doctrine.md` §4](../documents/engineering/substrate_doctrine.md#4-virtualized-substrates-synthesizing-a-linux-host-where-the-host-is-not-linux)
fixes once for every substrate. Its one prerequisite is [Phase 53](phase_53_apple_engine_bringup.md), which
reached the same frame by the apple route.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/development_plan_phase_model.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/substrates.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 54.1: The firmware and elevation preflight 📋](#sprint-541-the-firmware-and-elevation-preflight-)
- [Sprint 54.2: Ensuring WSL2 through the vendor installer 📋](#sprint-542-ensuring-wsl2-through-the-vendor-installer-)
- [Sprint 54.3: The reboot verdict and the convergent retry 📋](#sprint-543-the-reboot-verdict-and-the-convergent-retry-)
- [Sprint 54.4: The amoebius-owned distro 📋](#sprint-544-the-amoebius-owned-distro-)
- [Sprint 54.5: The lifted Linux plan 📋](#sprint-545-the-lifted-linux-plan-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked pending Phase-53 revalidation. Reopened 2026-08-19 by the generative re-baseline: the artifact, budget, lift, workflow and evidence calculi change what this phase's gate must cover, so any earlier seal is history and no longer presents completion evidence.

---

## Phase Summary

Windows is the one substrate the plan has never gated, and this phase admits it. The retired claim — that no
phase needed to gate it, because a `linux-cuda` host supplies the same lane — confused a **lane** with a
**route**. The lane is identical: a CPU-only Linux frame at `amd64`, the same one every other substrate
synthesizes. The route is not identical, and firmware virtualization, elevation, and the reboot outcome are
route facts. That two substrates supply one lane says nothing about whether either can be reached, so a lane
argument can never retire a route obligation.

The route is three reads, one install, one provision, and one evaluation. Firmware virtualization is read
first, ahead of every install, because a disabled BIOS/UEFI setting is not a software state and nothing
amoebius runs can clear it. Elevation is read next, because the feature install and the hypervisor launch
setting both need administrator rights. WSL2 is then ensured, an amoebius-owned distro is provisioned from
it, and the Linux plan Phase 52 proved is evaluated inside that distro without amendment.

Windows is not a third implementation of the host plan, it is the Linux frame reached by a different route.
Had this gate needed a Windows-specific plan, the kernel would have failed, because a plan that varies with
the route it was reached by is a plan keyed on plumbing. The lift is what makes that claim checkable rather
than aspirational: the step sequence evaluated inside the distro is compared against the sequence Phase 52
recorded, and any divergence is a failure rather than a Windows dialect.

**Phase scope:** one cohesive claim — *a Windows host reaches the same Linux engine the Linux band proved,
by a route that reads firmware before it installs and treats a required reboot as a verdict*. Its sprint
seams are the preflight, the feature install, the reboot verdict, the distro, and the lifted plan. It splits
if a second substrate or a second acceptance register appears.

**Substrate:** `windows` — the route runs only on Windows and no other host can execute it ([§L](development_plan_phase_model.md#l-one-substrate-discipline)).

**Lane:** `linux-cpu/amd64` — the frame runs the parent's natural architecture, which on Windows is always `amd64` ([§L](development_plan_phase_model.md#l-one-substrate-discipline)).

**Register:** 3 — live: a firmware bit, an optional-feature install, and a host reboot are facts about one real machine ([§K](development_plan_phase_model.md#k-honesty-proven--tested--assumed)).

**Depends on:** [Phase 53](phase_53_apple_engine_bringup.md)

**Requires**: `host-floor`

**Gate:** `python3 tools/run_phase_gate.py 54` passes every check named in
[Gate integrity](#gate-integrity), on a Windows host at lane `linux-cpu/amd64`. The phase does not seal until
it is green, and a reboot-required verdict seals nothing.

---

## Gate integrity

The gate is `python3 tools/windows_engine_bringup_gate.py --execute`, and it decides five things about a
live Windows host.


**The firmware fact is read, never inferred.** `VirtualizationFirmwareEnabled` and `HyperVisorPresent` are
read through PowerShell before the first install argv, and each read is recorded with its value and its
position in the transcript. A run that reaches `winget` with no recorded firmware read fails, because an
install attempted against disabled firmware yields a diagnostic about the installer rather than about the
machine, and the operator then debugs the wrong layer.

**A disabled setting is a refusal carrying an instruction.** The refusal names the prerequisite, names
BIOS/UEFI as the place it is cleared, and leaves the host unchanged. The gate re-reads the optional-feature
state after the refusal and compares it to the state before: a refusal that installed something first is a
refusal in name only.

**The reboot verdict is terminal, non-failing, and sealed only by a second run.** No earlier gate in this
plan suite has an outcome that is neither a pass nor a failure, so the verdict is defined here rather than
borrowed. The seal requires a post-reboot re-run that converges, and that re-run must converge *without*
repeating the feature install — the transcript records the argv of both runs, and a second run naming
`winget install` or `wsl --install` is a probe that has stopped probing.

**The plan identity is joined against an independent oracle.**
`test/oracle/windows_engine_bringup_route.tsv` enumerates the route's own steps — the two reads, the
elevation probe, the vendor install, the distro creation — and is authored apart from the reconciler it
checks. The distro-side step sequence is then joined against the sequence Phase 52's gate recorded, in both
directions: a step the Linux plan does not carry, and a step it carries that the distro skipped, are both
failures.

**Every host state the gate cannot create on demand is a committed fixture.** Firmware disabled, a pending
reboot, and an operator distro already present are held as transcripts in
`test/fixture/windows_engine_bringup/`, so a check only a hostile BIOS could otherwise exercise is exercised
on every run.

**The battery is five mutants**, recorded in `test/mutant/registry.tsv`. No two may be caught by the same
check, or the checks are not separating what they claim to:

- a preflight that reports firmware enabled without reading it — reddens the recorded-read check;
- a refusal that continues into `winget install` — reddens the unchanged-host check;
- a reboot-required outcome downgraded to a retry loop — reddens the terminal-verdict check;
- a post-reboot run that repeats the feature install — reddens the convergence check;
- a Windows-conditional step spliced into the distro-side plan — reddens the plan-identity join.

---

- **Extension conformance (§M.13).** `L1`–`L5`, `C1`–`C7`; negatives under `test/negative/windows_engine_bringup/`.

## Doctrine adopted

- [`extension_conformance_doctrine.md`](../documents/engineering/extension_conformance_doctrine.md) — windows: WSL2 and the lifted Linux engine is admitted by satisfying the contract, not by appearing on a list.
- [`substrate_doctrine.md` §4.2 — WSL2 on Windows](../documents/engineering/substrate_doctrine.md#42-wsl2-on-windows):
  the probe order, the vendor installer that enables the optional features so amoebius never toggles them,
  and the required reboot as a first-class outcome.
- [`substrate_doctrine.md` §3.1 — the per-substrate floor](../documents/engineering/substrate_doctrine.md#31-the-per-substrate-floor-what-only-the-operator-can-supply):
  the Windows rows this route evaluates — package-manager root, shell, firmware virtualization, elevation,
  reboot — and the rule that a refusal is a value naming its own remedy.
- [`substrate_doctrine.md` §4 — virtualized substrates](../documents/engineering/substrate_doctrine.md#4-virtualized-substrates-synthesizing-a-linux-host-where-the-host-is-not-linux):
  one Linux frame per substrate, at the parent's natural architecture, with the provider fixed by the
  detected hardware rather than chosen.
- [`testing_doctrine.md` §4 — no skips, fail fast](../documents/engineering/testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact):
  a reboot-required verdict is an outcome the per-run ledger names, never a skipped check reporting success.

---

## Sprints

## Sprint 54.1: The firmware and elevation preflight 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Substrate/Windows/Preflight.hs`
**Blocked by**: none within the phase
**Requires**: `host-floor`
**Independent Validation**: in every transcript the recorded firmware and elevation reads precede the first install argv
**Docs to update**: `documents/engineering/substrate_doctrine.md`

### Objective

Adopt [`substrate_doctrine.md` §3.1](../documents/engineering/substrate_doctrine.md#31-the-per-substrate-floor-what-only-the-operator-can-supply);
evaluate the Windows floor before the route begins, so a host that cannot support the run is told which
prerequisite is missing instead of failing several installs deep on a symptom.

### Deliverables

- A PowerShell-mediated read of `VirtualizationFirmwareEnabled` and `HyperVisorPresent`, taken at an absolute
  path, whose result is a value the route branches on rather than a log line.
- An elevation probe that establishes administrator rights as a fact, because discovering their absence from
  a failed install reports the install's error and not the host's.
- A refusal type carrying the prerequisite id and the remedy that clears it, so a disabled BIOS/UEFI setting
  produces an instruction and not a stack trace.
- A preflight ledger entry per read — the name, the value, and its position in the transcript — because a
  refusal is checkable only when the read behind it is observable.

### Validation

1. No install argv appears in a transcript whose firmware read is absent or later than it.
2. A refusal names the firmware prerequisite, and the optional-feature state after it equals the state before.

### Remaining Work

The whole sprint.

## Sprint 54.2: Ensuring WSL2 through the vendor installer 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Substrate/Windows/Wsl2.hs`
**Blocked by**: Sprint 54.1
**Independent Validation**: the default WSL version reads as 2 and no argv in the transcript toggles an optional feature directly
**Docs to update**: `documents/engineering/substrate_doctrine.md`

### Objective

Adopt [`substrate_doctrine.md` §4.2 — WSL2 on Windows](../documents/engineering/substrate_doctrine.md#42-wsl2-on-windows);
ensure the hypervisor layer through the vendor's own installer, so amoebius carries no direct dependency on
the optional-feature API and inherits the vendor's ordering instead of guessing it.

### Deliverables

- A readiness probe over `wsl --status` and `wsl --list --online` that admits "no installed distributions" as
  ready-to-install and classifies the disabled-virtualization diagnostic as its own case.
- A `winget` acquisition of the WSL package followed by `wsl --install --no-distribution`, which is the call
  that enables `VirtualMachinePlatform` and the Subsystem-for-Linux feature.
- `wsl --set-default-version 2` as an explicit step with its own post-condition read, because a default of 1
  is a different substrate answering to the same command name.
- Every host-boundary invocation routed through PowerShell at an absolute path, which is what keeps the
  no-`PATH` discipline intact where `wsl` is itself the nested-invocation tool.

### Validation

1. The optional features are enabled and no argv names a direct feature-toggle utility.
2. A second run against a host that already has WSL2 issues no install argv at all.

### Remaining Work

The whole sprint.

## Sprint 54.3: The reboot verdict and the convergent retry 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Substrate/Windows/Reboot.hs`
**Blocked by**: Sprint 54.2
**Independent Validation**: the pre-reboot run exits with the reboot verdict and the post-reboot run converges with no install argv
**Docs to update**: `documents/engineering/substrate_doctrine.md`, `DEVELOPMENT_PLAN/README.md`

### Objective

Adopt [`testing_doctrine.md` §4 — no skips, fail fast](../documents/engineering/testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact);
make a required host reboot a terminal, non-failing verdict, so the alternative — a run waiting on a state
only a reboot can produce — never occurs.

### Deliverables

- A three-valued route outcome — converged, refused, reboot-required — each with its own exit code and its
  own ledger entry, because two values force the third into a hang or a lie.
- A reboot-required verdict naming what changed, what the reboot completes, and the one command that resumes
  the route.
- A resumption that re-probes rather than replays: the second run reads the feature state, finds it
  satisfied, and skips the install it would otherwise repeat.
- A ledger record of both runs under one route identity, so the pair is readable as one convergence and not
  as two unrelated attempts.

### Validation

1. The reboot-required exit code is distinct from both success and failure, and the ledger names the change
   the reboot completes.
2. The post-reboot run converges and its argv set contains no install call.

### Remaining Work

The whole sprint.

## Sprint 54.4: The amoebius-owned distro 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Substrate/Windows/Distro.hs`
**Blocked by**: Sprint 54.3
**Independent Validation**: the distro inventory before and after the run differs by exactly the amoebius-owned entry
**Docs to update**: `documents/engineering/substrate_doctrine.md`

### Objective

Adopt [`substrate_doctrine.md` §4 — virtualized substrates](../documents/engineering/substrate_doctrine.md#4-virtualized-substrates-synthesizing-a-linux-host-where-the-host-is-not-linux);
provision the Linux frame as an amoebius-owned distro, so the run neither depends on nor damages whatever the
operator installed for their own reasons.

### Deliverables

- A distro created under one fixed amoebius-owned name from the pinned Ubuntu LTS image, registered as the
  run's frame and never as the host's default.
- A pristine-guest precondition: the frame is newly materialized and its clean preflight recorded before any
  tool is installed into it.
- An inventory of the operator's distros taken before and after, so ownership is a checked property rather
  than a naming convention nothing verifies.

### Validation

1. The distro inventory differs by exactly the amoebius-owned entry, in name and in count.
2. The operator's default distro selection is the same value after the run as before it.

### Remaining Work

The whole sprint.

## Sprint 54.5: The lifted Linux plan 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Substrate/Windows/Lift.hs`, `test/oracle/windows_engine_bringup_route.tsv`
**Blocked by**: Sprint 54.4
**Independent Validation**: the distro-side step sequence joins to the sequence Phase 52's gate recorded, in both directions
**Docs to update**: `documents/engineering/substrate_doctrine.md`, `DEVELOPMENT_PLAN/substrates.md`

### Objective

Adopt [`substrate_doctrine.md` §4](../documents/engineering/substrate_doctrine.md#4-virtualized-substrates-synthesizing-a-linux-host-where-the-host-is-not-linux);
evaluate the proven Linux plan inside the distro unchanged, so Windows contributes a route and not a second
implementation.

### Deliverables

- A frame descent that carries the decoded configuration into the distro instead of re-deriving it there, so
  one value is read on both sides of the boundary.
- The identity join between the distro-side sequence and the recorded Linux sequence, failing on any element
  either side holds alone.
- A refusal to admit a Windows-conditional branch inside the plan: a difference that genuinely belongs to
  Windows belongs to the route, above the frame, where the preceding four sprints put it.

### Validation

1. The two step sequences are equal, and the gate reports the compared sequences rather than an assertion
   that they matched.
2. No plan step reads the host substrate; the substrate is decided before the frame is entered.

### Remaining Work

The whole sprint.

---

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/substrate_doctrine.md` — §4.2 records the implemented probe order, the reboot
  verdict, and the amoebius-owned distro once the route has run end to end on a Windows host.

**Cross-references to add:**
- `DEVELOPMENT_PLAN/substrates.md` — replace the `windows` row's claim that no phase in the range gates it
  with this phase's gate, lane, and validation contract.
- `DEVELOPMENT_PLAN/development_plan_standards.md` — add this phase to the `host-floor` row of the
  `Requires` table, which the floor evaluation here declares.

---

## Related Documents
- [Substrate Doctrine](../documents/engineering/substrate_doctrine.md)
- [Testing Doctrine](../documents/engineering/testing_doctrine.md)
- [Substrates](substrates.md)
- [Phase 50](phase_50_host_assert_cli.md)
- [Phase 53](phase_53_apple_engine_bringup.md)
- [Development Plan](README.md)
