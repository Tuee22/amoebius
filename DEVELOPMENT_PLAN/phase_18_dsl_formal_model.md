# Phase 18: DSL formal model

> **Purpose**: Specify the target Haskell capability to project a bounded tranche of DSL decisions
> and concurrent protocols from Haskell values into executable and formal-model readings, with every
> Dhall, TLA+, CFG, or rendered fixture product generated only beneath `.build/**`.
> **Read this if**: the decoder/fold/render boundary, Lease/reservation/reconcile models, or the line between
> bounded design proof and runtime fidelity must be changed.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot regain authority through a status edit. Current
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
- [Sprint 18.1: Actual bounded DSL projections ⏸️](#sprint-181-actual-bounded-dsl-projections-)
- [Sprint 18.2: Protocol models and correspondence ⏸️](#sprint-182-protocol-models-and-correspondence-)
- [Sprint 18.3: Explorer, TLC, mutation, and gate ⏸️](#sprint-183-explorer-tlc-mutation-and-gate-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 17, its independent validation, and human promotion; every earlier
promotion barrier must also be satisfied in numerical order. Every prior pass, seal, receipt, attestation,
completion claim, and implementation result in this document is invalidated as validation evidence, even
where historical prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

> **Reset contract interpretation.** The phase-specific gate review below is REJECTED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and a human independently reviews it, the summary and work breakdown are a capability inventory, not executable authority. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is invalidated and non-operative.

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
behavior only. It cannot use host, hardware, live-service, or cluster observations to validate or
promote its claim.

**Phase scope:** Target capability only — project a bounded tranche of DSL decisions and concurrent
protocols from Haskell values into executable and formal-model readings, with every Dhall, TLA+,
CFG, or rendered fixture product generated only beneath `.build/**`. NOT VALIDATED.

**Substrate:** `none` — pre-Phase-49; no host, hardware, live service, or cluster observation.

**Lane:** `none`.

**Register:** 1 — Haskell-only pure/build/model target. NOT VALIDATED.

**Depends on:** [Phase 17](phase_17_gateway_migration_model.md) — exact current human approval; the numeric chain includes every earlier phase
**Gate:** `pb validate phase 18`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract review**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | Target capability only — project a bounded tranche of DSL decisions and concurrent protocols from Haskell values into executable and formal-model readings, with every Dhall, TLA+, CFG, or rendered fixture product generated only beneath `.build/**`. NOT VALIDATED. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | `pb validate phase 18` is future public spelling only. Before current human approval of Phase 50, `pb` is inadmissible validation transport; the candidate must invoke the exact absolute source-bound Haskell executable directly from an authenticated, network-independent toolchain input. The Haskell verdict entry point remains `UNRESOLVED` and blocks validation. |
| `Oracle` | UNRESOLVED — blocks validation: no separately authored `.hs` oracle, independence boundary, provenance, and independent human reviewer have been accepted. |
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
| `Predecessor` | MISSING — blocks validation: the current Phase 17 human approval receipt does not exist. |
| `Residue` | UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Human authority` | `human-only` — no agent, gate, CI job, digest, receipt-shaped file, or generated assertion may promote status. |

## Doctrine adopted

- [`formal_model_doctrine.md` §3 — Two total renderings](../documents/engineering/formal_model_doctrine.md#3-two-total-renderings): explorer and TLC are separate readings of one model value.
- [`formal_model_doctrine.md` §4.1 — The reference model and its semantic oracle](../documents/engineering/formal_model_doctrine.md#41-the-reference-model-and-its-semantic-oracle): semantic facts, not generated bytes, decide renderer acceptance.
- [`formal_model_doctrine.md` §6 — What a green model-check proves, and what it does not](../documents/engineering/formal_model_doctrine.md#6-what-a-green-model-check-proves-and-what-it-does-not): no finite result is current; any future accepted model result would still leave runtime fidelity unproved.
- [`dsl_doctrine.md` §5 — The illegal-state-unrepresentable contract](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract): the target model must not claim credit for states that a human-approved Haskell type-system boundary must first exclude.
- [`cluster_lifecycle_doctrine.md` §9 — How bring-up and teardown are implemented: the reconciler, not a state machine](../documents/engineering/cluster_lifecycle_doctrine.md#9-how-bring-up-and-teardown-are-implemented-the-reconciler-not-a-state-machine): unreachable observation is distinct from absence.

## Sprints

> **Reset validation review.** Every pre-reset `Independent Validation` and `### Validation` below is rejected as a current criterion and MUST NOT be executed or cited. It is retained only to inventory the capability while the fixed Haskell subject/oracle/reviewer/mutant/legacy contract is rewritten.

## Sprint 18.1: Actual bounded DSL projections ⏸️

**Status**: Blocked — NOT VALIDATED

### Objective

Connect a finite, explicitly named DSL decision tranche to real repository code without accepting generated
hashes or byte snapshots as semantic evidence.

### Deliverables

- Five actual decoder positives, four exact negatives, and a stated non-hash semantic projection.
- Exhaustive four-axis `0..2` demand/capacity differential over 6,561 pairs.
- Two actual provision/render/chain projections totaling 19 objects and steps.
- Actual five-calculus composition projected through the shared formal bridge.

### Validation

1. Require exact decoder surfaces, structural counts, and negative tags.
2. Compare `fits` to independent componentwise subtraction on every finite-domain pair.
3. Require exact render/chain identities and frames, unique objects, and zero construction-time effects.
4. Match all eight shared calculus facts.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 18.2: Protocol models and correspondence ⏸️

**Status**: Blocked — NOT VALIDATED

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

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 18.3: Explorer, TLC, mutation, and gate ⏸️

**Status**: Blocked — NOT VALIDATED

### Objective

Prove the bounded model claims, demonstrate their obligations are load-bearing, and retain the result as a
source-bound phase attestation.

### Deliverables

- Five exact explorer/TLC fingerprint comparisons.
- Eight exact safety mutants and four fairness-drop mutants red.
- Fourteen metrics, 15-surface/18-item join, ledger, containment, write guard, and attestation.

### Validation

1. Require explorer/TLC fingerprint equality on all five transition-bearing DSL models.
2. Require each safety mutant to violate exactly its authored invariant and each fairness drop to fail TLC.
3. Require all generated model-check output beneath `.build/**` and absent from the source snapshot.
4. Bind the complete result to the natural architecture and source digest.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Documentation Requirements

**Engineering docs to update (when the human promotes the gate, never before):**

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
