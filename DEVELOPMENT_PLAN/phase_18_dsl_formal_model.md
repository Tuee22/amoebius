# Phase 18: DSL formal model

> **Purpose**: Specify the target Haskell capability to project a bounded tranche of DSL decisions
> and concurrent protocols from Haskell values into executable and formal-model readings, with every
> Dhall, TLA+, CFG, or rendered fixture product generated only beneath `.build/**`.
> **Read this if**: the decoder/fold/render boundary, Lease/reservation/reconcile models, or the line between
> bounded design proof and runtime fidelity must be changed.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot satisfy a gate through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_19_reconcile_core_simulation.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 18.1: Actual bounded DSL projections](#sprint-181-actual-bounded-dsl-projections-)
- [Sprint 18.2: Protocol models and correspondence](#sprint-182-protocol-models-and-correspondence-)
- [Sprint 18.3: Explorer, TLC, mutation, and gate](#sprint-183-explorer-tlc-mutation-and-gate-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 17, its independent validation, and gate pass; every earlier
gate barrier must also be satisfied in numerical order. Every earlier completion claim and implementation result in this document is historical rather than a current gate result, even
where the surrounding prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

> **Reset contract interpretation.** The phase-specific gate check below is UNRESOLVED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and the complete qualified gate passes, the summary and work breakdown are a capability inventory, not an executable contract. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is historical and non-operative.

## Phase Summary

This phase specifies a Haskell target capability; it does not report a current implementation or
result. The target is to project a bounded tranche of DSL decisions and concurrent protocols from
Haskell values into executable and formal-model readings, with every Dhall, TLA+, CFG, or rendered
fixture product generated only beneath `.build/**`.

The production subject, behavioral controls, independent oracle, fixtures, and mutants must be authored as
`.hs`. Except for the `pb/**` bootstrap, no non-`.hs` behavioral source, fixture, oracle, or mutant may be
tracked. Any foreign representation, rendered specification, compiler transcript, suite manifest, generated
code, or other derived product must be created lazily beneath `.build/**` and remain run-scoped evidence only.
`pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec that exact Haskell verdict binary with argv unchanged; that entry point and its independent
evidence contract remain UNRESOLVED and block validation.

This phase precedes Phase 49 and is confined to pure, build, compiler, or model-level Register-1
behavior only. It cannot use host, hardware, live-service, or cluster observations to make its claim pass.

**Phase scope:** Target capability only — project a bounded tranche of DSL decisions and concurrent
protocols from Haskell values into executable and formal-model readings, with every Dhall, TLA+,
CFG, or rendered fixture product generated only beneath `.build/**`. NOT VALIDATED.

**Substrate:** `none` — pre-Phase-49; no host, hardware, live service, or cluster observation.

**Lane:** `none`.

**Register:** 1 — Haskell-only pure/build/model target. NOT VALIDATED.

**Depends on:** [Phase 17](phase_17_gateway_migration_model.md)
**Gate:** `pb validate phase 18`; see [Gate integrity](#gate-integrity).

## Gate integrity

**Contract check**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: Target capability only — project a bounded tranche of DSL decisions and concurrent protocols from Haskell values into executable and formal-model readings, with every Dhall, TLA+, CFG, or rendered fixture product generated only beneath `.build/**`. NOT VALIDATED. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: `pb validate phase 18` is future public spelling only. Before current gate pass of Phase 50, `pb` is inadmissible validation transport; the candidate must invoke the exact absolute source-bound Haskell executable directly from an pinned, network-independent toolchain input. The Haskell verdict entry point remains `UNRESOLVED` and blocks validation. |
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
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: Exact `ImmediatePredecessorPass` for Phase 17; candidate execution refuses an absent, stale, replayed, or different-source result. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Pass criterion` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: `qualified-gate-pass` — every required gate row must succeed in one qualified run for the exact current source; that complete pass is sufficient for the status-only transition. |

## Doctrine adopted

- [`formal_model_doctrine.md` §3 — Two total renderings](../documents/engineering/formal_model_doctrine.md#3-two-total-renderings): explorer and TLC are separate readings of one model value.
- [`formal_model_doctrine.md` §4.1 — The reference model and its semantic oracle](../documents/engineering/formal_model_doctrine.md#41-the-reference-model-and-its-semantic-oracle): semantic facts, not generated bytes, decide renderer acceptance.
- [`formal_model_doctrine.md` §6 — What a green model-check proves, and what it does not](../documents/engineering/formal_model_doctrine.md#6-what-a-green-model-check-proves-and-what-it-does-not): no finite result is current; any future accepted model result would still leave runtime fidelity unproved.
- [`dsl_doctrine.md` §5 — The illegal-state-unrepresentable contract](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract): the target model must not claim credit for states that a gate-passed Haskell type-system boundary must first exclude.
- [`cluster_lifecycle_doctrine.md` §9 — How bring-up and teardown are implemented: the reconciler, not a state machine](../documents/engineering/cluster_lifecycle_doctrine.md#9-how-bring-up-and-teardown-are-implemented-the-reconciler-not-a-state-machine): unreachable observation is distinct from absence.

## Sprints

> **Reset validation check.** Every pre-reset `Independent Validation` and `### Validation` below is historical context rather than a current criterion. It is retained only to inventory the capability while the fixed Haskell subject/oracle/mutant/legacy contract is rewritten.

## Sprint 18.1: Actual bounded DSL projections ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: [Phase 17](phase_17_gateway_migration_model.md) gate pass
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, and its provenance have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been checked for this sprint.

### Objective

Connect a finite, explicitly named DSL decision tranche to real repository code without accepting generated
hashes or byte snapshots as semantic evidence.

### Deliverables

- Exhaustive four-axis `0..2` demand/capacity differential over 6,561 pairs.
- Actual five-calculus composition projected through the shared formal bridge.

### Validation

1. Compare `fits` to independent componentwise subtraction on every finite-domain pair.
2. Match all eight shared calculus facts.

**The decoder and the provision/render/chain tranches are not this phase's to project.** Both named artefacts
this phase does not own: `decodeCluster` is built at
[Phase 26](phase_26_gadt_decode_ir.md), `provision` at [Phase 31](phase_31_provision_seal.md), `renderAll` at
[Phase 33](phase_33_render_manifest_oracles.md), and `Step`/`chain` at
[Phase 34](phase_34_chain_kernel_boundary.md). Requiring "five actual decoder positives" and "two actual
provision/render/chain projections" here made a phase-18 gate pass depend on four later phases, which
`Depends on:` cannot express and no checker could see. Each tranche moves to a sprint of its owning phase and
projects back through this phase's formal bridge locally, where the artefact already exists. What remains at
18 is what Phases 3–17 deliver: the capacity differential over the Phase-9 fold, and the five-calculus
composition over Phase-11 `Model` values.

### Remaining Work

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate. The two removed tranches are
carried as obligations on Phases 26 and 34 rather than as residue here, because this phase no longer claims
them.

## Sprint 18.2: Protocol models and correspondence ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 18.1
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, and its provenance have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been checked for this sprint.

### Objective

State temporal safety/liveness for token, reservation, Lease, and reconcile behavior, while keeping the actual
code correspondence explicitly bounded.

### Deliverables

- One projection model and four transition models with eight safety and four liveness obligations.
- Actual one-use token, one-debit reservation, and unreachable-refusal readings.
- Six-model contract including the actual calculus-composition model.

### Validation

1. Require exact model structure and an 18-state explorer total.
2. Require the actual protocol decisions at their exact outcomes and reasons.
3. Keep all live/effectful correspondence marked UNVERIFIED.

### Remaining Work

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 18.3: Explorer, TLC, mutation, and gate ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 18.2
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, and its provenance have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been checked for this sprint.

### Objective

Prove the bounded model claims, demonstrate their obligations are load-bearing, and retain the result as a
source-bound phase-gate result.

### Deliverables

- Five exact explorer/TLC fingerprint comparisons.
- Eight exact safety mutants and four fairness-drop mutants red.
- Fourteen metrics, 15-surface/18-item join, ledger, containment, write guard, and exact run binding.

### Validation

1. Require explorer/TLC fingerprint equality on all five transition-bearing DSL models.
2. Require each safety mutant to violate exactly its authored invariant and each fairness drop to fail TLC.
3. Require all generated model-check output beneath `.build/**` and absent from the source snapshot.
4. Bind the complete result to the natural architecture and source digest.

### Remaining Work

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- `formal_model_doctrine.md` — record the bounded DSL/protocol model set and actual-code projection boundary.
- `dsl_doctrine.md` — record the bounded decoder/fold/render/chain evidence without generalizing it.
- `cluster_lifecycle_doctrine.md` — record the modeled and actual unreachable-observation decision while
  leaving effectful reconciliation UNVERIFIED.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md`, `overview.md`, `system_components.md`, and
  `legacy_tracking_for_deletion.md` — reconcile order, evidence, implementation paths, and rewritten-body debt.

## Related Documents

- [Development Plan Tracker](README.md) — numeric order and current phase status.
- [Development Plan Standards](development_plan_standards.md) — phase shape, honesty, and artifact rules.
- [Phase 11](phase_11_formal_model_kernel.md) — formal kernel.
- [Phase 16](phase_16_deterministic_sim_substrate.md) — shared actual-calculus harness adapter.
- [Phase 17](phase_17_gateway_migration_model.md) — preceding concrete model and semantic-renderer instance.
- [Phase 19](phase_19_reconcile_core_simulation.md) — next numeric contract and runtime-simulation owner.
- [Formal Model Doctrine](../documents/engineering/formal_model_doctrine.md) — model/proof boundary.
- [DSL Doctrine](../documents/engineering/dsl_doctrine.md) — language and illegal-state boundary.
- [Gateway Migration Model Doctrine](../documents/engineering/gateway_migration_model_doctrine.md) — sibling concrete-protocol model.
- [Cluster Lifecycle Doctrine](../documents/engineering/cluster_lifecycle_doctrine.md) — reconcile observation semantics.
- [Generated Artifacts Doctrine](../documents/engineering/generated_artifacts_doctrine.md) — transient TLA+/CFG rule.
