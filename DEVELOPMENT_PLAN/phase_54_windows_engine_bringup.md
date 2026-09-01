# Phase 54: Windows: WSL2 and the lifted Linux engine

> **Purpose**: Admit `windows` as a gated substrate — read the firmware fact before anything is installed,
> ensure WSL2, provision an amoebius-owned distro, and evaluate the independently passed Phase-52 Linux plan
> inside it unchanged; that predecessor gate pass does not yet exist.
> **Read this if**: a Windows host has to reach the Linux engine, or the reboot verdict has to change.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot satisfy a gate through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_55_bootstrap_coordinator_kind.md, DEVELOPMENT_PLAN/substrates.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision — UNRESOLVED](#resource-provision--unresolved)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 54.1: The firmware and elevation preflight](#sprint-541-the-firmware-and-elevation-preflight-)
- [Sprint 54.2: Ensuring WSL2 through the vendor installer](#sprint-542-ensuring-wsl2-through-the-vendor-installer-)
- [Sprint 54.3: The reboot verdict and the convergent retry](#sprint-543-the-reboot-verdict-and-the-convergent-retry-)
- [Sprint 54.4: The amoebius-owned distro](#sprint-544-the-amoebius-owned-distro-)
- [Sprint 54.5: The lifted Linux plan](#sprint-545-the-lifted-linux-plan-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 53, its independent validation, and gate pass; every earlier
gate barrier must also be satisfied in numerical order. Every earlier completion claim and implementation result in this document is historical rather than a current gate result, even
where the surrounding prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

Hardware validation is also prohibited until the hardware-free DSL gate barrier is independently
satisfied and gate-passed.

---

> **Reset contract interpretation.** The phase-specific gate check below is UNRESOLVED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and the complete qualified gate passes, the summary and work breakdown are a capability inventory, not an executable contract. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is historical and non-operative.

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
it, and the future gate-passed Phase-52 Linux plan must be evaluated inside that distro without amendment.

Windows is not a third implementation of the host plan, it is the Linux frame reached by a different route.
Had this gate needed a Windows-specific plan, the kernel would have failed, because a plan that varies with
the route it was reached by is a plan keyed on plumbing. The lift is what makes that claim checkable rather
than aspirational: the step sequence evaluated inside the distro must be compared against the sequence bound
to Phase 52's future gate pass, and any divergence is a failure rather than a Windows dialect.

**Phase scope:** one cohesive target claim — *a Windows host reaches the same Linux engine Phase 52 must establish,
by a route that reads firmware before it installs and treats a required reboot as a verdict*. Its sprint
seams are the preflight, the feature install, the reboot verdict, the distro, and the lifted plan. It splits
if a second substrate or a second acceptance register appears.

**Substrate:** `windows` — the route runs only on Windows and no other host can execute it ([§L](development_plan_phase_model.md#l-one-substrate-discipline)).

**Lane:** `linux-cpu/amd64` — the frame runs the parent's natural architecture, which on Windows is always `amd64` ([§L](development_plan_phase_model.md#l-one-substrate-discipline)).

**Register:** 3 — live: a firmware bit, an optional-feature install, and a host reboot are facts about one real machine ([§K](development_plan_phase_model.md#k-honesty-proven--tested--assumed)).

**Depends on:** [Phase 53](phase_53_apple_engine_bringup.md)
**Gate:** `pb validate phase 54`; see [Gate integrity](#gate-integrity).

## Gate integrity

**Contract check**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: one cohesive target claim — *a Windows host reaches the same Linux engine Phase 52 must establish, by a route that reads firmware before it installs and treats a required reboot as a verdict*. Its sprint seams are the preflight, the feature install, the reboot verdict, the distro, and the lifted plan. It splits if a second substrate or a second acceptance register appears. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: `pb validate phase 54` is the target command only; `pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec it with argv unchanged, while the Haskell verdict entry point remains UNRESOLVED and blocks validation. |
| `Oracle` | UNRESOLVED — blocks validation: no separately authored `.hs` oracle, independence boundary, provenance have been established. |
| `Positive controls` | UNRESOLVED — blocks validation: no closed named Haskell corpus and exact per-member observations have been accepted. |
| `Paired negatives` | UNRESOLVED — blocks validation: minimally different pairs, exact rejection loci, and exact reasons have not yet been demonstrated by a passing gate for every foreclosed dimension. |
| `Mutants` | UNRESOLVED — blocks validation: operators, production loci, applied-change witnesses, expected red observations, and unaffected controls have not yet been demonstrated by a passing gate. |
| `Discovery` | UNRESOLVED — blocks validation: expected and runtime-discovered surfaces, two-way equality, and empty-discovery refusal have not yet been demonstrated by a passing gate. |
| `Challenge` | UNRESOLVED — blocks validation: neither a post-start challenge nor a checked pure-claim independent predicate has been accepted. |
| `Observer` | UNRESOLVED — blocks validation: no outside observer, raw observation, authenticity check, and fail-closed rule have been accepted. |
| `Authority/bypass` | UNRESOLVED — blocks validation: least-privilege/foreign-scope pairs, bypass probes, or checked non-applicability have not yet been demonstrated by a passing gate. |
| `Freshness` | UNRESOLVED — blocks validation: stale state, cached output, prior evidence, and replayed responses have not been made unable to pass. |
| `Qualification` | UNRESOLVED — blocks validation: the fixed sabotage corpus has not qualified a Haskell harness independently of a clean candidate run. |
| `Cleanroom` | UNRESOLVED — blocks validation: no run has derived all products lazily with generated and condemned legacy copies absent. |
| `Legacy closure` | UNRESOLVED — blocks validation: stable owned legacy IDs and their exact zero-finding check have not been reconciled. |
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: Exact `ImmediatePredecessorPass` for Phase 53; candidate execution refuses an absent, stale, replayed, or different-source result. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Pass criterion` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: `qualified-gate-pass` — every required gate row must succeed in one qualified run for the exact current source; that complete pass is sufficient for the status-only transition. |

## Resource provision — UNRESOLVED

> **UNRESOLVED — blocks validation.** No live mutation may begin. Before check this phase must name its exact owner marker, preflight, allowed and forbidden mutations, external observer, scoped cleanup, and zero-owned-residue criterion. The reset inventory below cannot supply that contract.

## Doctrine adopted

- [`extension_conformance_doctrine.md` §5 — The conformance gate is generated, not authored](../documents/engineering/extension_conformance_doctrine.md#5-the-conformance-gate-is-generated-not-authored) — windows: WSL2 and the lifted Linux engine is admitted by satisfying the contract, not by appearing on a list.
- [`substrate_doctrine.md` §4.2 — WSL2 on Windows](../documents/engineering/substrate_doctrine.md#42-wsl2-on-windows):
  the probe order, the vendor installer that enables the optional features so amoebius never toggles them,
  and the required reboot as a first-class outcome.
- [`substrate_doctrine.md` §3.1 — The per-substrate floor: what only the operator can supply](../documents/engineering/substrate_doctrine.md#31-the-per-substrate-floor-what-only-the-operator-can-supply):
  the Windows rows this route evaluates — package-manager root, shell, firmware virtualization, elevation,
  reboot — and the rule that a refusal is a value naming its own remedy.
- [`substrate_doctrine.md` §4 — Virtualized substrates: synthesizing a Linux host where the host is not Linux](../documents/engineering/substrate_doctrine.md#4-virtualized-substrates-synthesizing-a-linux-host-where-the-host-is-not-linux):
  one Linux frame per substrate, at the parent's natural architecture, with the provider fixed by the
  detected hardware rather than chosen.
- [`testing_doctrine.md` §4 — No skips, fail fast, and the per-run ledger artifact](../documents/engineering/testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact):
  a reboot-required verdict is an outcome the per-run ledger names, never a skipped check reporting success.

---

## Sprints

> **Reset validation check.** Every pre-reset `Independent Validation` and `### Validation` below is historical context rather than a current criterion. It is retained only to inventory the capability while the fixed Haskell subject/oracle/mutant/legacy contract is rewritten.

## Sprint 54.1: The firmware and elevation preflight ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: [Phase 53](phase_53_apple_engine_bringup.md) gate pass
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

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

## Sprint 54.2: Ensuring WSL2 through the vendor installer ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: Sprint 54.1
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

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

## Sprint 54.3: The reboot verdict and the convergent retry ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: Sprint 54.2
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

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

## Sprint 54.4: The amoebius-owned distro ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: Sprint 54.3
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

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

## Sprint 54.5: The lifted Linux plan ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: Sprint 54.4
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

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

**Engineering docs to update (after the complete gate passes):**

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
