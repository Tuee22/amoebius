# Phase 51: The host-ensure kernel

> **Purpose**: Move every host assertion after the handoff into one closed, substrate-indexed algebra whose
> install steps are typed data, with algebraic totality as the target claim.
> **Read this if**: a host tool has to be ensured, a substrate arm has to be added, or a step has to run inside
> a frame rather than on the host.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot regain authority through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_50_host_assert_cli.md, DEVELOPMENT_PLAN/phase_52_linux_engine_bringup.md, DEVELOPMENT_PLAN/phase_53_apple_engine_bringup.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/substrate_doctrine.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision — UNRESOLVED](#resource-provision--unresolved)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 51.1: The closed substrate algebra ⏸️](#sprint-511-the-closed-substrate-algebra-)
- [Sprint 51.2: Install steps as typed data ⏸️](#sprint-512-install-steps-as-typed-data-)
- [Sprint 51.3: The reconciler table ⏸️](#sprint-513-the-reconciler-table-)
- [Sprint 51.4: The probe-first ensure driver ⏸️](#sprint-514-the-probe-first-ensure-driver-)
- [Sprint 51.5: The lift fold to argv ⏸️](#sprint-515-the-lift-fold-to-argv-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 50, its independent validation, and delegated promotion; every earlier
promotion barrier must also be satisfied in numerical order. Every prior pass, seal, receipt, attestation,
completion claim, and implementation result in this document is invalidated as validation evidence, even
where historical prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

---

> **Reset contract interpretation.** The phase-specific gate review below is REJECTED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and an authorized reviewer independently inspects it, the summary and work breakdown are a capability inventory, not executable authority. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is invalidated and non-operative.

## Phase Summary

The binary takes over every assertion the moment [Phase 50](phase_50_host_assert_cli.md) execs it, and the
pressure on this phase is that the takeover happens once, in one place. One table answers which frame a
substrate supplies and which engine that frame supplies. One type describes an install step. One driver
executes a plan, and one fold turns a lift context into the argv that runs a step inside it. A second
spelling of any of the four is the defect the future phase gate must make unconstructable.

That foreclosure is a typing obligation rather than a testing one. "Install Docker twice on Apple"
and "no Linux frame on Windows" must not be values the target algebra can build. The map from substrate to
frame must be total and closed, with no default arm to absorb a member nobody considered. A test can only
observe the cases someone thought to write down; the future gate must establish that a total map without a
wildcard refuses to compile when a case goes missing.

What the tree carries today is a declared substrate story with no interpreter behind it.
`installAndVerify` has zero callers, and `pristineLinuxProvider` is consumed only by two specs.
`Cluster/Bootstrap.hs` refuses `apple` and `windows` outright rather than entering their frames; `HostTool`
has five constructors and no Docker arm; and `installMechanism :: String` in `src/Amoebius/Host/Ensure.hs`
holds values like `brew-install:ghcup` that nothing parses and nothing executes. The plan is pure and
uninterpretable at the same time, and that pairing is what the future phase gate must close.

**Phase scope:** one cohesive claim — *every post-handoff host assertion resolves through one closed,
substrate-indexed algebra whose install steps are typed data*. Its sprint seams are the algebra, the step
type, the reconciler table, the driver, and the lift fold. It splits if a second acceptance register or a
second substrate appears.

**Substrate:** `none` — Haskell declarations generate a fresh run-local fake tool directory beneath
`.build/**`; it is never retained in the repository and the algebra is replayed against it, not a host
([§L](development_plan_phase_model.md#l-one-substrate-discipline)).

**Lane:** none ([§L](development_plan_phase_model.md#l-one-substrate-discipline)).

**Register:** 2 — boundary-with-fakes: the claim is about tool resolution and emitted argv, not about a value ([§K](development_plan_phase_model.md#k-honesty-proven--tested--assumed)).

**Depends on:** [Phase 50](phase_50_host_assert_cli.md)
**Gate:** `pb validate phase 51`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract review**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: one cohesive claim — *every post-handoff host assertion resolves through one closed, substrate-indexed algebra whose install steps are typed data*. Its sprint seams are the algebra, the step type, the reconciler table, the driver, and the lift fold. It splits if a second acceptance register or a second substrate appears. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `pb validate phase 51` is the target command only; `pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec it with argv unchanged, while the Haskell verdict entry point remains UNRESOLVED and blocks validation. |
| `Oracle` | UNRESOLVED — blocks validation: no separately authored `.hs` oracle, independence boundary, provenance, and independent reviewer have been accepted. |
| `Positive controls` | UNRESOLVED — blocks validation: no closed named Haskell corpus and exact per-member observations have been accepted. |
| `Paired negatives` | UNRESOLVED — blocks validation: minimally different pairs, exact rejection loci, and exact reasons have not been accepted for every foreclosed dimension. |
| `Mutants` | UNRESOLVED — blocks validation: operators, production loci, applied-change witnesses, expected red observations, and unaffected controls have not been accepted. |
| `Discovery` | UNRESOLVED — blocks validation: expected and runtime-discovered surfaces, two-way equality, and empty-discovery refusal have not been accepted. |
| `Challenge` | UNRESOLVED — blocks validation: neither a post-start challenge nor a reviewed pure-claim independent predicate has been accepted. |
| `Observer` | UNRESOLVED — blocks validation: no outside observer, raw observation, authenticity check, and fail-closed rule have been accepted. |
| `Authority/bypass` | UNRESOLVED — blocks validation: least-privilege/foreign-scope pairs, bypass probes, or reviewed non-applicability have not been accepted. |
| `Freshness` | UNRESOLVED — blocks validation: stale state, cached output, prior evidence, and replayed responses have not been made unable to pass. |
| `Qualification` | UNRESOLVED — blocks validation: the fixed sabotage corpus has not qualified a Haskell harness independently of a clean candidate run. |
| `Cleanroom` | UNRESOLVED — blocks validation: no run has derived all products lazily with generated and condemned legacy copies absent. |
| `Legacy closure` | UNRESOLVED — blocks validation: stable owned legacy IDs and their exact zero-finding check have not been reconciled. |
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: Exact external `ImmediatePredecessorApproval` for Phase 50; candidate execution separately refuses an absent, stale, replayed, or locally shaped receipt. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Promotion authority` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `delegated-reviewer` — an authorized human or agent may promote after inspecting the complete qualified candidate; no gate, CI job, digest, receipt-shaped file, or generated assertion may promote by itself. |

## Resource provision — UNRESOLVED

> **UNRESOLVED — blocks validation.** No live mutation is authorized. The owner marker, preflight, complete
> allowed/forbidden mutations, external observer, scoped cleanup, and zero-owned-residue contract are absent.

## Doctrine adopted

- [`extension_conformance_doctrine.md` §5 — The conformance gate is generated, not authored](../documents/engineering/extension_conformance_doctrine.md#5-the-conformance-gate-is-generated-not-authored) — the host-ensure kernel is admitted by satisfying the contract, not by appearing on a list.
- [`substrate_doctrine.md` §3 — the no-environment / no-`PATH` lazy tool-ensure contract](../documents/engineering/substrate_doctrine.md#3-the-no-environment--no-path-lazy-tool-ensure-contract):
  probe, install when absent, resolve the absolute path from the package manager, invoke by that path and
  never by a name the OS searches for.
- [`substrate_doctrine.md` §3 — The no-environment / no-`PATH` lazy tool-ensure contract; “The exact boundary of the no-`PATH` rule”](../documents/engineering/substrate_doctrine.md#the-exact-boundary-of-the-no-path-rule):
  only the outermost tool is resolved, and a nested command is the guest's own name against the guest's own
  environment — which is what makes a single fold over a lift context sufficient.
- [`dsl_doctrine.md` §5 — the illegal-state-unrepresentable contract](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract):
  a state the types cannot express needs no test, and the ensure algebra is where that contract reaches the
  host surface.
- [`testing_doctrine.md` §9 — derivation: generated enumeration, authored expectation](../documents/engineering/testing_doctrine.md#9-derivation-generated-enumeration-authored-expectation):
  the substrate cases are enumerated from the type and every expectation is authored in Haskell, so a new constructor
  arrives with a missing expectation rather than with silent coverage.

---

## Sprints

> **Reset validation review.** Every pre-reset `Independent Validation` and `### Validation` below is rejected as a current criterion and MUST NOT be executed or cited. It is retained only to inventory the capability while the fixed Haskell subject/oracle/reviewer/mutant/legacy contract is rewritten.

## Sprint 51.1: The closed substrate algebra ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: [Phase 50](phase_50_host_assert_cli.md) reviewer approval
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary, and reviewer have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt [`dsl_doctrine.md` §5](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract);
replace the per-site substrate branch with one table that answers frame and engine supply for every catalog
member.

### Deliverables

- A `Frame` sum with three constructors — the native Linux frame, the Lima guest, the WSL2 guest. The package
  manager and the host provider are identical on `linux-cpu` and `linux-cuda`, so a fourth and fifth tag would
  only re-spell an accelerator distinction the ensure surface never reads.
- One total function from `Substrate` to `Frame` and one from `Frame` to the engine it supplies, neither
  carrying a default arm, so an added substrate constructor is a compile error at every site that must answer
  for it.
- Retirement of `supportsLinuxCpu`, which returns `True` for every input and therefore states nothing its own
  type does not already state.
- The accelerator tag confined to the surfaces that read it — capacity and device exposure — and absent from
  the ensure path, since re-spelling the pair at every site is how a new constructor misses a case that reads
  as exhaustive.

### Validation

1. Every `case` over `Substrate` in the host modules is exhaustive and wildcard-free.
2. Adding a constructor to `Substrate` or `Frame` fails the build at each table obliged to answer for it.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 51.2: Install steps as typed data ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: Sprint 51.1
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary, and reviewer have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt [`substrate_doctrine.md` §3](../documents/engineering/substrate_doctrine.md#3-the-no-environment--no-path-lazy-tool-ensure-contract);
make an install step a value the driver executes rather than a label a reader interprets.

### Deliverables

- An `InstallStep` carrying a resolved host tool plus its arguments, replacing `installMechanism :: String`.
  An install step is not a string, it is a tool and an argument vector, and a string is exactly the shape that
  compiles while naming a mechanism no interpreter implements.
- A `Docker` arm on `HostTool`, so the container engine is ensured through the same closed enum as every other
  tool instead of being resolved outside it by a second helper.
- Version and download identity read from the authored requirements rather than embedded in the step, so a pin
  has one home and a bump touches one file.
- One resolver: `Amoebius.Host.Context`'s existence-only discovery helper is deleted in favour of the
  executable-bit resolver, because two predicates over one tool set answer differently on the same host.

### Validation

1. The step type admits no constructor whose payload is an unparsed string.
2. Every tool a production path invokes is a `HostTool` constructor, joined from the invocation sites to the
   enum in both directions.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 51.3: The reconciler table ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: Sprint 51.2
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary, and reviewer have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt [`testing_doctrine.md` §9](../documents/engineering/testing_doctrine.md#9-derivation-generated-enumeration-authored-expectation);
express a reconciler as a row so its three views cannot disagree with each other.

### Deliverables

- One table whose row carries the substrates a reconciler applies to, the phrase a diagnostic uses to describe
  them, and the steps it installs on each. A reconciler is not a module of parallel logic, it is a row.
- A diagnostic rendered from the applicability column rather than authored beside it, because an authored
  phrase drifts from the set it describes the first time that set changes.
- A refusal that fires before any side effect when a reconciler is driven on a substrate its row excludes, so
  a misapplied reconciler costs a message rather than a half-installed host.
- A separately authored Haskell table expectation. Its human-readable rendering is generated lazily beneath
  `.build/**`, so a row change is a reviewable diff without a serialized repository fixture.

### Validation

1. A reconciler's diagnostic names exactly the substrates its applicability column admits, with no third
   place where either is written.
2. Driving a reconciler on an excluded substrate refuses before any process is created.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 51.4: The probe-first ensure driver ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: Sprint 51.3
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary, and reviewer have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt [`substrate_doctrine.md` §3](../documents/engineering/substrate_doctrine.md#3-the-no-environment--no-path-lazy-tool-ensure-contract);
give the driver an installer and a production caller, and make the probe the post-condition as well as the
pre-condition.

### Deliverables

- An installer that executes a typed step by absolute path and returns a classified failure, so a failed
  install is distinguishable from a tool that was never attempted.
- A re-resolve after every step, because a tool a step laid down is absent from the config snapshot that step
  began with, and the next step would otherwise report it missing.
- One predicate serving as both pre-probe and post-probe, since a driver that probes one property and verifies
  another reports a convergence nothing established.
- A production caller in the binary's host context, replacing `Cluster/Bootstrap.hs`'s outright refusal of
  `apple` and `windows` with entry into the frame their rows name.

### Validation

1. A second run issues no install argv, and the recorded argv set is the evidence rather than a return code.
2. A plan exhausted with the requested tool still unresolved fails with that tool named.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 51.5: The lift fold to argv ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: Sprint 51.4
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary, and reviewer have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt [the exact boundary of the no-`PATH` rule](../documents/engineering/substrate_doctrine.md#the-exact-boundary-of-the-no-path-rule);
fold a lift context into argv once, so one step list runs on the host, inside a VM, and inside a container
without a second deployment path.

### Deliverables

- A `LiftContext` describing where a step executes, and one pure fold from that context and a step to the argv
  that runs it. Two deployment paths for one step list is how a fix reaches one substrate and not the others.
- Absolute-path resolution applied to the outermost tool only, with a nested command left as the guest's own
  name against the guest's own environment.
- A separately authored Haskell argv expectation per context. Any diff rendering is generated lazily beneath
  `.build/**`, so a fold change is visible without a serialized repository golden.

### Validation

1. The three contexts consume one step list and differ only in the prefix the fold emits.
2. The fold creates no process and reads no environment variable, so it is testable as a pure function.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

---

## Documentation Requirements

**Engineering docs to update (when an authorized reviewer promotes the gate, never before):**

- `documents/engineering/substrate_doctrine.md` — §3's honesty note records package-manager-canonical
  discovery once the resolver performs it, and the install-and-verify subsection records the typed step and
  the closed frame map.
- `documents/engineering/daemon_topology_doctrine.md` — the composition lift records that one fold serves all
  three contexts.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/system_components.md` — the lazy tool-ensure row leaves PARTIAL once the driver has a
  caller and the mechanism is typed, and the new host modules take their rows.
- `DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md` — the reader-facing
  [host-obligation explanations](legacy_tracking_for_deletion.md#4-host-image-and-lift-violations) for the
  uninterpretable mechanism, caller-less driver, thrice-written tool set, and second discovery helper are
  reconciled here only after their typed Haskell closure predicates return zero and the authorized reviewer approves.

---

## Related Documents

- [Substrate Doctrine](../documents/engineering/substrate_doctrine.md)
- [DSL Doctrine](../documents/engineering/dsl_doctrine.md)
- [Testing Doctrine](../documents/engineering/testing_doctrine.md)
- [Phase 50](phase_50_host_assert_cli.md)
- [Development Plan](README.md)
